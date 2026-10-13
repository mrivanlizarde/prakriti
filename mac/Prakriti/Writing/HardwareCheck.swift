import Foundation

// The hardware check (v2 part M5a, docs/v2/PLAN.md M5): what this Mac is, and whether it can run the
// writing model. A suggestion only: nothing switches to a cloud provider by itself.
//
// The threshold is measured, not guessed: Qwen3.8-27B holds about 33 to 36 GB while it works and the
// whole Mac peaked at 51 to 54 GB with it serving (docs/LOCAL-MODEL.md), so 64 GB or more can run it.

/// The facts the check reads. Tests inject their own; `current()` reads this Mac.
struct HardwareProfile: Sendable, Equatable {
    /// "Apple M5 Pro", from `sysctl machdep.cpu.brand_string`.
    var chip: String
    /// `ProcessInfo.physicalMemory`, in bytes.
    var memoryBytes: UInt64
    /// Nil when Apple Intelligence's on-device model can be used, else why not, in plain words.
    var appleIntelligenceUnavailable: String?

    static func current() -> HardwareProfile {
        HardwareProfile(chip: chipName(), memoryBytes: ProcessInfo.processInfo.physicalMemory,
                        appleIntelligenceUnavailable: AppleOnDeviceClient.unavailableReason)
    }

    static func chipName() -> String {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 1 else { return "This Mac" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0) == 0 else { return "This Mac" }
        let name = String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            .trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "This Mac" : name
    }

    /// Whole gigabytes as macOS shows them in About This Mac (64 for 68,719,476,736 bytes).
    var memoryGB: Int { Int((Double(memoryBytes) / 1_073_741_824).rounded()) }
}

/// The verdict, in the words the Models pane shows.
struct HardwareVerdict: Sendable, Equatable {
    /// "Apple M5 Pro, 64 GB. This Mac can run the writing model."
    var headline: String
    /// What to do about it, or nil when nothing needs doing.
    var suggestion: String?
    /// Apple on-device's state in one sentence.
    var appleIntelligence: String
    var canRunWritingModel: Bool

    static let neededGB = 64

    init(_ profile: HardwareProfile) {
        canRunWritingModel = profile.memoryGB >= Self.neededGB
        let mac = "\(profile.chip), \(profile.memoryGB) GB."
        if canRunWritingModel {
            headline = "\(mac) This Mac can run the writing model."
            suggestion = nil
        } else {
            headline = "\(mac) Writing a long recording needs a cloud key, or it waits."
            suggestion = "The writing model needs \(Self.neededGB) GB of memory. For talks, the Claude API can do the writing with your own key. Classes, and recordings with other people, still wait for a model on this Mac."
        }
        appleIntelligence = profile.appleIntelligenceUnavailable ?? "Apple Intelligence is on, so Apple on-device can make tags and summaries."
    }
}
