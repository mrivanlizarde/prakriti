---
id: capture-the-best-video
title: Capture the best video
summary: Light, framing, camera, sound and room choices that give Prakriti a clean recording to work from.
keywords: [lighting, window, key light, framing, eye level, camera, iPhone, webcam, 4K, 1080p, frame rate, shutter, microphone, lavalier, shotgun, levels, headphones, echo, background, test recording, class, students]
related: [03-set-up-obs-for-prakriti, 07-people-and-privacy, 10-troubleshooting]
---

# Capture the best video

Prakriti is built for clean recordings. The choices you make before you press Record decide how
good the finished video can be. Nothing done afterward fixes a dark face, a soft picture or a voice
lost in an echo.

## Before you press Record

- The light is in front of you or to the side, never behind you.
- The camera lens is at eye level, and your eyes sit about a third of the way down the frame.
- The camera records 4K at 30 frames per second, if it can.
- Each person who speaks wears their own microphone, recorded on its own track.
- The loudest words reach the upper yellow of the OBS meter and only touch the red.
- Someone is wearing headphones and listening to what is recorded.
- Students know the class is recorded, and anyone who prefers not to appear is out of frame.
- You recorded 10 seconds, played it back and liked what you saw and heard.

## Light the face

**Use a window if you have one.** Face the window, or sit with it to one side. Never sit with a
bright window behind you: the camera exposes for the window and your face goes dark. If you wear
glasses and the window is straight ahead, turn a little so it does not show in the lenses. Daylight
changes as clouds pass, so for long sessions add a light of your own.

**With lights, use three.**

1. **Key light.** Your main light. Place it about 45 degrees to one side of the camera, a little
   above eye level, pointing down at the face. Soften it with a softbox or diffusion fabric. Closer to
   the camera gives a flatter, brighter look. Further to the side gives more shadow.
2. **Fill light.** On the other side of the camera, and weaker than the key. It lifts the shadows the
   key makes without making shadows of its own. A white wall or a reflector can do this job.
3. **Back light.** Behind the person and above them, pointing at their head and shoulders. It
   separates them from the background.

Use lights of the same color. Daylight from a window and warm household bulbs in the same shot make
faces look patchy. Set the camera's white balance by hand so it does not drift during the session.

## Frame the shot

- **Lens at eye level.** A camera below the eyes looks up the nose. A camera above looks down on the
  speaker.
- **Eyes on the upper third.** Picture the frame cut into thirds from top to bottom. Put the eyes on
  the top line and leave a little space above the head.
- **Leave room around the person.** Prakriti makes the zooms you see in a finished video by moving in
  on the recorded picture. For a talk, frame from about the waist up. For movement on a mat, frame the
  whole mat with a little space around it.
- **Keep the camera still.** Use a tripod or a fixed mount, and do not move it during a session.
- **Look into the lens** when you speak to the people who will watch.
- **Stay near the middle** for the moments you want as a short. A vertical short is cut from the
  center of the frame.

## Choose a camera

From best to simplest:

- **A mirrorless camera or camcorder into a capture card.** The camera sends a clean picture through
  HDMI into a 4K capture card plugged into the Mac, and OBS records it. Turn on the camera's clean HDMI
  output (no on-screen icons), turn off its automatic power off, and run it from mains power if it can.
- **An iPhone, as a camera for the Mac.** Continuity Camera lets OBS use an iPhone's camera. Mount the
  phone in landscape, keep it still, and keep it plugged in. In Control Center on the Mac, turn off
  Center Stage, Portrait and Studio Light for the iPhone: they move, blur or relight the picture in
  ways Prakriti cannot undo.
- **A webcam.** Fine for a quick talk. Most webcams record 1080p, so zooms look softer.

### Camera settings

| Setting | Use | Why |
|---|---|---|
| Resolution | 4K (3840 by 2160) | A 4K frame holds four 1080p frames, so Prakriti can zoom in up to twice as close and still deliver a sharp 1080p video, and cut a full-quality vertical short from the middle of the frame. |
| Frame rate | 30 frames per second | Right for talking and teaching, half the data of 60, and YouTube asks for videos at the rate they were recorded. |
| Shutter speed | 1/60 of a second | Twice the frame rate gives natural motion, and it matches lights powered at 60 Hz in the US. If you see bands or flicker, try 1/120. |
| Focus, exposure, white balance | Locked, or face tracking for focus | Automatic exposure and color drift as people move and light changes. |

