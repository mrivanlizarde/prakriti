import Foundation

/// One media file a scan found: its path and its size at that moment.
struct ScannedFile: Sendable, Equatable {
    let path: String
    let size: Int64
}

/// Lists the recordings in a watched folder: engine v0's `candidates()`, ported rule for rule.
/// - Names starting with "." are skipped (hidden files, iCloud's own files).
/// - Folders are entered three levels deep (v0: `depth < 3`); OBS saves one dated folder per day.
/// - Only media files count (v0's list of extensions), and never a "-vertical." rendition: OBS
///   records a vertical copy beside each landscape one, and v0 never listed them, so its
///   state.json does not know them. Listing them would start work on files v0 deliberately left.
/// - Symbolic links are skipped, as v0's `isFile()` skips them: a link could point anywhere,
///   including a class or the archive.
/// Listing never downloads an iCloud placeholder; readiness does that, one file at a time.
enum FolderScan {
    enum Result: Sendable, Equatable {
        case files([ScannedFile])
        /// The folder is not there (moved, renamed, or a drive not attached).
        case missing
        /// macOS has not allowed Prakriti to read it (the Documents folder asks once).
        case notAllowed
        case failed(String)
        /// The scan did not answer in time. Reading a protected folder for the first time waits
        /// until someone answers macOS's permission prompt, so this usually means that.
        case timedOut
    }

    /// The file types engine v0 accepts.
    static let mediaExtensions: Set<String> = ["mp4", "mov", "mkv", "m4a", "wav", "mp3", "aac", "m4v"]
    static let maxDepth = 3

    static func isMedia(_ name: String) -> Bool {
        mediaExtensions.contains((name as NSString).pathExtension.lowercased())
    }

    /// A file name the watcher takes in: media, not hidden, not a vertical rendition.
    static func isCandidate(_ name: String) -> Bool {
        !name.hasPrefix(".") && isMedia(name) && name.range(of: "-vertical.", options: .caseInsensitive) == nil
    }

    static func scan(_ root: String) -> Result {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        let rootURL = URL(fileURLWithPath: root, isDirectory: true)
        let top: [URL]
        do {
            top = try fm.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: keys, options: [])
        } catch {
            return classify(error)
        }
        var found: [ScannedFile] = []
        func visit(_ entries: [URL], depth: Int) {
            for url in entries {
                let name = url.lastPathComponent
                if name.hasPrefix(".") { continue }
                guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
                if values.isSymbolicLink == true { continue }
                if values.isDirectory == true {
                    if depth < maxDepth, let children = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: []) {
                        visit(children, depth: depth + 1)
                    }
                } else if values.isRegularFile == true, isCandidate(name) {
                    found.append(ScannedFile(path: url.standardizedFileURL.path, size: Int64(values.fileSize ?? 0)))
                }
            }
        }
        visit(top, depth: 0)
        return .files(found.sorted { $0.path < $1.path })
    }

    private static func classify(_ error: Error) -> Result {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain {
            switch ns.code {
            case NSFileReadNoSuchFileError, NSFileNoSuchFileError: return .missing
            case NSFileReadNoPermissionError: return .notAllowed
            default: break
            }
        }
        if let posix = (ns.userInfo[NSUnderlyingErrorKey] as? NSError), posix.domain == NSPOSIXErrorDomain {
            switch Int32(posix.code) {
            case ENOENT, ENOTDIR: return .missing
            case EPERM, EACCES: return .notAllowed
            default: break
            }
        }
        return .failed(ns.localizedDescription)
    }
}
