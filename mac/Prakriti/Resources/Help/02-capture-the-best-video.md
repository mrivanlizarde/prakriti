---
id: capture-the-best-video
title: Capture the best video
summary: Light, framing, camera, sound and room choices that give Prakriti a clean recording to work from.
section: recording
order: 1
keywords: [lighting, window, key light, framing, eye level, camera, iPhone, webcam, 4K, 1080p, frame rate, shutter, microphone, lavalier, shotgun, levels, headphones, echo, background, test recording, class, students, tracks]
related: [set-up-obs-for-prakriti, people-and-privacy, troubleshooting]
---

# Capture the best video

Prakriti is built for clean recordings. The choices you make before you press Record decide how good
the finished work can be. Nothing done afterward fixes a dark face, a soft picture or a voice lost in
an echo.

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

**Use a window if you have one.** Face the window, or sit with it to one side. Never sit with a bright
window behind you: the camera exposes for the window and your face goes dark. If you wear glasses and
the window is straight ahead, turn a little so it does not show in the lenses. Daylight changes as
clouds pass, so for long sessions add a light of your own.

**With lights, use three.**

1. **Key light.** Your main light. Place it about 45 degrees to one side of the camera, a little above
   eye level, pointing down at the face. Soften it with a softbox or diffusion fabric. Closer to the
   camera gives a flatter, brighter look. Further to the side gives more shadow.
2. **Fill light.** On the other side of the camera, and weaker than the key. It lifts the shadows the
   key makes without making shadows of its own. A white wall or a reflector can do this job.
3. **Back light.** Behind the person and above them, pointing at their head and shoulders. It separates
   them from the background.

Use lights of the same color. Daylight from a window and warm household bulbs in the same shot make
faces look patchy. Set the camera's white balance by hand so it does not drift during the session.

## Frame the shot

- **Lens at eye level.** A camera below the eyes looks up the nose. A camera above looks down on the
  speaker.
- **Eyes on the upper third.** Picture the frame cut into thirds from top to bottom. Put the eyes on the
  top line and leave a little space above the head.
- **Leave room around the person.** For a talk, frame from about the waist up. For movement on a mat,
  frame the whole mat with a little space around it.
:::requires style
  Prakriti makes the zooms you see in a finished video by moving in on the recorded picture, so the
  room around the person is what it zooms into.
:::
- **Keep the camera still.** Use a tripod or a fixed mount, and do not move it during a session.
- **Look into the lens** when you speak to the people who will watch.
:::requires shorts
- **Stay near the middle** for the moments you want as a short. A vertical short is cut from the center
  of the frame.
:::

## Choose a camera

From best to simplest:

- **A mirrorless camera or camcorder into a capture card.** The camera sends a clean picture through
  HDMI into a 4K capture card plugged into the Mac, and OBS records it. Turn on the camera's clean HDMI
  output (no icons on the picture), turn off its automatic power off, and run it from mains power if it
  can.
- **An iPhone, as a camera for the Mac.** Continuity Camera lets OBS use an iPhone's camera. Mount the
  phone in landscape, keep it still, and keep it plugged in. In Control Center on the Mac, turn off
  Center Stage, Portrait and Studio Light for the iPhone: they move, blur or relight the picture in ways
  that cannot be undone afterward.
- **A webcam.** Fine for a quick talk. Most webcams record 1080p, so the picture is softer.

### Camera settings

- **Resolution: 4K (3840 by 2160).** A 4K frame holds four 1080p frames, so the picture stays sharp
  when it is cropped or enlarged.
:::requires style
  Prakriti can zoom in up to twice as close and still deliver a sharp 1080p video.
:::
:::requires shorts
  It can also cut a full-quality vertical short from the middle of the frame.
:::
- **Frame rate: 30 frames per second.** Right for talking and teaching, half the data of 60, and YouTube
  asks for videos at the rate they were recorded.
- **Shutter speed: 1/60 of a second.** Twice the frame rate gives natural motion, and it matches lights
  powered at 60 Hz in the US. If you see bands or flicker, try 1/120.
- **Focus, exposure and white balance: locked,** or face tracking for focus. Automatic exposure and
  color drift as people move and light changes.

If the camera or the Mac cannot record 4K, record 1080p at the same settings. Everything still works.

