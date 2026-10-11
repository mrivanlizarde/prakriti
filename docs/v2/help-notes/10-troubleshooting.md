# Builder notes: 10-troubleshooting.md

The team's notes for the in-app Help article `mac/Prakriti/Resources/Help/10-troubleshooting.md` ("If something isn't working").
Moved out of the article in v2 part M2a so the app bundle holds user text only. Never shown in the app.

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
