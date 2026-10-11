import Foundation

// The podcast-ready MP3's tag, written by Prakriti itself as ID3v2.4, and read back to check it.
//
// Why not ffmpeg's own tags: measured 10 Oct on ffmpeg 9.0.1, its MP3 muxer writes a "comment" as a
// TXXX frame, never the COMM frame players and hosts read as the comment, and it wrote CHAP frames
// with no titles inside them. So ffmpeg encodes the audio with no tag at all (`-id3v2_version 0`),
// and this file puts the tag in front of it: title, author, show, year, comment, genre, episode
// number, the artwork, and the chapters (a CTOC frame listing CHAP frames, each with its title).
//
// The reader parses ID3v2.3 and v2.4, including frames inside CHAP and CTOC, so the checklist and
// the tests can prove what is in the file rather than trust what was meant to be written.

enum ID3 {
    /// One chapter: its title, and where it starts and ends in milliseconds.
    struct Chapter: Equatable, Sendable {
        var id: String
        var startMS: UInt32
        var endMS: UInt32
        var title: String
    }

    /// The table of contents: its id, whether it is the top level and ordered, and its chapters' ids.
    struct TableOfContents: Equatable, Sendable {
        var id: String
        var topLevel: Bool
        var ordered: Bool
        var children: [String]
    }

    struct Picture: Equatable, Sendable {
        var mime: String
        var type: UInt8
        var bytes: Int
    }

    /// What the tag holds, as read back.
    struct Tag: Equatable, Sendable {
        var version: UInt8 = 0
        var text: [String: String] = [:]
        var comment: String?
        var picture: Picture?
        var toc: TableOfContents?
        var chapters: [Chapter] = []
        /// Every frame id, in order, for the checklist and the tests.
        var frameIDs: [String] = []
        /// The size of the whole tag, header included: where the audio starts.
        var size: Int = 0
    }

    /// What to write.
    struct Contents: Sendable {
        var title: String
        var artist: String?
        var album: String?
        var year: String?
        var comment: String?
        var genre: String = "Podcast"
        var track: Int?
        var artwork: (data: Data, mime: String)?
        var chapters: [Chapter] = []
    }

    // MARK: Writing

    /// "ID3" v2.4 with every frame in UTF-8, plus 1 KB of padding so a player that edits the tag in
    /// place need not rewrite the file.
    static func tag(_ contents: Contents) -> Data {
        var frames = Data()
        frames += textFrame("TIT2", contents.title)
        if let artist = contents.artist, !artist.isEmpty { frames += textFrame("TPE1", artist) }
        if let album = contents.album, !album.isEmpty { frames += textFrame("TALB", album) }
        if let year = contents.year, !year.isEmpty { frames += textFrame("TDRC", year) }
        if let track = contents.track { frames += textFrame("TRCK", String(track)) }
        frames += textFrame("TCON", contents.genre)
        if let comment = contents.comment, !comment.isEmpty {
            var body = Data([3]) + Data("eng".utf8)
            body += Data([0]) // empty short description, UTF-8
            body += Data(comment.utf8)
            frames += frame("COMM", body)
        }
        if let artwork = contents.artwork {
            var body = Data([3]) + Data(artwork.mime.utf8) + Data([0])
            body += Data([3]) // front cover
            body += Data("Cover".utf8) + Data([0])
            body += artwork.data
            frames += frame("APIC", body)
        }
        if !contents.chapters.isEmpty {
            var toc = Data("toc".utf8) + Data([0])
            toc += Data([0x03, UInt8(min(contents.chapters.count, 255))]) // top level, ordered
            for chapter in contents.chapters.prefix(255) { toc += Data(chapter.id.utf8) + Data([0]) }
            toc += textFrame("TIT2", "Chapters")
            frames += frame("CTOC", toc)
            for chapter in contents.chapters.prefix(255) {
                var body = Data(chapter.id.utf8) + Data([0])
                body += bigEndian(chapter.startMS) + bigEndian(chapter.endMS)
                body += bigEndian(UInt32.max) + bigEndian(UInt32.max) // no byte offsets
                body += textFrame("TIT2", chapter.title)
                frames += frame("CHAP", body)
            }
        }
        let padding = Data(count: 1024)
        var header = Data("ID3".utf8) + Data([4, 0, 0])
        header += syncsafe(UInt32(frames.count + padding.count))
        return header + frames + padding
    }