## Record clean sound

Sound matters more than picture. A soft image is forgiven. A voice that cannot be heard is not.

- **One microphone per person.** A lavalier (clip-on) microphone for each teacher, wireless if they
  move. Clip it to the chest, about a hand's width from the mouth, away from hair, jewelry and fabric
  that rubs.
- **A shotgun microphone** works for one person who stays still: on a stand above and in front of them,
  pointing at the mouth, just out of the shot.
- **Each microphone on its own track.** OBS can record each microphone, and Zoom or computer audio, as
  separate tracks in the same file, which keeps each voice on its own in the original. See
  [Set up OBS for Prakriti](03-set-up-obs-for-prakriti.md).
:::requires people
  Prakriti uses the tracks to keep each voice clean and to remove a voice you do not want.
:::
- **Set the level.** Speak at teaching volume. In OBS, speech should sit in the upper part of the yellow
  on the meter, and the loudest words should only touch the start of the red. That is about -12 to -9
  dBFS. Too quiet adds hiss. Too loud distorts, and distortion cannot be removed.
- **Leave noise reduction off in OBS.** Noise suppression and noise gates can smear a voice or cut off
  quiet words. Prakriti levels the sound itself, and works best from sound nobody has changed.
- **Wear headphones.** Someone should hear exactly what is recorded. Closed headphones also stop Zoom
  audio from the speakers leaking into the teacher's microphone.

## Quiet the room

- Soft surfaces absorb echo: a rug, heavy curtains, a sofa, a full bookshelf. Bare walls and hard floors
  make a voice sound far away.
- Close windows and doors. Turn off fans and air conditioning while you record, if you can, and silence
  phones.
- The closest microphone is the strongest fix. A lavalier on the chest hears the voice far more than the
  room.

## Set the background

- Leave space between the person and the wall behind them. It adds depth and keeps their shadow off the
  wall.
- Keep it simple and tidy. A lamp in the background adds warmth.
- Keep screens out of the shot, especially a Zoom window showing other faces or anything private.

## Make clean takes

:::unless video
- **If you stumble, pause, then say the whole sentence again from the start.** The mistake can then be
  cut cleanly on the recording's page, at a pause.
:::
:::requires video
- **If you stumble, pause, then say the whole sentence again from the start.** Prakriti recognizes the
  repeat and keeps the last complete take.
:::
- Leave a second of quiet before you start and after you finish.
:::requires style
- Mark a moment as you record: press the OBS chapter marker key after a strong moment, or right after a
  mistake. Prakriti reads the markers.
:::

## Record a 10-second test

Do this every time you set up, even when nothing has changed.

1. Press Record in OBS.
2. Say your name and one sentence at teaching volume. Each person with a microphone does the same.
3. Stop, and play the recording back with headphones.
4. Check the face is bright and sharp, the framing is right, and each voice is clear.
:::requires captureCheck
5. Put the test file in the Drop folder. Prakriti files anything under 60 seconds as a test and shows
   its capture check on the recording's page: the picture size, the frame rate, each audio track and
   how loud it is.
:::

**Tip:** A file that sounds fine in a player can still be missing a track, because players only play
the first one. The 10-second test in [Set up OBS for Prakriti](03-set-up-obs-for-prakriti.md) lists
every track in a file.

## Record a class

:::unless people
Prakriti never makes a class ready to upload, and a recording marked as a class cannot be approved,
because Prakriti does not yet tell one voice from another. The room can still be set up so students
are protected from the start.
:::
:::requires people
Prakriti protects students in what it makes, and it works best when the room is set up for that too.
:::

- **Point the camera at the teacher.** Seat students behind the camera or beside it. If some students
  will be in the shot, film them from behind.
- **Tell students every time.** At the start of each class, say that it is recorded, what the recording
  is for, and where to sit to stay out of frame. Anyone who prefers not to appear sits there.
- **Repeat questions in your own words,** so the answer still makes sense without the student's voice.
- **For students on Zoom, record only Zoom's sound,** on its own track. Do not record the Zoom gallery.
- **If a child is in the room,** keep that recording private.

See [Privacy and students](07-people-and-privacy.md) for what Prakriti keeps on this Mac and which
recordings only models on this Mac may read.
