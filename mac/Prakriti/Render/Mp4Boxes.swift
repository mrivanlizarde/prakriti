import Foundation

// The MP4's boxes, read from the file (v2 part M8b): where the index (`moov`) sits against the media (`mdat`), and the edit
// lists (`elst`) of each track, for the Ready checklist (research-edit-engine.md 6.4: "index at the front", "no video edit
// list"); and the one change Prakriti makes to a written MP4, turning the video track's identity edit list into a free box.
//
// Why that change is safe: AVAssetWriter always writes an edit list on the video track. With no B-frames (VideoWriter) it is
// one entry that starts at media time 0 and covers the whole track at rate 1, which shows the track exactly as it is
// without it. Renaming its `edts` box to `free` keeps every byte offset in the file (no index moves) and removes the only
// edit list YouTube would see on the video. Any other edit list is left alone, and the checklist fails it.

enum Mp4Boxes {
    struct Box: Equatable, Sendable {
        var type: String
        var offset: Int64
        var size: Int64
        var header: Int64
    }

    struct EditEntry: Equatable, Sendable {
        var segmentDuration: Int64
        var mediaTime: Int64
        var rate: Double
    }

    struct Track: Equatable, Sendable {
        var handler: String
        var edits: [EditEntry]?
        /// The `edts` box's offset in the file, when the track has one.
        var editsOffset: Int64?
    }

    struct Layout: Equatable, Sendable {
        var topLevel: [Box]
        var tracks: [Track]

        var indexBeforeMedia: Bool {
            guard let moov = topLevel.first(where: { $0.type == "moov" }), let mdat = topLevel.first(where: { $0.type == "mdat" }) else { return false }
            return moov.offset < mdat.offset
        }

        var videoEditLists: Int { tracks.filter { $0.handler == "vide" && $0.edits != nil }.count }
    }

    struct Failure: Error, Equatable, Sendable {
        let reason: String
    }

    /// The movie's length from its `mvhd` box (the movie header's duration over its timescale), read without decoding anything
    /// (v2 part M11b: the Approve sheet measures every short this way each time it opens). Nil when the file has no movie header.
    static func duration(_ url: URL) -> Double? {
        guard let layout = try? read(url), let moov = layout.topLevel.first(where: { $0.type == "moov" }),
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var at = moov.offset + moov.header
        let end = moov.offset + moov.size
        while at + 8 <= end {
            guard (try? handle.seek(toOffset: UInt64(at))) != nil, let head = try? handle.read(upToCount: 8), head.count == 8 else { return nil }
            let size = Int64(be32(head, 0))
            let type = String(decoding: head[4..<8], as: UTF8.self)
            guard size >= 8 else { return nil }
            if type == "mvhd" {
                guard let body = try? handle.read(upToCount: 32), body.count >= 20 else { return nil }
                let version = body[0]
                if version == 1 {
                    guard body.count >= 32 else { return nil }
                    let scale = Double(be32(body, 20))
                    let length = Double(UInt64(be32(body, 24)) << 32 | UInt64(be32(body, 28)))
                    return scale > 0 ? length / scale : nil
                }
                let scale = Double(be32(body, 12)), length = Double(be32(body, 16))
                return scale > 0 ? length / scale : nil
            }
            at += size
        }
        return nil
    }

    static func read(_ url: URL) throws -> Layout {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let end = Int64(try handle.seekToEnd())
        var top: [Box] = []
        var at: Int64 = 0
        while at + 8 <= end {
            try handle.seek(toOffset: UInt64(at))
            guard let head = try handle.read(upToCount: 16), head.count >= 8 else { break }
            var size = Int64(be32(head, 0))
            let type = String(decoding: head[4..<8], as: UTF8.self)
            var header: Int64 = 8
            if size == 1, head.count >= 16 { size = Int64(bitPattern: be64(head, 8)); header = 16 }
            if size == 0 { size = end - at }
            guard size >= header else { throw Failure(reason: "The MP4's box at \(at) has a size of \(size).") }
            top.append(Box(type: type, offset: at, size: size, header: header))
            at += size
        }
        var tracks: [Track] = []
        if let moov = top.first(where: { $0.type == "moov" }) {
            try handle.seek(toOffset: UInt64(moov.offset))
            let data = try handle.read(upToCount: Int(moov.size)) ?? Data()
            for trak in children(data, from: Int(moov.header), to: data.count) where trak.type == "trak" {
                var track = Track(handler: "")
                for child in children(data, from: Int(trak.offset + trak.header), to: Int(trak.offset + trak.size)) {
                    if child.type == "edts" {
                        track.editsOffset = moov.offset + child.offset
                        for elst in children(data, from: Int(child.offset + child.header), to: Int(child.offset + child.size)) where elst.type == "elst" {
                            track.edits = editEntries(data, at: Int(elst.offset + elst.header))
                        }
                        if track.edits == nil { track.edits = [] }
                    }
                    if child.type == "mdia" {
                        for hdlr in children(data, from: Int(child.offset + child.header), to: Int(child.offset + child.size)) where hdlr.type == "hdlr" {
                            let p = Int(hdlr.offset + hdlr.header) + 8
                            if p + 4 <= data.count { track.handler = String(decoding: data[(data.startIndex + p)..<(data.startIndex + p + 4)], as: UTF8.self) }
                        }
                    }
                }
                tracks.append(track)
            }
        }
        return Layout(topLevel: top, tracks: tracks)
    }

