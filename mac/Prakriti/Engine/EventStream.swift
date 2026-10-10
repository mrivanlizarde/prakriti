import CoreServices
import Darwin
import Foundation

/// One delivery of file-system changes under the watched folders.
struct EventBatch: Sendable {
    /// The changed paths that could be a recording (media files, or folders that may hold one).
    var paths: [String] = []
    /// Every event in the delivery, relevant or not.
    var count = 0
    /// The newest event id in the delivery, saved so the next launch replays from here.
    var lastID: UInt64 = 0
    /// macOS dropped or merged events, or a watched folder itself moved: only a full look is safe.
    var mustRescan = false
    /// The replay of changes made while Prakriti was closed has finished.
    var historyDone = false
    /// Replayed events delivered before `historyDone` in this batch.
    var replayed = 0
}

/// FSEvents, file by file, over every watched folder. The last event id is saved after each batch
/// and passed back on launch, so changes made while Prakriti was closed are replayed (SCOPE 7.3,
/// research 02 §4.2). Apple calls that history advisory, so the watcher also looks through every
/// folder at launch, on wake, every 5 minutes, and whenever this stream says it dropped events.
final class EventStream: @unchecked Sendable {
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "studio.therowan.prakriti.events", qos: .utility)
    private let handler: @Sendable (EventBatch) -> Void
    private let paths: [String]
    private let since: FSEventStreamEventId
    private let latency: CFTimeInterval
    private var replaying: Bool

    /// - Parameter since: an event id saved by an earlier run, or nil for "from now on".
    init(paths: [String], since: UInt64?, latency: Double = 2, handler: @escaping @Sendable (EventBatch) -> Void) {
        self.paths = paths
        self.since = since ?? FSEventStreamEventId(kFSEventStreamEventIdSinceNow)
        self.latency = latency
        self.handler = handler
        self.replaying = since != nil
    }

    deinit { stop() }

    /// Starts delivering changes. False if macOS would not create the stream.
    @discardableResult
    func start() -> Bool {
        guard stream == nil, !paths.isEmpty else { return stream != nil }
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot
                                             | kFSEventStreamCreateFlagUseCFTypes)
        guard let created = FSEventStreamCreate(kCFAllocatorDefault, EventStream.callback, &context, paths as CFArray,
                                                since, latency, flags) else { return false }
        FSEventStreamSetDispatchQueue(created, queue)
        guard FSEventStreamStart(created) else {
            FSEventStreamInvalidate(created)
            FSEventStreamRelease(created)
            return false
        }
        stream = created
        return true
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    /// The id of the newest event on this Mac right now.
    static var currentID: UInt64 { FSEventsGetCurrentEventId() }

    /// Event ids belong to one disk. The saved id is replayed only if the disk is the same one;
    /// otherwise ids mean nothing and the full look at launch covers the gap.
    static func deviceUUID(for path: String) -> String? {
        var info = stat()
        guard stat(path, &info) == 0, let uuid = FSEventsCopyUUIDForDevice(info.st_dev) else { return nil }
        return CFUUIDCreateString(nil, uuid) as String?
    }

    private static let callback: FSEventStreamCallback = { _, info, count, eventPaths, eventFlags, eventIDs in
        guard let info else { return }
        let me = Unmanaged<EventStream>.fromOpaque(info).takeUnretainedValue()
        let names = (Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String]) ?? []
        me.deliver(count: count, paths: names, flags: eventFlags, ids: eventIDs)
    }

    private func deliver(count: Int, paths names: [String], flags: UnsafePointer<FSEventStreamEventFlags>, ids: UnsafePointer<FSEventStreamEventId>) {
        var batch = EventBatch()
        batch.count = count
        let rescan = FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagUserDropped
                                             | kFSEventStreamEventFlagKernelDropped | kFSEventStreamEventFlagEventIdsWrapped
                                             | kFSEventStreamEventFlagRootChanged)
        let historyDone = FSEventStreamEventFlags(kFSEventStreamEventFlagHistoryDone)
        let isDirectory = FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir)
        for i in 0..<count {
            let flag = flags[i]
            batch.lastID = max(batch.lastID, ids[i])
            if flag & historyDone != 0 {
                batch.historyDone = true
                replaying = false
                continue
            }
            if replaying { batch.replayed += 1 }
            if flag & rescan != 0 { batch.mustRescan = true }
            guard i < names.count else { continue }
            let path = names[i]
            let name = (path as NSString).lastPathComponent
            if name.hasPrefix(".") { continue }
            if flag & isDirectory != 0 || FolderScan.isCandidate(name) { batch.paths.append(path) }
        }
        handler(batch)
    }
}