If the camera or the Mac cannot record 4K, record 1080p at the same settings. Everything still works.
Zooms are gentler and look a little softer.

## Record clean sound

Sound matters more than picture. People forgive a soft image. They stop watching when they cannot
hear.

- **One microphone per person.** A lavalier (clip-on) microphone for each teacher, wireless if they
  move. Clip it to the chest, about a hand's width from the mouth, away from hair, jewelry and fabric
  that rubs.
- **A shotgun microphone** works for one person who stays still: on a stand above and in front of
  them, pointing at the mouth, just out of the shot.
- **Each microphone on its own track.** OBS can record each microphone, and Zoom or computer audio,
  as separate tracks in the same file. Prakriti uses them to keep each voice clean and to remove a
  voice you do not want. See [Set up OBS for Prakriti](03-set-up-obs-for-prakriti.md).
- **Set the level.** Speak at teaching volume. In OBS, speech should sit in the upper part of the
  yellow on the meter, and the loudest words should only touch the start of the red. That is about
  -12 to -9 dBFS. Too quiet adds hiss. Too loud distorts, and distortion cannot be removed.
- **Leave noise reduction off in OBS.** Noise suppression and noise gates can smear a voice or cut off
  quiet words. Prakriti cleans and levels the sound itself, from the untouched tracks.
- **Wear headphones.** Someone should hear exactly what is recorded. Closed headphones also stop Zoom
  audio from the speakers leaking into the teacher's microphone.

## Quiet the room

- Soft surfaces absorb echo: a rug, heavy curtains, a sofa, a full bookshelf. Bare walls and hard
  floors make a voice sound far away.
- Close windows and doors. Turn off fans and air conditioning while you record, if you can, and
  silence phones.
- The closest microphone is the strongest fix. A lavalier on the chest hears the voice far more than
  the room.

## Set the background

- Leave space between the person and the wall behind them. It adds depth and keeps their shadow off
  the wall.
- Keep it simple and tidy. A lamp in the background adds warmth.
- Keep screens out of the shot, especially a Zoom window showing other people's faces or anything
  private.

## Make clean takes

- **If you stumble, pause, then say the whole sentence again from the start.** Prakriti recognizes the
  repeat and keeps the last complete take.
- Leave a second of quiet before you start and after you finish.
- Mark a moment as you record: press the OBS chapter marker key after a strong moment, or right after
  a mistake. Prakriti reads the markers.

## Record a 10-second test

Do this every time you set up, even when nothing has changed.

1. Press Record in OBS.
2. Say your name and one sentence at teaching volume. Each person with a microphone does the same.
3. Stop, and play the recording back with headphones.
4. Check the face is bright and sharp, the framing is right, and each voice is clear.
5. Put the test file in the Drop folder. Prakriti files anything under 60 seconds as a test and shows
   its capture check on the recording's page: the picture size, the frame rate, each audio track and
   how loud it is.

**Tip:** A file that sounds fine in a player can still be missing a track. Players only play the first
track. The capture check lists every track in the file.

## Record a class

Prakriti protects students in what it makes, and it works best when the room is set up for that too.

- **Point the camera at the teacher.** Seat students behind the camera or beside it. If some students
  will be in the shot, film them from behind.
- **Tell students every time.** At the start of each class, say that it is recorded, what the
  recording is for, and where to sit to stay out of frame. Anyone who prefers not to appear sits there.
- **Repeat questions in your own words.** Prakriti removes students' voices by default. When the
  teacher repeats the question, the answer still makes sense without them.
- **For students on Zoom, record only Zoom's sound,** on its own track. Do not record the Zoom gallery.
- **If a child is in the room,** that recording stays private.

See [People and privacy](07-people-and-privacy.md) for how Prakriti finds faces and voices and how you
choose who appears.

## See also

- [Set up OBS for Prakriti](03-set-up-obs-for-prakriti.md)
- [Outputs](05-outputs.md)
- [If something isn't working](10-troubleshooting.md)

<!-- builder-notes: everything below this line is for the team and is not shown in the app -->

## Builder notes

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