    /// The audio of an MP3, without any ID3v2 tag in front of it (ffmpeg's, or one written before).
    static func audio(of data: Data) -> Data {
        let size = tagSize(data)
        return size > 0 && size <= data.count ? data.subdata(in: size..<data.count) : data
    }

    /// Writes `contents` as the tag of the MP3 at `source`, into `destination`.
    static func write(_ contents: Contents, audioFrom source: URL, to destination: URL) throws {
        let data = try Data(contentsOf: source)
        try (tag(contents) + audio(of: data)).write(to: destination, options: .atomic)
    }

    private static func textFrame(_ id: String, _ text: String) -> Data {
        frame(id, Data([3]) + Data(text.utf8))
    }

    private static func frame(_ id: String, _ body: Data) -> Data {
        Data(id.utf8) + syncsafe(UInt32(body.count)) + Data([0, 0]) + body
    }

    static func syncsafe(_ value: UInt32) -> Data {
        Data([UInt8((value >> 21) & 0x7F), UInt8((value >> 14) & 0x7F), UInt8((value >> 7) & 0x7F), UInt8(value & 0x7F)])
    }

    private static func bigEndian(_ value: UInt32) -> Data {
        Data([UInt8(value >> 24), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)])
    }

    // MARK: Reading

    /// The size of the ID3v2 tag at the start of `data`, header (and footer) included; 0 when none.
    static func tagSize(_ data: Data) -> Int {
        let bytes = [UInt8](data.prefix(10))
        guard bytes.count == 10, bytes[0] == 0x49, bytes[1] == 0x44, bytes[2] == 0x33 else { return 0 }
        let size = Int(unsyncsafe(bytes[6...9]))
        let footer = bytes[5] & 0x10 != 0 ? 10 : 0
        return 10 + size + footer
    }

    static func read(_ url: URL) -> Tag? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: 10), head.count == 10 else { return nil }
        let size = tagSize(head)
        guard size > 10, let rest = try? handle.read(upToCount: size - 10) else { return nil }
        return parse(head + rest)
    }

    static func parse(_ data: Data) -> Tag? {
        let bytes = [UInt8](data)
        guard bytes.count >= 10, bytes[0] == 0x49, bytes[1] == 0x44, bytes[2] == 0x33 else { return nil }
        var tag = Tag()
        tag.version = bytes[3]
        tag.size = tagSize(data)
        let end = min(bytes.count, 10 + Int(unsyncsafe(bytes[6...9])))
        for (id, body) in frames(bytes, from: 10, to: end, version: tag.version) {
            tag.frameIDs.append(id)
            apply(id, body, version: tag.version, to: &tag)
        }
        return tag
    }

    private static func apply(_ id: String, _ body: ArraySlice<UInt8>, version: UInt8, to tag: inout Tag) {
        switch id {
        case "COMM":
            guard body.count > 4 else { return }
            let encoding = body[body.startIndex]
            let rest = body.dropFirst(4)
            let (_, after) = terminated(rest, encoding: encoding)
            tag.comment = decode(after, encoding: encoding)
        case "APIC":
            guard let encoding = body.first else { return }
            let (mime, afterMime) = terminated(body.dropFirst(), encoding: 0)
            guard let type = afterMime.first else { return }
            let (_, data) = terminated(afterMime.dropFirst(), encoding: encoding)
            tag.picture = Picture(mime: mime, type: type, bytes: data.count)
        case "CTOC":
            let (elementID, after) = terminated(body, encoding: 0)
            guard after.count >= 2 else { return }
            let flags = after[after.startIndex], count = Int(after[after.startIndex + 1])
            var cursor = after.dropFirst(2)
            var children: [String] = []
            for _ in 0..<count {
                let (child, next) = terminated(cursor, encoding: 0)
                children.append(child)
                cursor = next
            }
            tag.toc = TableOfContents(id: elementID, topLevel: flags & 0x02 != 0, ordered: flags & 0x01 != 0, children: children)
        case "CHAP":
            let (elementID, after) = terminated(body, encoding: 0)
            guard after.count >= 16 else { return }
            let start = UInt32(bigEndian: after, at: after.startIndex), finish = UInt32(bigEndian: after, at: after.startIndex + 4)
            var title = ""
            let sub = Array(after.dropFirst(16))
            for (subID, subBody) in frames(sub, from: 0, to: sub.count, version: version) where subID == "TIT2" {
                title = text(subBody)
            }
            tag.chapters.append(Chapter(id: elementID, startMS: start, endMS: finish, title: title))
        default:
            if id.hasPrefix("T"), id != "TXXX" { tag.text[id] = text(body) }
        }
    }

    /// Frames between `from` and `to`, each as its id and body.
    private static func frames(_ bytes: [UInt8], from: Int, to: Int, version: UInt8) -> [(String, ArraySlice<UInt8>)] {
        var out: [(String, ArraySlice<UInt8>)] = []
        var i = from
        while i + 10 <= to {
            let idBytes = bytes[i..<(i + 4)]
            guard idBytes.allSatisfy({ ($0 >= 0x41 && $0 <= 0x5A) || ($0 >= 0x30 && $0 <= 0x39) }) else { break } // padding
            let id = String(decoding: idBytes, as: UTF8.self)
            let size = version >= 4 ? Int(unsyncsafe(bytes[(i + 4)...(i + 7)])) : Int(UInt32(bigEndian: bytes[...], at: i + 4))
            let start = i + 10, end = min(to, start + size)
            guard size >= 0, start <= end else { break }
            out.append((id, bytes[start..<end]))
            i = start + size
        }
        return out
    }

    private static func unsyncsafe(_ b: ArraySlice<UInt8>) -> UInt32 {
        b.reduce(UInt32(0)) { ($0 << 7) | UInt32($1 & 0x7F) }
    }

    /// A text frame's value: its encoding byte, then the text (a trailing terminator dropped).
    private static func text(_ body: ArraySlice<UInt8>) -> String {
        guard let encoding = body.first else { return "" }
        return decode(body.dropFirst(), encoding: encoding).trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
    }

    /// The text up to its terminator (one zero byte, or two for UTF-16), and what follows it.
    private static func terminated(_ body: ArraySlice<UInt8>, encoding: UInt8) -> (String, ArraySlice<UInt8>) {
        let wide = encoding == 1 || encoding == 2
        var i = body.startIndex
        while i < body.endIndex {
            if wide {
                if i + 1 < body.endIndex, body[i] == 0, body[i + 1] == 0, (i - body.startIndex) % 2 == 0 {
                    return (decode(body[body.startIndex..<i], encoding: encoding), body[(i + 2)...])
                }
                i += 1
            } else {
                if body[i] == 0 { return (decode(body[body.startIndex..<i], encoding: encoding), body[(i + 1)...]) }
                i += 1
            }
        }
        return (decode(body, encoding: encoding), body[body.endIndex...])
    }

    private static func decode(_ bytes: ArraySlice<UInt8>, encoding: UInt8) -> String {
        let data = Data(bytes)
        switch encoding {
        case 0: return String(data: data, encoding: .isoLatin1) ?? ""
        case 1: return String(data: data, encoding: .utf16) ?? ""
        case 2: return String(data: data, encoding: .utf16BigEndian) ?? ""
        default: return String(decoding: data, as: UTF8.self)
        }
    }
}

private extension UInt32 {
    init<C: RandomAccessCollection>(bigEndian bytes: C, at index: C.Index) where C.Element == UInt8 {
        var value: UInt32 = 0
        var i = index
        for _ in 0..<4 {
            value = (value << 8) | UInt32(bytes[i])
            i = bytes.index(after: i)
        }
        self = value
    }
}
