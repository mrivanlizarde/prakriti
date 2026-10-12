import AppKit
import SwiftUI

/// The transcript under the player (v2 part M3b, design spec 3.4.4): paragraphs of words at 17 pt, each
/// paragraph under its time at 15 pt in monospaced digits. Click a word to play from it; drag or
/// Shift-click to select words, then Remove from the Edit or Keep in the Edit (the bar under it, the
/// context menu, the Edit menu). Words the trim or a cut take out are struck through in the secondary
/// color. With Follow Playback on, the sentence playing is marked with the accent at 12 percent and kept in
/// view. Command-F finds in it.
///
/// It is AppKit text (`NSTextView`), not SwiftUI views. Reason: a word must be clickable on its own and a
/// run of words selectable across lines, in a transcript of up to about 10,000 words (6 Sep: 9,952), with
/// the system's Find bar; one SwiftUI view per word was the alternative, and a selection cannot cross views.
struct TranscriptTextView: NSViewRepresentable {
    let document: TranscriptDocument
    /// The parts of the original the edit keeps, as the trim and cuts stand now (made or not).
    let kept: [Mastering.Span]
    let playing: Int?
    /// The words chosen (the Viewer's own record), shown as the text's selection.
    let selected: ClosedRange<Int>?
    let follow: Bool
    let revealRequest: Int
    let findRequest: Int
    let actions: Actions

