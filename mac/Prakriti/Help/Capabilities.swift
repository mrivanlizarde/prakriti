import Foundation

/// What this build of Prakriti can do, as far as Help is concerned. Every Help article, and every block
/// inside one, can name the capability it describes; anything whose capability is not built is hidden.
/// Reason: v1's help described features that did not exist yet (a viewer, faces, an edited video), and
/// Ivan's rule is that Help only ever describes what the app does today (docs/v2/PLAN.md, M2).
///
/// Each capability is switched on in `Capabilities.built` by the part of the v2 build that makes it,
/// in the same commit as the feature (docs/v2/PLAN.md, section 6).
enum Capability: String, CaseIterable, Sendable {
    /// The Help window itself (v2 part M2a).
    case help
    /// The welcome window and Help, Welcome to Prakriti (M2b).
    case welcome
    /// The Viewer: playing every output inside the app, the transcript under it, Timeline-lite (M3b).
    case viewer
    /// Stage, percent and time left everywhere; the Activity window (M4a).
    case progress
    /// Every track of a new recording measured, with a finding and a capture tip; Hybrid MOV (M4b).
    case captureCheck
    /// Anthropic and OpenAI as providers, with their keys in the Keychain (M5b).
    case cloudProviders
    /// Faces and voices found in a recording, and Include, Blur Face or Remove per person (M6).
    case people
    /// The People gallery of named people (M7).
    case gallery
    /// The rendered, edited video and its Ready checklist (M8).
    case video
    /// The house style, presets and the direction field (M9).
    case style
    /// Timelines for Final Cut Pro and DaVinci Resolve (M10).
    case timelines
    /// Vertical shorts (M11a).
    case shorts
    /// Thumbnails, the Approve sheet and Ready (M11b).
    case thumbnails
    /// Moments from another recording (M12).
    case merge
}

enum Capabilities {
    /// What this build does: Help (M2a), the welcome window (M2b), the Viewer (M3b), progress with the
    /// Activity window (M4a), the capture check (M4b) and Anthropic and OpenAI (M5b). Each later part switches
    /// its own on.
    static let built: Set<Capability> = [.help, .welcome, .viewer, .progress, .captureCheck, .cloudProviders]

    /// Every capability, for the test that every article and every block is visible once all are built.
    static let all = Set(Capability.allCases)
}
