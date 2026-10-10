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
    static func run(_ executable: URL, _ arguments: [String], captureStdout: Bool = true,
                    timeout: Duration? = nil) async throws -> ToolOutput {
        let tool = executable.lastPathComponent
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw ToolError(kind: .missing, tool: tool, status: -1, stderrTail: executable.path)
        }
        let job = Job(executable: executable, arguments: arguments, captureStdout: captureStdout)
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
        private let state = Mutex<(timedOut: Bool, stopped: Bool)>((false, false))

        init(executable: URL, arguments: [String], captureStdout: Bool) {
            self.captureStdout = captureStdout
            process.executableURL = executable
            process.arguments = arguments
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = ToolPaths.searchPath + (environment["PATH"].map { ":" + $0 } ?? "")
            process.environment = environment
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = captureStdout ? stdoutPipe : FileHandle.nullDevice
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
            process.terminationHandler = { _ in group.leave() }
            do {
                try process.run()
            } catch {
                completion(.failure(ToolError(kind: .couldNotStart, tool: process.executableURL?.lastPathComponent ?? "tool",
                                              status: -1, stderrTail: error.localizedDescription)))
                return
            }
            // Read both pipes to their end on background threads, so a chatty tool never fills a
            // pipe and stalls.
            if captureStdout {
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
                let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + seconds) { [self] in
                    guard process.isRunning else { return }
                    state.withLock { $0.timedOut = true }
                    process.terminate()
                }
            }
            let process = self.process
            group.notify(queue: .global(qos: .utility)) {
                let out = outBox.withLock { String(decoding: $0, as: UTF8.self) }
                let err = errBox.withLock { String(decoding: $0, as: UTF8.self) }
                completion(.success(ToolOutput(status: process.terminationStatus, stdout: out, stderr: err)))
            }
        }

        func stop() {
            state.withLock { $0.stopped = true }
            if process.isRunning { process.terminate() }
        }
    }
}