    struct Actions {
        var playWord: (Int) -> Void
        var select: (ClosedRange<Int>?) -> Void
        var remove: () -> Void
        var keep: () -> Void
        var togglePlay: () -> Void
        var shuttle: (Character) -> Void
        var back: () -> Void
        var canRemove: () -> Bool
        var canKeep: () -> Bool
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        let text = PlayableTextView(frame: .zero)
        text.isEditable = false
        text.isSelectable = true
        text.isRichText = true
        text.drawsBackground = false
        text.usesFindBar = true
        text.isIncrementalSearchingEnabled = true
        text.textContainerInset = NSSize(width: 20, height: 14)
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.minSize = NSSize(width: 0, height: 0)
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        text.textContainer?.widthTracksTextView = true
        text.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        text.setAccessibilityLabel("Transcript")
        text.delegate = context.coordinator
        text.coordinator = context.coordinator
        scroll.documentView = text
        context.coordinator.textView = text
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.actions = actions
        guard let text = coordinator.textView else { return }
        if coordinator.document != document {
            coordinator.build(document, kept: kept)
        } else if coordinator.kept != kept {
            coordinator.restyle(kept: kept)
        }
        coordinator.highlight(playing, follow: follow)
        coordinator.select(selected)
        if revealRequest != coordinator.revealRequest {
            coordinator.revealRequest = revealRequest
            coordinator.reveal(playing)
        }
        if findRequest != coordinator.findRequest {
            coordinator.findRequest = findRequest
            text.window?.makeFirstResponder(text)
            text.performTextFinderAction(NSMenuItem.findItem)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: PlayableTextView?
        var actions: Actions?
        var document = TranscriptDocument.empty
        var kept: [Mastering.Span] = []
        /// Where each word and sentence sits in the text.
        private(set) var wordRanges: [NSRange] = []
        private var sentenceRanges: [NSRange] = []
        private var highlighted: Int?
        /// True while the text is being replaced: the selection AppKit drops then is not Ivan's.
        private var building = false
        var revealRequest = 0
        var findRequest = 0

        /// Lays the whole transcript out: a time line, then the paragraph's words, for each paragraph.
        func build(_ document: TranscriptDocument, kept: [Mastering.Span]) {
            self.document = document
            self.kept = kept
            highlighted = nil
            guard let textView, let storage = textView.textStorage else { return }
            let out = NSMutableAttributedString()
            var words: [NSRange] = []
            var sentences: [NSRange] = Array(repeating: NSRange(location: 0, length: 0), count: document.sentences.count)
            let timeStyle = NSMutableParagraphStyle()
            timeStyle.paragraphSpacingBefore = 16
            timeStyle.paragraphSpacing = 2
            let wordsStyle = NSMutableParagraphStyle()
            wordsStyle.lineSpacing = 4
            for paragraph in document.paragraphs {
                out.append(NSAttributedString(string: Format.timecode(paragraph.start) + "\n", attributes: [
                    .font: AppFont.nsNumbers, .foregroundColor: AppColor.secondaryTextNS, .paragraphStyle: timeStyle]))
                for sentenceIndex in paragraph.sentences {
                    let sentence = document.sentences[sentenceIndex]
                    let sentenceStart = out.length
                    for wordIndex in sentence.words {
                        let word = document.words[wordIndex]
                        let location = out.length
                        out.append(NSAttributedString(string: word.text, attributes: Self.wordAttributes(kept: word.isKept(in: kept), style: wordsStyle)))
                        words.append(NSRange(location: location, length: (word.text as NSString).length))
                        out.append(NSAttributedString(string: " ", attributes: [.font: AppFont.nsBody, .paragraphStyle: wordsStyle]))
                    }
                    sentences[sentenceIndex] = NSRange(location: sentenceStart, length: max(0, out.length - sentenceStart - 1))
                }
                out.append(NSAttributedString(string: "\n", attributes: [.font: AppFont.nsBody, .paragraphStyle: wordsStyle]))
            }
            building = true
            storage.setAttributedString(out)
            building = false
            wordRanges = words
            sentenceRanges = sentences
        }

        static func wordAttributes(kept: Bool, style: NSParagraphStyle) -> [NSAttributedString.Key: Any] {
            var attributes: [NSAttributedString.Key: Any] = [.font: AppFont.nsBody, .paragraphStyle: style,
                                                             .foregroundColor: kept ? NSColor.labelColor : AppColor.secondaryTextNS]
            if !kept {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                attributes[.strikethroughColor] = AppColor.secondaryTextNS
            }
            return attributes
        }

        /// The trim or the cuts changed: each word is struck through or not again, in place, so the
        /// transcript keeps its scroll position.
        func restyle(kept: [Mastering.Span]) {
            self.kept = kept
            guard let storage = textView?.textStorage else { return }
            storage.beginEditing()
            for (index, range) in wordRanges.enumerated() where NSMaxRange(range) <= storage.length {
                let isKept = document.words[index].isKept(in: kept)
                storage.addAttribute(.foregroundColor, value: isKept ? NSColor.labelColor : AppColor.secondaryTextNS, range: range)
                if isKept {
                    storage.removeAttribute(.strikethroughStyle, range: range)
                } else {
                    storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                    storage.addAttribute(.strikethroughColor, value: AppColor.secondaryTextNS, range: range)
                }
            }
            storage.endEditing()
        }

        /// Marks the sentence playing; with Follow Playback on, keeps it in view.
        func highlight(_ sentence: Int?, follow: Bool) {
            guard sentence != highlighted, let storage = textView?.textStorage else { return }
            if let old = highlighted, sentenceRanges.indices.contains(old), NSMaxRange(sentenceRanges[old]) <= storage.length {
                storage.removeAttribute(.backgroundColor, range: sentenceRanges[old])
            }
            highlighted = sentence
            guard let sentence, sentenceRanges.indices.contains(sentence), NSMaxRange(sentenceRanges[sentence]) <= storage.length else { return }
            storage.addAttribute(.backgroundColor, value: AppColor.playingHighlightNS, range: sentenceRanges[sentence])
            if follow { reveal(sentence) }
        }

        /// Brings a sentence to the middle of the transcript's view, as Follow Playback does.
        func reveal(_ sentence: Int?) {
            guard let sentence, sentenceRanges.indices.contains(sentence), let textView,
                  let layout = textView.layoutManager, let container = textView.textContainer,
                  let clip = textView.enclosingScrollView?.contentView else { return }
            let glyphs = layout.glyphRange(forCharacterRange: sentenceRanges[sentence], actualCharacterRange: nil)
            var rect = layout.boundingRect(forGlyphRange: glyphs, in: container)
            rect.origin.y += textView.textContainerOrigin.y
            let visible = clip.bounds.height
            let top = max(0, min(rect.midY - visible / 2, textView.frame.height - visible))
            clip.scroll(to: NSPoint(x: 0, y: top))
            textView.enclosingScrollView?.reflectScrolledClipView(clip)
        }

        /// Shows the Viewer's chosen words as the text's selection.
        func select(_ chosen: ClosedRange<Int>?) {
            guard let textView, words(in: textView.selectedRange()) != chosen else { return }
            guard let chosen, wordRanges.indices.contains(chosen.lowerBound), wordRanges.indices.contains(chosen.upperBound) else {
                if textView.selectedRange().length > 0 { textView.setSelectedRange(NSRange(location: textView.selectedRange().location, length: 0)) }
                return
            }
            let first = wordRanges[chosen.lowerBound], last = wordRanges[chosen.upperBound]
            textView.setSelectedRange(NSRange(location: first.location, length: NSMaxRange(last) - first.location))
        }

        /// The word at a character of the text: the word itself, or, between words or on a time line, the
        /// next word after it.
        func word(at character: Int) -> Int? {
            guard !wordRanges.isEmpty else { return nil }
            if let index = wordRanges.firstIndex(where: { NSMaxRange($0) >= character }) { return index }
            return wordRanges.count - 1
        }

        /// The words a selection covers, or nil.
        func words(in range: NSRange) -> ClosedRange<Int>? {
            guard range.length > 0 else { return nil }
            let touched = wordRanges.indices.filter { NSIntersectionRange(wordRanges[$0], range).length > 0 }
            guard let first = touched.first, let last = touched.last else { return nil }
            return first...last
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView, !building else { return }
            actions?.select(words(in: textView.selectedRange()))
        }
    }
}

extension NSMenuItem {
    /// The Find bar's "show" action, as Edit > Find > Find... sends it.
    @MainActor static var findItem: NSMenuItem {
        let item = NSMenuItem()
        item.tag = NSTextFinder.Action.showFindInterface.rawValue
        return item
    }
}

/// The text view under the transcript: a click without a drag plays from the word under it; Space, J, K
/// and L play, Escape goes back to the library; Control-click offers the edit and Copy.
final class PlayableTextView: NSTextView {
    weak var coordinator: TranscriptTextView.Coordinator?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // NSTextView tracks the drag inside mouseDown; when it returns with nothing selected, it was a click.
        guard selectedRange().length == 0, let coordinator else { return }
        let point = convert(event.locationInWindow, from: nil)
        let character = characterIndexForInsertion(at: point)
        if let word = coordinator.word(at: character) { coordinator.actions?.playWord(word) }
    }

