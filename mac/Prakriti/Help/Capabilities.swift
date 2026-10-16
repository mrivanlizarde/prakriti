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
    /// Faces hidden and voices removed in every output Prakriti makes, timelines and shorts included, and what later parts
    /// build on it. Its Help text describes the whole of that, so it stays off until the last of those outputs exists (M10b,
    /// M11; M13 at the latest). The edited video's own hiding (M8d) is described under `renderedVideo`.
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
    /// The edited video in the Viewer, made through the same compositor as the file; Restore and Remove on the plan's spans,
    /// Delete and Undo, struck-through words and the Captions overlay (M8c). The Help text about zooms, text and transitions in
    /// the video is `style` (M9); hidden faces in it (M8d) are described under `renderedVideo`.
    case video
    /// The House Style pane and what it does to the edited video: the style's pauses, punch-ins and slow push-ins centred on
    /// the teacher's face, Pace, Teaching, and the room at the end (M9a). Presets chosen per recording, the direction field,
    /// text on screen and transitions are `style`.
    case houseStyle
    /// Text on the edited video: the title for 2 s at the start and each included teacher's name once (lower third), in
    /// Alegreya Sans, never over a face; the House Style pane's Text on Screen (M9b). Key phrases and term cards are `style`.
    case textOnScreen
    /// Direction for one recording (M9c): the direction field, presets, Pace and Length in the Outputs tab, the rules table and
    /// the planning model, the chips, the parts of the talk (beats) and the choice among them under a length, and the plan in
    /// plain lines before the video is made. The Direction tab, versions, key phrases, the hook and chapters are `style`.
    case direction
    /// The rest of M9 (M9d): key-phrase text, term cards, the opening line (the hook), the held moment, chapters, versions, the
    /// Direction tab and the marks lane.
    case style
    /// Timelines for Final Cut Pro and DaVinci Resolve (M10a): FCPXML 1.14 and 1.10, the texts as graphics clips, the media as a
    /// clone, Read Me, Make Timelines and Open In, the File menu's export items; written only when everyone is included. The
    /// privacy-safe media for a recording with anyone hidden (M10b) is described under `people`.
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
    /// edit plan (M8a), the rendered MP4 (M8b), the video in the Viewer (M8c), the House Style with its zooms (M9a), the title and
    /// names on screen (M9b), direction for one recording (M9c), and the opening line, key phrases, terms, chapters, versions and
    /// the Direction tab (M9d), and the timelines for Final Cut Pro and DaVinci Resolve (M10a). Each later part switches its own on.
    static let built: Set<Capability> = [.help, .welcome, .viewer, .progress, .captureCheck, .cloudProviders, .faces, .voices, .choices, .hiding, .gallery,
                                         .recognition, .editPlan, .renderedVideo, .video, .houseStyle, .textOnScreen, .direction, .style, .timelines]

    /// Every capability, for the test that every article and every block is visible once all are built.
    static let all = Set(Capability.allCases)
}