    /// Turns the video track's edit list into a free box when it is the identity (one entry, media time 0, rate 1).
    /// Returns whether it changed the file.
    @discardableResult
    static func dropIdentityVideoEditList(_ url: URL) throws -> Bool {
        let layout = try read(url)
        guard let video = layout.tracks.first(where: { $0.handler == "vide" }), let offset = video.editsOffset, let edits = video.edits else { return false }
        guard edits.count == 1, edits[0].mediaTime == 0, abs(edits[0].rate - 1) < 1e-9 else { return false }
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(offset + 4))
        guard let type = try handle.read(upToCount: 4), String(decoding: type, as: UTF8.self) == "edts" else {
            throw Failure(reason: "The video track's edit list was not where it was read.")
        }
        try handle.seek(toOffset: UInt64(offset + 4))
        try handle.write(contentsOf: Data("free".utf8))
        return true
    }

    // MARK: Reading

    /// The boxes directly inside `data[from..<to]`, with offsets relative to `data`.
    static func children(_ data: Data, from: Int, to: Int) -> [Box] {
        var out: [Box] = []
        var at = from
        while at + 8 <= to {
            var size = Int64(be32(data, at))
            let type = String(decoding: data[(data.startIndex + at + 4)..<(data.startIndex + at + 8)], as: UTF8.self)
            var header: Int64 = 8
            if size == 1, at + 16 <= to { size = Int64(bitPattern: be64(data, at + 8)); header = 16 }
            if size == 0 { size = Int64(to - at) }
            guard size >= header, at + Int(size) <= to else { break }
            out.append(Box(type: type, offset: Int64(at), size: size, header: header))
            at += Int(size)
        }
        return out
    }

    static func editEntries(_ data: Data, at p: Int) -> [EditEntry] {
        guard p + 8 <= data.count else { return [] }
        let version = data[data.startIndex + p]
        let count = Int(be32(data, p + 4))
        var out: [EditEntry] = []
        var at = p + 8
        for _ in 0..<count {
            if version == 1 {
                guard at + 20 <= data.count else { break }
                out.append(EditEntry(segmentDuration: Int64(bitPattern: be64(data, at)), mediaTime: Int64(bitPattern: be64(data, at + 8)),
                                     rate: Double(Int16(bitPattern: UInt16(be16(data, at + 16)))) + Double(be16(data, at + 18)) / 65536))
                at += 20
            } else {
                guard at + 12 <= data.count else { break }
                out.append(EditEntry(segmentDuration: Int64(be32(data, at)), mediaTime: Int64(Int32(bitPattern: be32(data, at + 4))),
                                     rate: Double(Int16(bitPattern: UInt16(be16(data, at + 8)))) + Double(be16(data, at + 10)) / 65536))
                at += 12
            }
        }
        return out
    }

    static func be16(_ d: Data, _ i: Int) -> UInt32 {
        let b = d.startIndex + i
        return UInt32(d[b]) << 8 | UInt32(d[b + 1])
    }

    static func be32(_ d: Data, _ i: Int) -> UInt32 {
        let b = d.startIndex + i
        return UInt32(d[b]) << 24 | UInt32(d[b + 1]) << 16 | UInt32(d[b + 2]) << 8 | UInt32(d[b + 3])
    }

    static func be64(_ d: Data, _ i: Int) -> UInt64 {
        UInt64(be32(d, i)) << 32 | UInt64(be32(d, i + 4))
    }
}
