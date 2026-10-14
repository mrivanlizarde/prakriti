import Foundation

// The welcome window's words (v2 part M2b; docs/v2/design-spec.md 4.2, with the copy source in
// docs/v2/help-notes/welcome-panels.md). Five panels, each a symbol, a title, one line and its rows.
//
// The welcome describes only what this build does, the same rule Help follows (docs/v2/PLAN.md, M2):
// every row names the capabilities it describes. A row with `requires` shows only once every one of them
// is built; a row with `unless` shows only until every one of them is built, so the sentence that is true
// of today's app gives way to the v2 sentence in the same commit that builds the feature. Each later part
// that switches a capability on reads the rows that name it and makes each sentence true of what it built.
// The copy rules are tested (`WelcomeTests`): no em or en dash, no "we", no "Processing", "click" never
// "tap", and no feature name of a part that is not built.

/// One piece of welcome text and the capabilities it describes.
struct WelcomeText: Sendable, Equatable {
    let text: String
    /// Shown only once every capability here is built. Empty: always.
    var requires: Set<Capability> = []
    /// Shown only until every capability here is built. Empty: always.
    var unless: Set<Capability> = []

    init(_ text: String, requires: Set<Capability> = [], unless: Set<Capability> = []) {
        self.text = text
        self.requires = requires
        self.unless = unless
    }

    func isVisible(with capabilities: Set<Capability>) -> Bool {
        WelcomeContent.isVisible(requires: requires, unless: unless, with: capabilities)
    }
}

/// What a row's button does. Only the last panel's rows have one.
enum WelcomeAction: String, Sendable, Equatable {
    /// Choose Folder...: the system's Open panel, then the folder is watched (Ask me first).
    case chooseFolder
    /// Turn On Notifications, or Open Notification Settings when they are turned off.
    case notifications
    /// Open Help: the Help window.
    case openHelp
    /// Settings, Models, with this Mac's verdict as the row's status (v2 part M5b).
    case models
}

/// One row: a symbol, a headline and a sentence, read as one paragraph.
struct WelcomeRow: Sendable, Equatable, Identifiable {
    let id: String
    let symbol: String
    /// Drawn semibold before the sentence. Steps and the privacy points have none.
    let headline: String?
    let sentence: String
    var requires: Set<Capability> = []
    var unless: Set<Capability> = []
    var action: WelcomeAction?

    init(_ id: String, symbol: String, headline: String? = nil, _ sentence: String,
         requires: Set<Capability> = [], unless: Set<Capability> = [], action: WelcomeAction? = nil) {
        self.id = id
        self.symbol = symbol
        self.headline = headline
        self.sentence = sentence
        self.requires = requires
        self.unless = unless
        self.action = action
    }

    func isVisible(with capabilities: Set<Capability>) -> Bool {
        WelcomeContent.isVisible(requires: requires, unless: unless, with: capabilities)
    }
}

struct WelcomePanel: Sendable, Equatable, Identifiable {
    enum Style: Sendable, Equatable {
        /// Each row carries its own symbol.
        case rows
        /// Numbered steps: each visible row is drawn with its number (1.circle, 2.circle...).
        case steps
    }

    let id: String
    let symbol: String
    let title: String
    /// The line under the title: the first visible one is shown. "{count}" becomes the number of visible
    /// rows in words ("three steps"), so the line never counts a row this build hides.
    let lines: [WelcomeText]
    let style: Style
    let rows: [WelcomeRow]
    /// "More in Help: <the article's title>", opening that article.
    var helpArticle: String?
}

/// A panel as this build shows it: the visible line and rows, steps numbered.
struct VisibleWelcomePanel: Sendable, Equatable, Identifiable {
    let id: String
    let symbol: String
    let title: String
    let line: String
    let rows: [WelcomeRow]
    let isSteps: Bool
    let helpArticle: String?

    /// The symbol a row is drawn with: its own, or its step number.
    func symbol(for row: WelcomeRow) -> String {
        guard isSteps, let index = rows.firstIndex(of: row) else { return row.symbol }
        return "\(index + 1).circle"
    }
}

