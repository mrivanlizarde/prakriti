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
    /// Faces found in a recording: the People tab, the people line, the Other People Appear filter and notice
    /// (M6a). Voices and choices are not part of it.
    case faces
    /// Voices found in a recording (from microphone tracks, else told apart on the mixed track), linked to faces;
    /// People You Name in Settings, Privacy, Who is teaching, Name for This Recording, Check People, and the privacy
    /// lock fed by the people check (M6b).
    case voices
    /// Include, Hide Face or Leave Out per person, applied to the podcast; names said aloud kept or muted; the audio
    /// output check; Approve waiting for each (M6c). Hiding faces in pictures is `people` (M6d).
    case choices
    /// Faces hidden in pictures: the card picture chosen after the people pass, with every face of anyone not included
    /// hidden by `FaceHide`, and the Viewer's People overlay (M6d). Faces hidden in the video and every other output are
    /// `people`.
    case hiding
    /// Faces hidden and voices removed in every output Prakriti makes, the video included (M8d), and what later parts
    /// build on it. Its Help text describes the whole of that, so it waits for the video.
    case people
    /// The People gallery of every named person, Name Only included: the person page, the consent sheet (Name This
    /// Person), the sealed vault, Forget Face and Voice, retention (M7a).
    case gallery
    /// Named people with a release recognized in new recordings, Review Possible Matches, Merge 2 People (M7b).
    case recognition
    /// The edit plan: Plan the Edit, `edit-plan.json`, the plan on the Original's Timeline-lite (M8a). No video.
    case editPlan
    /// The edited MP4 made from the edit plan, with its captions, Description.txt and Ready checklist, Make Video, and the
    /// Edited video output (M8b). Not watched in the Viewer and nobody hidden in it yet: those are `video` and `people`.
    case renderedVideo
    /// The edited video in the Viewer, made through the same compositor as the file (M8c); its Help text describes the
    /// whole video, so the zooms and text in it wait for `style` (M9).
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
    /// Activity window (M4a), the capture check (M4b), Anthropic and OpenAI (M5b), faces (M6a), voices and names
    /// (M6b), choices applied to audio (M6c), hiding in pictures (M6d), the People gallery (M7a), recognition (M7b), the
    /// edit plan (M8a), and the rendered MP4 (M8b). Each later part switches its own on.
    static let built: Set<Capability> = [.help, .welcome, .viewer, .progress, .captureCheck, .cloudProviders, .faces, .voices, .choices, .hiding, .gallery,
                                         .recognition, .editPlan, .renderedVideo]

    /// Every capability, for the test that every article and every block is visible once all are built.
    static let all = Set(Capability.allCases)
}