    override func keyDown(with event: NSEvent) {
        let characters = event.charactersIgnoringModifiers ?? ""
        let plain = event.modifierFlags.intersection([.command, .control, .option]).isEmpty
        if plain, characters == " " {
            coordinator?.actions?.togglePlay()
            return
        }
        if plain, let key = characters.first, "jklJKL".contains(key) {
            coordinator?.actions?.shuttle(key)
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        coordinator?.actions?.back()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let remove = NSMenuItem(title: "Remove from the Edit", action: #selector(removeFromEdit), keyEquivalent: "")
        remove.target = self
        remove.isEnabled = coordinator?.actions?.canRemove() == true
        let keep = NSMenuItem(title: "Keep in the Edit", action: #selector(keepInEdit), keyEquivalent: "")
        keep.target = self
        keep.isEnabled = coordinator?.actions?.canKeep() == true
        menu.autoenablesItems = false
        menu.addItem(remove)
        menu.addItem(keep)
        menu.addItem(.separator())
        let copy = NSMenuItem(title: "Copy", action: #selector(copy(_:)), keyEquivalent: "")
        copy.target = self
        copy.isEnabled = selectedRange().length > 0
        menu.addItem(copy)
        return menu
    }

    @objc private func removeFromEdit() { coordinator?.actions?.remove() }
    @objc private func keepInEdit() { coordinator?.actions?.keep() }
}
