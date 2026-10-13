# Builder notes: 02-capture-the-best-video.md

The team's notes for the in-app Help article `mac/Prakriti/Resources/Help/02-capture-the-best-video.md` ("Capture the best video").
Moved out of the article in v2 part M2a so the app bundle holds user text only. Never shown in the app.

## Status after v2 part M3b (Mon 12 Oct 2026)

- v1's recording page was retired with the Viewer: every line that sent Ivan to "the recording's page"
  now names the viewer or the inspector's tab that holds the same thing.

## Status after v2 part M2a (Sun 11 Oct 2026)

- Tables are not drawn in Help: the camera settings table is a list.
- Gated: zoom room (`style`), the vertical-short centre (`shorts`), the 4K reasons (`style`, `shorts`),
  "Prakriti uses the tracks" (`people`), the retake recognition (`video`; until then: cut it on the
  recording's page), chapter markers read by Prakriti (`style`; unconfirmed by any part yet), the capture
  check on a test file (`captureCheck`), the class protections (`people`; until then: classes cannot be
  approved or made ready).
- "People forgive a soft image" became "A soft image is forgiven", because the Help test forbids a
  capitalized "People" until the `people` capability exists.
- "If a child is in the room, that recording stays private" is now advice ("keep that recording private"),
  not a claim about the app.

## Notes from the help track (Sat 10 Oct 2026)

### Assumptions this article makes about v2 (confirm against the build)

- **Capture check for tests.** v1 files anything under 60 s as a test and makes nothing, with no notice
  (`Pipeline.swift`, "Under 60 seconds, so it was filed as a test"). This article assumes v2 turns that
  into a capture check on the recording's page: resolution, frame rate, codec, every audio track with
  its peak and loudness, silence per track. Recommended, because it is the cheapest way to catch the
  14 Sep silent-class failure before a real session. If it is not built, change step 5 to "open it in
  QuickTime Player" and cut the Tip.
- **Retakes.** "Prakriti recognizes the repeat and keeps the last complete take" assumes the edit
  engine detects a repeated sentence (word-timestamp alignment from Parakeet) and keeps the last one.
- **Chapter markers read by Prakriti.** OBS writes chapter markers into Hybrid MP4 and MOV files
  (verified, below). Assumes v2 reads them (SCOPE PIP-28 proposed this).
- **Vertical shorts cut from the center.** Assumes v2 crops 9:16 from the horizontal frame, ideally
  following the teacher's face. See the recommendation in 03.
- **"If a child is in the room, that recording stays private."** From research/08 P10 (minors
  excluded from public outputs without a parent's release). Not in REQUEST.md's decisions. Confirm.

### Verification notes

- The 1/60 and 1/120 shutter advice for US 60 Hz lighting is standard practice, sourced from forums
  and blogs, not a manufacturer. Some LED fixtures flicker at other frequencies, so the "try 1/120"
  line is a starting point, not a guarantee `[unverified per fixture]`.
- "About -12 to -9 dBFS" for OBS's upper yellow: OBS's own guide gives zones (speech "should sit in
  the upper range" of yellow and "reach the lower end" of red) but no numbers. The -20 and -9 dB zone
  edges come from a forum feature request, and OBS 32.1 rewrote the mixer `[unverified for OBS 32.1+]`.
- Continuity Camera's maximum resolution inside OBS is not documented by Apple `[unverified]`;
  community reports suggest 1080p class, not 4K. That is why the iPhone is second, not first.
- Leaving space between person and wall: no fixed distance given on purpose; guides vary.
- "In Control Center on the Mac, turn off Center Stage, Portrait and Studio Light": the video effects
  for a camera in use live in Control Center (or the camera menu bar item) on recent macOS
  `[unverified wording and place on macOS 27]`. OBS itself warns when one is active.
- Noise reduction off: grounded in SCOPE NEV-19 (a denoiser before transcription has lost speech on
  past jobs) and the podcast-ready finding that noise reduction can smear a voice (`PodcastReadyViews`).

### Sources (checked 10 Oct 2026)

- Three-point lighting, key at about 45 degrees, fill weaker and opposite, back light above and
  behind: https://www.togethervideo.ie/latest/a-beginner-s-guide-to-three-point-lighting ;
  https://blog.motionarray.com/learn/filmmaking/three-point-lighting-set-up/
- Window light in front or to the side, never behind; glasses glare; changing daylight:
  https://uwaterloo.ca/keep-learning/sites/default/files/uploads/documents/shooting_video_tips_final.pdf ;
  https://www.lsu.edu/communications/files/video/tips-for-at-home-video.pdf
- Eye level, eyes on the upper third, headroom: https://www.videomaker.com/article/7596-getting-started-video-composition
- 4K source cropped for 1080p punch-ins: https://videoguys.com/blogs/news-and-sales/how-to-get-wide-medium-and-close-up-shots-from-one-4k-camera
- 180-degree shutter, 60 Hz lighting: https://www.diyphotography.net/?p=309010 ; https://bgr.com/2204818/why-do-led-lights-flicker-on-camera/
- YouTube: upload at the frame rate recorded: https://support.google.com/youtube/answer/1722171
- Continuity Camera requirements (macOS 13+, iPhone XR+, landscape, stable, plugged in): https://support.apple.com/102546
- OBS warns about Center Stage, Portrait and Studio Light on a capture device (OBS source, plugins/mac-avcapture locale: "Center Stage system effect is active on the selected device").
- Lavalier about a hand-span from the mouth; shotgun above and in front, just out of frame: https://rode.com/en-us/about/news-info/how-to-record-better-interview-audio ; https://zh-hant.rode.com/user-guides/rodecaster-pro-ii/tips-on-microphone-technique
- Dialogue in the -12 to -6 dBFS range for lavaliers: https://www.adorama.com/alc/mastering-audio-levels/
- OBS meter zones and "record a test session and listen back": https://obsproject.com/kb/audio-mixer-guide
- Separate tracks per source, players play one track: https://obsproject.com/kb/multiple-audio-track-recording-guide
- Soft furnishings against echo: https://acousticalsolutions.com/how-to-reduce-echo-in-a-room
- Classes: notice before recording, opt out without penalty, camera placed so students are not identifiable, film students from behind: https://archive.teaching.utoronto.ca/?p=3295 ;
  https://assets.w3.tue.nl/w/fileadmin/Education_Guide/Content/Praktische%20zaken/Regelingen%2C%20gedragscodes%20en%20richtlijnen/Regelingen%20en%20richtlijnen/Framework%20education%20recordings%20Approved%20EB%20-%20adjusted%20012024.pdf ;
  https://www.ualberta.ca/information-services-and-technology/security/online-meetings-and-classes/best-practices-recording-lectures.html
- Repeating questions is common lecture-capture practice (so the answer stands without the student's
  voice); not separately sourced `[unverified as a published guideline]`.
- The measured state of today's studio files (one dual-mono track, the silent 14 Sep class, 6.18 Mbps
  1080p): research/07 §1.3.

## Built in v2 part M4b (Mon 12 Oct 2026)

- `captureCheck` is on. Measured, not assumed: the capture check runs as the first step once a file is complete,
  before the 60 s test rule, so a test file keeps its check; it shows at the top of the inspector's Checks as
  "Capture" (summary line, then each finding with "Limit:", "Tip:" and a Help link). The 13 Sep talk reads 1920 by
  1080, 29.97 frames per second, H.264 (High), Rec. 709, one stereo track with one microphone in both channels
  (left minus right -91 dB). Hybrid MOV is accepted (a fragmented MOV passes the watcher, readiness, the capture
  check and AVFoundation in `CaptureCheckTests`). Older recordings show Check Capture. Not built: the speaker's
  place in the frame, light on the face and steadiness (design spec 3.5.4 lists them; they need the face work of M6).
