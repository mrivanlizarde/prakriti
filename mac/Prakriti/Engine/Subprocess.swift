import Foundation
import Synchronization

/// The outside tools the pipeline runs, always by absolute path. Reason: a login item or launch
/// agent does not get Homebrew's PATH, and the agency backup on this Mac failed 66 nights in a row
/// on exactly that, silently. Engine v0 uses the same paths.
struct ToolPaths: Sendable {
    var ffmpeg: URL
    var ffprobe: URL
    var parakeet: URL
    var brctl: URL

    static var standard: ToolPaths {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ToolPaths(ffmpeg: URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg"),
                         ffprobe: URL(fileURLWithPath: "/opt/homebrew/bin/ffprobe"),
                         parakeet: home.appending(path: "Code/transcribe-3/.venv/bin/parakeet-mlx"),
                         brctl: URL(fileURLWithPath: "/usr/bin/brctl"))
    }

    /// The PATH every child process gets. Parakeet reads audio by calling ffmpeg by name, so
    /// Homebrew's folder must be on it even when Prakriti was started with a bare PATH.
    static let searchPath = "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
}

struct ToolOutput: Sendable {
    let status: Int32
    let stdout: String
    let stderr: String
}

/// Why a tool did not finish. `stderrTail` is for the log only, never shown to Ivan as is.
struct ToolError: Error, Sendable {
    enum Kind: Sendable { case missing, failed, timedOut, couldNotStart }
    let kind: Kind
    let tool: String
    let status: Int32
    let stderrTail: String

    var logLine: String {
        switch kind {
        case .missing: "\(tool) is not installed at its expected path"
        case .couldNotStart: "\(tool) could not be started: \(stderrTail)"
        case .timedOut: "\(tool) ran past its time limit and was stopped"
        case .failed: "\(tool) exited \(status): \(stderrTail)"
        }
    }
}

