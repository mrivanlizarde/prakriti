# Builder notes: 06-reviewing-and-approving.md

The team's notes for the in-app Help article `mac/Prakriti/Resources/Help/06-reviewing-and-approving.md` ("Review and approve").
Moved out of the article in v2 part M2a so the app bundle holds user text only. Never shown in the app.

## Status after v2 part M3a (Sun 11 Oct 2026)

- "Find and open a recording" replaces "Open a recording": the four smart groups, grid and list (Command-1,
  Command-2), the Sort menu, search over titles, notes and what was said, the inspector (Command-Option-I),
  open with a double-click or Return, Back or Escape. Statuses read "Waiting for your yes" (C1) and point at
  the inspector. The accuracy checklist has a box per claim in the inspector's Checks. Approve works from the
  page or the inspector. New section: Remove from Library (Control-click), with the Trash and the tombstone.
- Command-Option-I is named because it is built; Command-9 is not named (it is listed for `progress` in
  `HelpTests.unbuiltNames` until M4a). Quick Look is not built and not named.

## Status after v2 part M2a (Sun 11 Oct 2026)

- Visible: v1's recording page (Listen with Episode or Original, transcript lines, Control-click menu,
  Trim and cuts, Make Again, What this is, Approve with v1's rules, "Approved before this change").
- Gated: the viewer (`viewer`), people choices and least-sure moments (`people`), direction (`style`), and
  v2's approval rules (`people`). M3a renames "Ready for your yes" to "Waiting for your yes" (DS C1): edit
  the status list then.

## Notes from the help track (Sat 10 Oct 2026)

- From v1 (`RecordingPage.swift`, `Vocabulary.swift`, `Approval.swift`): statuses, "Episode starts
  at", "Episode ends at", "Use Player Time", "Cut Selected Lines", "Add Cut", "Remove", "Make
  Again…", "Approve…", `APPROVAL.md` with every file's size and SHA-256 ("fingerprint" in user text),
  "Approved before this change".
- **Assumes for v2, confirm each:** the viewer plays video outputs and lets you choose the output
  (Ivan's item 10; v1 has AVKit's audio player with "Episode" and "Original"); a strip of cuts,
  zooms and titles under the player; captions toggle; Quick Look on made files; a "People in This
  Recording" section; "moments where Prakriti is least sure" marked on the page (SCOPE's review
  model: Ivan listens at the low-confidence moments).
- **Approve rules change in v2.** v1 only approves "Talk, one teacher speaking" because speakers are
  not checked. With per-person choices in v2, this article assumes a class can be approved once every
  person has a choice and the checklists pass. That is a real policy change: confirm with Ivan
  before the build lifts v1's rule. Serenity's consent questions (Q-S13 and others in SCOPE) may still
  block classes from public outputs regardless of the app.
- Keyboard: AVKit's player handles Space; J, K and L (Final Cut Pro's shuttle keys) and arrow-key
  frame stepping are recommended for the viewer but not promised here `[unverified in AVPlayerView]`.
- v1 says "a changed copy voids approvals" (SCOPE). "Approve it again" matches that.
