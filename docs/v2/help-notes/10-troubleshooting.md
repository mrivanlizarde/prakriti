# Builder notes: 10-troubleshooting.md

The team's notes for the in-app Help article `mac/Prakriti/Resources/Help/10-troubleshooting.md` ("If something isn't working").
Moved out of the article in v2 part M2a so the app bundle holds user text only. Never shown in the app.

## Status after v2 part M3b (Mon 12 Oct 2026)

- v1's recording page was retired with the Viewer: every line that sent Ivan to "the recording's page"
  now names the viewer or the inspector's tab that holds the same thing.

## Status after v2 part M3a (Sun 11 Oct 2026)

- Sources, Check Now and Open Privacy Settings are in the inspector with the folder selected; Activity is Window >
  Activity (Show Me `activity`, which opens the Activity window); notifications go through Settings, General
  (Show Me `settings/general`); LM Studio and the Claude API test through Settings, Models.

## Status after v2 part M2a (Sun 11 Oct 2026)

- Visible: v1's checks, Show Me for Sources, Activity, Settings and Models, "If a cut took out something you
  need" (Remove beside the cut), **Help > Show Log in Finder** (built in M2a: today's log selected in the
  Finder, else the folder).
- Gated: one audio track (`captureCheck`), soft video after a zoom (`style`), people (`people`), Final Cut
  Pro and Resolve (`timelines`).
- Notifications now go through the app's Settings screen (Open Notification Settings) and say the
  Settings screen reports whether macOS allows the notices (`permissionLine`).

## Notes from the help track (Sat 10 Oct 2026)

- From v1: the silence rule (loudest point at or below -60 dB, or no audio track: Needs a decision,
  nothing made), the transcript-gap notice ("the transcript stops N before the end"), the 5-minute
  heartbeat line, the log path `~/Library/Logs/Prakriti/<date>.log`, "Check Now", "Open Privacy
  Settings…", "Test LM Studio". The crash note: v1 has nothing that restarts Prakriti until the
  next login; if v2 adds a LaunchAgent or a helper, simplify "If Prakriti seems to have stopped".
- **Assumes for v2:** "Help > Show Log in Finder" (recommended: Ivan never has to type a path);
  "Restore" on a cut in the viewer strip; "Not This Person"; a separate Resolve file. If the timeline
  track ships one FCPXML for both apps, cut the "Use the file Prakriti made for Resolve" sentence.
- Final Cut Pro "File > Relink Files" `[unverified in FCP 12 menu wording]`. Resolve "Relink Clips
  for Selected Timeline" is from third-party guides `[unverified in Resolve 21]`.
- Resolve "Invalid XML" on newer FCPXML versions: third-party guides say Resolve has lagged a
  version or two behind Final Cut Pro (https://tryuncle.com/learn/davinci-resolve/switching-from-final-cut-pro-to-davinci-resolve);
  Resolve 21 added Final Cut Pro 12 FCPXML import. The timeline track should write the lowest FCPXML
  version that carries every feature it needs, and test an import in both apps.
- The sync offset advice uses OBS's "Sync Offset" label (Advanced Audio Properties, OBS locale).
- macOS privacy path "Privacy & Security > Microphone" `[unverified on macOS 27 wording]`.

## Status after v2 part M2b (Sun 11 Oct 2026)

- "If you don't get notifications": Open Notification Settings opens System Settings at Prakriti's own page
  (the address carries the app's id; measured on macOS 27.2), so the step is now "turn on Allow
  notifications". A `:::requires welcome` block adds the welcome's last panel as a second way.

## Built in v2 part M4b (Mon 12 Oct 2026)

- `captureCheck` is on. Measured, not assumed: the capture check runs as the first step once a file is complete,
  before the 60 s test rule, so a test file keeps its check; it shows at the top of the inspector's Checks as
  "Capture" (summary line, then each finding with "Limit:", "Tip:" and a Help link). The 13 Sep talk reads 1920 by
  1080, 29.97 frames per second, H.264 (High), Rec. 709, one stereo track with one microphone in both channels
  (left minus right -91 dB). Hybrid MOV is accepted (a fragmented MOV passes the watcher, readiness, the capture
  check and AVFoundation in `CaptureCheckTests`). Older recordings show Check Capture. Not built: the speaker's
  place in the frame, light on the face and steadiness (design spec 3.5.4 lists them; they need the face work of M6).

## Built in v2 part TXGAP (Wed 14 Oct 2026)

- New section "If the transcript is missing words in the middle". Measured: a stretch of speech with no words after the second
  listen fails the coverage check, the notice reads "...the transcript has no words for 1 stretch of speech. Its Checks tab says
  where; listen there before trusting it.", the Checks tab shows a Missing words row, and REPORT.md says "NO WORDS for 1 stretch
  of speech at 0:30 (12 s)" (`TranscriptGapsTests`, a stretch planted and the second listen made deaf).

## Notes from part M8c (Wed 14 Oct 2026)

- New section "If the video does not play in the viewer" (`requires video`), one bullet per sentence `VideoPreview.source` and the
  Viewer can say.