/// Runs one tool and waits for it without blocking a thread of the caller's: output is read on
/// background threads, and the process is stopped if the task is cancelled or runs past `timeout`.
enum Subprocess {
    /// - Parameters:
    ///   - onStdoutLine: each line the tool writes on stdout, as it comes (ffmpeg's `-progress pipe:1`, v2 part
    ///     M4a). stdout is then always read, and kept only when `captureStdout` is true.
    ///   - control: pauses and resumes the tool for a make that is paused (v2 part M4a). The tool waits to
    ///     start while it is paused, and its time limit moves on by the time it spent paused.
    static func run(_ executable: URL, _ arguments: [String], captureStdout: Bool = true,
                    timeout: Duration? = nil, onStdoutLine: (@Sendable (String) -> Void)? = nil,
                    control: ProcessControl? = nil) async throws -> ToolOutput {
        let tool = executable.lastPathComponent
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw ToolError(kind: .missing, tool: tool, status: -1, stderrTail: executable.path)
        }
        if let control { await control.waitWhilePaused() }
        try Task.checkCancellation()
        let job = Job(executable: executable, arguments: arguments, captureStdout: captureStdout, onStdoutLine: onStdoutLine, control: control)
        let output = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ToolOutput, Error>) in
                job.start(timeout: timeout) { result in continuation.resume(with: result) }
            }
        } onCancel: {
            job.stop()
        }
        try Task.checkCancellation()
        if job.timedOut {
            throw ToolError(kind: .timedOut, tool: tool, status: output.status, stderrTail: tail(output.stderr))
        }
        guard output.status == 0 else {
            throw ToolError(kind: .failed, tool: tool, status: output.status, stderrTail: tail(output.stderr))
        }
        return output
    }

    /// The last few lines of a tool's error output, for the log.
    static func tail(_ text: String, characters: Int = 600) -> String {
        String(text.suffix(characters)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// One running process. Process and Pipe are not Sendable, so every touch goes through a lock.
    private final class Job: @unchecked Sendable {
        private let process = Process()
        private let stdoutPipe = Pipe()
        private let stderrPipe = Pipe()
        private let captureStdout: Bool
        private let onStdoutLine: (@Sendable (String) -> Void)?
        private let control: ProcessControl?
        private let state = Mutex<(timedOut: Bool, stopped: Bool)>((false, false))

        init(executable: URL, arguments: [String], captureStdout: Bool, onStdoutLine: (@Sendable (String) -> Void)?, control: ProcessControl?) {
            self.captureStdout = captureStdout
            self.onStdoutLine = onStdoutLine
            self.control = control
            process.executableURL = executable
            process.arguments = arguments
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = ToolPaths.searchPath + (environment["PATH"].map { ":" + $0 } ?? "")
            process.environment = environment
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = captureStdout || onStdoutLine != nil ? stdoutPipe : FileHandle.nullDevice
            process.standardError = stderrPipe
        }

        var timedOut: Bool { state.withLock { $0.timedOut } }

        func start(timeout: Duration?, completion: @escaping @Sendable (Result<ToolOutput, Error>) -> Void) {
            let group = DispatchGroup()
            let outBox = Mutex<Data>(Data())
            let errBox = Mutex<Data>(Data())
            if state.withLock({ $0.stopped }) {
                completion(.failure(CancellationError()))
                return
            }
            group.enter() // left when the process exits
            let control = self.control
            process.terminationHandler = { finished in
                control?.detach(finished.processIdentifier)
                group.leave()
            }
            do {
                try process.run()
            } catch {
                completion(.failure(ToolError(kind: .couldNotStart, tool: process.executableURL?.lastPathComponent ?? "tool",
                                              status: -1, stderrTail: error.localizedDescription)))
                return
            }
            control?.attach(process.processIdentifier)
            // Read both pipes to their end on background threads, so a chatty tool never fills a
            // pipe and stalls.
            if let onStdoutLine {
                // Line by line, as the tool writes them (ffmpeg's progress), kept only when asked.
                group.enter()
                let handle = stdoutPipe.fileHandleForReading
                let keep = captureStdout
                DispatchQueue.global(qos: .utility).async {
                    var kept = Data()
                    var pending = Data()
                    while true {
                        let chunk = handle.availableData
                        if chunk.isEmpty { break }
                        if keep { kept.append(chunk) }
                        pending.append(chunk)
                        while let newline = pending.firstIndex(of: 0x0A) {
                            let line = String(decoding: pending[pending.startIndex..<newline], as: UTF8.self)
                            pending.removeSubrange(pending.startIndex...newline)
                            onStdoutLine(line)
                        }
                    }
                    if !pending.isEmpty { onStdoutLine(String(decoding: pending, as: UTF8.self)) }
                    outBox.withLock { $0 = kept }
                    group.leave()
                }
            } else if captureStdout {
                group.enter()
                let handle = stdoutPipe.fileHandleForReading
                DispatchQueue.global(qos: .utility).async {
                    let data = handle.readDataToEndOfFile()
                    outBox.withLock { $0 = data }
                    group.leave()
                }
            }
            group.enter()
            let errHandle = stderrPipe.fileHandleForReading
            DispatchQueue.global(qos: .utility).async {
                let data = errHandle.readDataToEndOfFile()
                errBox.withLock { $0 = data }
                group.leave()
            }
            if let timeout {
                scheduleTimeout(after: timeout, pausedAtStart: control?.pausedTotal ?? .zero)
            }
            let process = self.process
            group.notify(queue: .global(qos: .utility)) {
                let out = outBox.withLock { String(decoding: $0, as: UTF8.self) }
                let err = errBox.withLock { String(decoding: $0, as: UTF8.self) }
                completion(.success(ToolOutput(status: process.terminationStatus, stdout: out, stderr: err)))
            }
        }

        /// The time limit counts only the time the tool ran: time spent paused moves it on (v2 part M4a).
        private func scheduleTimeout(after delay: Duration, pausedAtStart: Duration) {
            let seconds = Double(delay.components.seconds) + Double(delay.components.attoseconds) / 1e18
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + seconds) { [self] in
                guard process.isRunning else { return }
                let paused = (control?.pausedTotal ?? .zero) - pausedAtStart
                if paused > .milliseconds(1) {
                    scheduleTimeout(after: paused, pausedAtStart: pausedAtStart + paused)
                    return
                }
                state.withLock { $0.timedOut = true }
                terminate()
            }
        }

        /// A stopped (paused) process gets SIGTERM only once it runs again, so it is continued first.
        private func terminate() {
            guard process.isRunning else { return }
            kill(process.processIdentifier, SIGCONT)
            process.terminate()
        }

        func stop() {
            state.withLock { $0.stopped = true }
            terminate()
        }
    }
}