enum WelcomeContent {
    /// The welcome's version, stored as `welcomeSeenVersion` once it has been shown. The window opens by
    /// itself only while the stored number is lower. 2 is Prakriti v2's welcome, the first one; a later
    /// "What's New" panel raises it (docs/v2/design-spec.md 4.1).
    static let version = 2

    static func isVisible(requires: Set<Capability>, unless: Set<Capability>, with capabilities: Set<Capability>) -> Bool {
        requires.isSubset(of: capabilities) && (unless.isEmpty || !unless.isSubset(of: capabilities))
    }

    /// The panels this build shows, in order. A panel with no visible row is left out.
    static func visiblePanels(with capabilities: Set<Capability> = Capabilities.built) -> [VisibleWelcomePanel] {
        panels.compactMap { panel in
            let rows = panel.rows.filter { $0.isVisible(with: capabilities) }
            guard !rows.isEmpty, let line = panel.lines.first(where: { $0.isVisible(with: capabilities) }) else { return nil }
            return VisibleWelcomePanel(id: panel.id, symbol: panel.symbol, title: panel.title,
                                       line: line.text.replacingOccurrences(of: "{count}", with: numberWord(rows.count)),
                                       rows: rows, isSteps: panel.style == .steps, helpArticle: panel.helpArticle)
        }
    }

    /// Small numbers in words, as the copy writes them ("three steps").
    static func numberWord(_ n: Int) -> String {
        let words = ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        return words.indices.contains(n) ? words[n] : String(n)
    }

    /// Every word the panels hold, visible or not, for the copy test.
    static var everyString: [(where: String, text: String)] {
        var out: [(String, String)] = []
        for panel in panels {
            out.append(("\(panel.id) title", panel.title))
            for (n, line) in panel.lines.enumerated() { out.append(("\(panel.id) line \(n + 1)", line.text)) }
            for row in panel.rows {
                if let headline = row.headline { out.append(("\(panel.id) \(row.id) headline", headline)) }
                out.append(("\(panel.id) \(row.id)", row.sentence))
            }
        }
        return out
    }

    // MARK: The five panels

    static let panels: [WelcomePanel] = [
        // Panel 1: what Prakriti does. At v2 part M2b it lists finding recordings, the podcast and
        // "nothing is posted without you" (docs/v2/PLAN.md, M2).
        WelcomePanel(
            id: "welcome", symbol: "sparkles", title: "Welcome to Prakriti",
            lines: [WelcomeText("Prakriti turns a raw recording into finished work, on this Mac.")],
            style: .rows,
            rows: [
                WelcomeRow("finds", symbol: "tray.and.arrow.down", headline: "It finds your recordings.",
                           "Anything saved in a folder you choose is found on its own."),
                WelcomeRow("edit", symbol: "wand.and.sparkles", headline: "It makes the edit.",
                           "Pauses, filler words and retakes come out. Captions, titles, zooms and transitions go in.",
                           requires: [.video, .style]),
                WelcomeRow("podcast", symbol: "shippingbox", headline: "It makes the podcast episode.",
                           "The sound is leveled and checked, and the words become a transcript with captions.",
                           unless: [.video, .shorts, .timelines]),
                WelcomeRow("files", symbol: "shippingbox", headline: "It hands you finished files.",
                           "A video ready to upload, short vertical clips, a podcast episode, and a timeline you can open in Final Cut Pro or DaVinci Resolve.",
                           requires: [.video, .shorts, .timelines]),
                WelcomeRow("yours", symbol: "checkmark.seal", headline: "Nothing is posted without you.",
                           "You listen, then approve it. Uploading is always yours.",
                           unless: [.viewer, .people]),
                WelcomeRow("yours-v2", symbol: "checkmark.seal", headline: "Nothing is posted without you.",
                           "You watch it, choose who appears and approve it. Uploading is always yours.",
                           requires: [.viewer, .people]),
            ]),

        // Panel 2: capture, the answer to "including how to capture the best video" (REQUEST item 2).
        // Hybrid MOV joins Hybrid MP4 with the capture check (M4b), as docs/v2/PLAN.md section 5 fixed it.
        WelcomePanel(
            id: "record", symbol: "camera.viewfinder", title: "Record for the Best Results",
            lines: [WelcomeText("Prakriti does its best work with a clean recording. These {count} things make the biggest difference.")],
            style: .rows,
            rows: [
                WelcomeRow("frame", symbol: "camera.viewfinder", headline: "Frame at eye level.",
                           "Put the speaker in the middle of the picture, with a little space above the head.",
                           unless: [.shorts]),
                WelcomeRow("frame-v2", symbol: "camera.viewfinder", headline: "Frame at eye level.",
                           "Put the speaker in the middle of the picture with a little space above the head, so the vertical clips keep them in frame.",
                           requires: [.shorts]),
                WelcomeRow("settings", symbol: "video.badge.checkmark", headline: "Record 4K or 1080p at 30 frames per second.",
                           "Keep the same settings for the whole session. In OBS, record Hybrid MP4, never MKV.",
                           unless: [.captureCheck]),
                WelcomeRow("settings-v2", symbol: "video.badge.checkmark", headline: "Record 4K or 1080p at 30 frames per second.",
                           "Keep the same settings for the whole session. In OBS, record Hybrid MOV or Hybrid MP4, never MKV.",
                           requires: [.captureCheck]),
                WelcomeRow("microphones", symbol: "mic", headline: "Give each speaker a microphone.",
                           "Record each one to its own track. A clip-on microphone, a hand's width from the mouth, works well."),
                WelcomeRow("light", symbol: "light.max", headline: "Light the face.",
                           "Light from the front, a little to one side. Avoid a bright window behind the speaker."),
                WelcomeRow("students", symbol: "person.2", headline: "Keep students out of frame.",
                           "Seat them behind the camera or beside it, and tell them each time that the class is recorded.",
                           unless: [.people]),
                WelcomeRow("students-v2", symbol: "person.2", headline: "Keep students out of frame.",
                           "Seat them behind the camera. Anyone Prakriti does not know is blurred and their voice removed, so a clean frame means less is cut.",
                           requires: [.people]),
                WelcomeRow("test", symbol: "headphones", headline: "Record a 10-second test.",
                           "Play it back with headphones, and check the face, the framing and each voice."),
            ],
            helpArticle: "capture-the-best-video"),

        // Panel 3: from a recording to finished files, as numbered steps.
        WelcomePanel(
            id: "outputs", symbol: "shippingbox", title: "How Outputs Work",
            lines: [WelcomeText("From a raw recording to finished files, in {count} steps.", unless: [.thumbnails]),
                    WelcomeText("From a raw recording to files ready to upload, in {count} steps.", requires: [.thumbnails])],
            style: .steps,
            rows: [
                WelcomeRow("found", symbol: "1.circle",
                           "Prakriti finds a new recording and makes its outputs, or waits for you if its folder is set to Ask me first. In Progress shows the step it is on.",
                           unless: [.progress]),
                WelcomeRow("found-v2", symbol: "1.circle",
                           "Prakriti finds a new recording and makes its outputs, or waits if its folder is set to Ask me first. The recording shows how far along it is and the time left, and Activity lists every step.",
                           requires: [.progress]),
                WelcomeRow("review-viewer", symbol: "2.circle",
                           "Open it to listen in the Viewer. Select words in the transcript and choose Remove from the Edit, or set where the episode starts and ends in the inspector's Info tab, then choose Make Again.",
                           requires: [.viewer], unless: [.video]),
                WelcomeRow("review-v2", symbol: "2.circle",
                           "Watch the edit in the Viewer. The bar under the picture shows what stayed and what was taken out.",
                           requires: [.viewer, .video]),
                WelcomeRow("people-audio", symbol: "3.circle",
                           "Under People in the inspector, choose who is in the episode, and keep or mute each name said aloud.",
                           requires: [.choices], unless: [.people]),
                WelcomeRow("people", symbol: "3.circle", "Under People, choose who appears in each output.",
                           requires: [.people]),
                WelcomeRow("direction", symbol: "4.circle",
                           "Under Direction, say how the edit should feel, for example \"more energetic\", then choose Make Again.",
                           requires: [.style]),
                WelcomeRow("approve", symbol: "5.circle",
                           "Approve it. Prakriti copies the finished files to your Approved folder with a receipt, and you upload them.",
                           unless: [.thumbnails]),
                WelcomeRow("approve-v2", symbol: "5.circle",
                           "Approve it. The finished files and an upload checklist are ready, and you press Upload.",
                           requires: [.thumbnails]),
            ]),

        // Panel 4: privacy, in the shape Apple's pro apps use (a title, one line, three points, a link).
        WelcomePanel(
            id: "privacy", symbol: "hand.raised", title: "Privacy",
            lines: [WelcomeText("Prakriti keeps every recording on this Mac, and holds back anything a person has not checked.",
                                unless: [.people, .video]),
                    WelcomeText("Prakriti protects everyone who did not choose to be in the video.", requires: [.people, .video])],
            style: .rows,
            rows: [
                WelcomeRow("hidden", symbol: "eye.slash",
                           "People Prakriti does not know are blurred and their voices removed, unless you choose otherwise.",
                           requires: [.people]),
                WelcomeRow("named", symbol: "person.crop.square",
                           "People lists everyone you name, with their recordings. Prakriti keeps their name and their release, never their face or voice.",
                           requires: [.gallery], unless: [.recognition]),
                WelcomeRow("remembered", symbol: "person.badge.shield.checkmark",
                           "Prakriti remembers a face or a voice only for someone you name who has agreed. Everyone else is forgotten when the work is done.",
                           requires: [.recognition]),
                WelcomeRow("approve-talks", symbol: "person.2",
                           "Only a talk with one teacher speaking can be approved, and a class is never made ready to upload.",
                           unless: [.people]),
                WelcomeRow("notices", symbol: "bell",
                           "Notices never show a file name or a title, because they appear on the lock screen.",
                           unless: [.people]),
                WelcomeRow("cloud", symbol: "lock",
                           "Recordings never leave this Mac. With an Anthropic or OpenAI key, only words are sent, and only for a talk whose people have been checked. Until Prakriti checks who appears, nothing is sent.",
                           unless: [.cloudProviders, .people]),
                WelcomeRow("cloud-v2", symbol: "lock",
                           "Recordings never leave this Mac. With an Anthropic or OpenAI key, only words are sent, and never for a class or a recording where other people appear.",
                           requires: [.cloudProviders, .people]),
            ],
            helpArticle: "people-and-privacy"),

        // Panel 5: three things to set now, each optional. The notification ask lives here, after a
        // reason, never at launch (docs/v2/design-spec.md 4.2). Where models write, with this Mac's verdict,
        // joined in M5b as a button to Settings, Models rather than the spec's pop-up: one pop-up for every
        // task would set tasks behind Ivan's back, and the lock decides per recording anyway.
        WelcomePanel(
            id: "start", symbol: "checklist", title: "Get Started",
            lines: [WelcomeText("Each of these is optional and can be changed later.")],
            style: .rows,
            rows: [
                WelcomeRow("folder", symbol: "folder", headline: "Choose a folder to watch.",
                           "Recordings saved there are found on their own. A new folder asks you before anything is made.",
                           action: .chooseFolder),
                WelcomeRow("notifications", symbol: "bell", headline: "Get a notice when something needs you.",
                           "A notice says when a recording is waiting for your yes, needs a decision or could not finish.",
                           action: .notifications),
                WelcomeRow("models", symbol: "cpu", headline: "Choose where models write.",
                           "This Mac writes by itself when it has the memory. An Anthropic or OpenAI key can do the writing instead, only for recordings the privacy lock lets out.",
                           requires: [.cloudProviders], action: .models),
                WelcomeRow("help", symbol: "questionmark.circle", headline: "Find help at any time.",
                           "Choose Help > Prakriti Help, or type in the Help menu's search field.",
                           action: .openHelp),
            ]),
    ]
}
