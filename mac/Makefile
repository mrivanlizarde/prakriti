# Prakriti for Mac. Every command runs from this folder:
#   cd ~/Code/prakriti/mac && make build
#
# make generate   regenerate Prakriti.xcodeproj from project.yml (needs: brew install xcodegen)
# make build      build the app (signed, warnings fail the build)
# make test       run every unit test (includes the snapshot render)
# make snapshots  render every screen, light and dark, to ../screens/mac/$(MILESTONE)/
#                 (ONLY=library draws just the main window's groups, browser, inspector, Settings and
#                 Activity, ONLY=recording just v1's recording pages, ONLY=help just the Help window,
#                 ONLY=welcome just the welcome)
# make fixtures   build the shared test files of v2 (docs/v2/PLAN.md section 4) from the 13 Sep and
#                 6 Sep talks and macOS `say` into ~/Prakriti/Dev/Fixtures, every time from scratch;
#                 prints each file's SHA-256 and whether it is the SAME as the last run (about 15 s)
# make accept     milestone 2's acceptance through the app's pipeline: the REAL 13 Sep talk, the
#                 silent-60s fixture (65 s of the 13 Sep picture with digital silence; never a class),
#                 a 30 s clip, the REAL 6 Sep talk. Builds the fixtures first if any is missing. Writes
#                 episodes to ~/Prakriti/Dev/Outputs and pictures plus acceptance.txt to
#                 ../screens/mac/$(MILESTONE)/ (takes about 4 to 5 minutes)
# make regress    the regression set every v2 part runs: make test, make accept, make accept-edits,
#                 in that order, stopping at the first failure (about 15 minutes)
# make accept-progress  v2 part M4a's acceptance: the REAL 13 Sep talk made twice in development with the
#                 podcast-ready episode on, every progress snapshot written to progress-trace.txt (time, stage,
#                 percent, time left). Passes when the percent rises from 0 to 100 without going back, the second
#                 run's time left at 50% is within 25% of what really remained, and the menu bar's status line
#                 (written to the development log, as --debug-status-log does) matches the trace at three
#                 moments. Writes acceptance-progress.txt to ../screens/mac/$(MILESTONE)/ (about 3 minutes)
# make accept-capture  v2 part M4b's acceptance: the capture check through the app's runner in development on
#                 the REAL 13 Sep talk (1080p, 29.97 fps, H.264, Rec. 709, one track with one microphone in both
#                 channels), the two-people-tracks.mov fixture (three tracks, each its own loudness), silent-60s.mp4
#                 (its track silent) and the 30 s clip (a test, no output folder, its check in the store). Draws the
#                 Checks tab of each and writes acceptance-capture.txt to ../screens/mac/$(MILESTONE)/ (about 2 minutes)
# make accept-video  v2 part M8a's acceptance (PLAN M8 check 2, the half measured on the plan): the REAL 13 Sep talk
#                 made in development, then Plan the Edit, then Make Again (which must plan again, the same plan); the
#                 plan read back from edit-plan.json and measured against the original's own samples: every cut point
#                 20 dB or more under speech, no silence over the trigger but protected ones, the shortened pauses'
#                 median, every span and cut on a video frame, PlanValidation, nothing made but the plan. Then the REAL
#                 6 Sep talk planned from its development transcript, measured the same way. Writes acceptance-video.txt
#                 to ../screens/mac/$(MILESTONE)/ (about 3 minutes). Then v2 part M8b's half (VideoAcceptanceTests, PLAN M8
#                 checks 2, 3 and 5 on the made MP4): the REAL 13 Sep and 6 Sep talks made in development with the Edited video
#                 on; the MP4 measured by ffprobe, ffmpeg (ebur128, the last 5 s decoded), the box reader (moov before mdat, no
#                 elst on the picture), Parakeet run on it (98% of kept words in order, 90% of removed "um" and "uh" gone), the
#                 sound at every join (no jump in a crossfade over the largest in the 50 ms around it; cross-correlated with the
#                 original: in sync), six frames by pixel difference against the original's at the plan's moment, the pauses
#                 and length, the Ready checklist, StageTiming fed; then Make Video refused with someone hidden. Writes
#                 acceptance-video-m8b.txt (about 30 minutes; PRAKRITI_VIDEO_ONLY="13 Sep" runs one talk)
# make accept-outputs  milestone 4's acceptance on the REAL 13 Sep talk: the standard choices, the
#                 Outputs screen's loudness changed to -19 and made again, the transcript turned off
#                 on the recording's page and made again, then everything off (must equal engine v0
#                 bit for bit). Writes to ~/Prakriti/Dev/Outputs and acceptance-outputs.txt plus
#                 pictures to ../screens/mac/$(MILESTONE)/ (takes about 3 minutes)
# make accept-edits  milestone 5's acceptance on the REAL 13 Sep talk: made, marked as a talk, the
#                 first 10 s trimmed and 5:00 to 5:30 cut, made again, approved (copied to
#                 ~/Prakriti/Dev/Approved), measured with ffprobe against the first episode, the cut
#                 words checked gone by transcribing the approved episode again, then marked as a
#                 class and refused. Writes acceptance-edits.txt and pictures of every state to
#                 ../screens/mac/$(MILESTONE)/ (takes about 3 minutes)
# make accept-models  milestone 6's acceptance on the REAL 13 Sep talk: made with titles, show notes
#                 and chapters on, writing set to the Claude API on purpose (the talk names Serenity, so
#                 the privacy lock must hand it to LM Studio; the Claude client only counts and refuses),
#                 tags and summary on Apple on-device. Qwen3.8-27B is unloaded first so Prakriti's own
#                 load at 65,536 tokens serves it. Every chapter time is checked against transcript.srt
#                 and every quote against transcript.txt; then Apple on-device tags a short input and
#                 each provider is tested for real. Needs LM Studio's server running with the model
#                 downloaded. Writes acceptance-models.txt and pictures to ../screens/mac/$(MILESTONE)/
#                 (takes about 5 to 15 minutes, most of it the writing model)
# make accept-podcast  the podcast-ready episode's acceptance on the REAL 13 Sep and 6 Sep talks: engine v0's
#                 episode diagnosed again (loudness range, loudnorm's mode, how its gain moved), the
#                 podcast-ready episode made alone and then with the first 10 s trimmed (a known caption must
#                 move by exactly 10 s less the silence trim), then made with everything on and the titles,
#                 notes, chapters and captions by Qwen3.8-27B in LM Studio; the MP3 measured and read back,
#                 the checklist read. Needs LM Studio's server running. Writes to ~/Prakriti/Dev/Outputs and
#                 acceptance-podcast-*.txt plus pictures to ../screens/mac/$(MILESTONE)/ (about 40 minutes)
# make accept-episode-text  the episode text's acceptance on the REAL 13 Sep talk (11 Oct): made with
#                 everything on, the writing by Qwen3.8-27B in LM Studio (set to the Claude API on purpose:
#                 the privacy lock must keep it on this Mac), then Episode text.txt and .md read back: every
#                 section there, every pull quote word for word in transcript.txt and inside one .srt cue,
#                 every chapter time one ffprobe reads from the finished MP3, no dashes, no "$" or "enroll"
#                 in the captions, X and Threads under 280 characters; a call to action set, updated and
#                 cleared; pictures of the page and of the class refusal. Needs LM Studio's server running.
#                 Writes acceptance-episode-text.txt and pictures to ../screens/mac/$(MILESTONE)/ (about 30 minutes)
# make accept-names  v2 part M5a's check 3: how many person names in the REAL 13 Sep talk Apple's tagger finds,
#                 on the exact text a cloud writing request would carry, against a reference Qwen3.8-27B makes in
#                 LM Studio on this Mac (it lists every name and judges each find). Needs the 13 Sep transcript from
#                 `make accept` and LM Studio's server. Names only Gabriel and Serenity; every other name is
#                 "name N". Writes acceptance-names.txt to ../screens/mac/$(MILESTONE)/ (about 2 to 10 minutes)
# make accept-providers  v2 part M5b's check 6: each cloud key against its provider's free model list, then one
#                 write of synthetic-transcript.json per provider. Costs cents: runs only with YES=1 (Ivan's yes),
#                 reads keys only from the tests' Keychain items, and reports SKIPPED without them
# make migrate-check  copy the live store (sqlite3 .backup, a consistent snapshot; the live store
#                 is only read) into build/store-copy and open the COPY with this build's models.
#                 Run it before `make install` whenever the models change. It holds on any real store
#                 (12 Oct): fields this build adds must arrive at their defaults, and every row and every
#                 value already stored (approvals, removed files, switches) must come through unchanged.
#                 FROM=<an older store> runs it on that store instead (still only a copy is opened)
# make run        build, then open the app
# make accept-help  v2 parts M2a and M2b: Prakriti Help and the welcome in the REAL app. The Help window
#                 opened on its own with sample data at three articles and a search, light and dark; the
#                 welcome opened on its own at each of its five panels (and the last panel after Choose
#                 Folder added a folder, and refused one), light and dark, each fitting without scrolling;
#                 all captured to ../screens/mac/$(MILESTONE)/real/. Then Help, Welcome to Prakriti chosen
#                 through Accessibility, the welcome driven by Continue, Return, Command-Left, Back and
#                 Escape, and the Help menu's search handler run for OBS, notifications and privacy (the
#                 debug switch --debug-help-search), each needing its expected article first. Writes
#                 acceptance-help.txt (takes the screen's focus for about two minutes)
# make accept-first-launch  v2 part M2b's first-launch check in the REAL app: deletes the DEVELOPMENT
#                 preference welcomeSeenVersion (never the live one), opens the built app twice with
#                 --development, and needs the welcome at the first launch only and the watcher's first
#                 look within 5 s both times. Writes acceptance-first-launch.txt and the welcome's picture
#                 (takes the screen's focus for about half a minute)
# make look       open the REAL app on sample data, capture every screen light and dark to
#                 ../screens/mac/$(MILESTONE)/real/, and check the selected sidebar row, the keys (Space
#                 plays in the Viewer, read from the log); then (v2 part M3b) open PLAYBACK in a
#                 development copy's Viewer with --debug-playback-log, press Space, and prove playback
#                 from the log: two currentTime lines 3 s apart differ by 2.5 to 3.5 s at rate 1
#                 (playback.txt). Takes the screen's focus for about three minutes; do not touch the Mac
# make check      build, test, launch, prove it keeps running with its window closed, then look
# make install    build, then put the app in ~/Applications and open it there: the live watcher and
#                 the copy that opens at login (quits the installed copy first, cleanly)
# make drop       milestone 3's check in the real app: a fresh 90 s clip is moved into the drop
#                 folder and must be found, made and logged with no clicks. MODE=development uses a
#                 test copy on ~/Prakriti/Dev/Drop; MODE=live uses the installed copy on ~/Prakriti/Drop

PROJECT   = Prakriti.xcodeproj
SCHEME    = Prakriti
DERIVED   = build
APP       = $(DERIVED)/Build/Products/Debug/Prakriti.app
MILESTONE ?= latest
MODE      ?= development
ONLY      ?=
STYLE_ONLY ?=
YES       ?=
XCB       = xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED) -destination 'platform=macOS'

.PHONY: accept-timeline-full accept-timeline-people accept-timeline resolve-import accept-hook accept-direction accept-text accept-style accept-people-video accept-viewer-video look-video accept-video calibrate-people accept-gallery accept-people accept-capture generate build test snapshots fixtures accept accept-progress regress accept-outputs accept-edits accept-models accept-podcast accept-episode-text accept-names accept-providers accept-help accept-first-launch migrate-check run look check install drop

generate:
	xcodegen generate

# The output is kept and read for warnings, because warnings-as-errors misses some (scripts/no-warnings.sh).
# A warning shows only when its file compiles, so the W4 check is a clean build in a fresh clone.
build:
	@mkdir -p $(DERIVED)
	bash -o pipefail -c "$(XCB) build 2>&1 | tee $(DERIVED)/build-output.log"
	./scripts/no-warnings.sh $(DERIVED)/build-output.log

test:
	TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test

snapshots:
	TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) TEST_RUNNER_PRAKRITI_SNAPSHOT_ONLY=$(ONLY) $(XCB) test -only-testing:PrakritiTests/SnapshotTests

fixtures:
	./scripts/make-fixtures.sh

accept:
	./scripts/make-fixtures.sh --if-missing
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=1 TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/PipelineAcceptanceTests

regress:
	$(MAKE) test MILESTONE=$(MILESTONE) DERIVED=$(DERIVED)
	$(MAKE) accept MILESTONE=$(MILESTONE) DERIVED=$(DERIVED)
	$(MAKE) accept-edits MILESTONE=$(MILESTONE) DERIVED=$(DERIVED)

accept-progress:
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=progress TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/ProgressAcceptanceTests

accept-video:
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=video TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/EditPlanAcceptanceTests -only-testing:PrakritiTests/VideoAcceptanceTests

# accept-viewer-video  v2 part M8c's acceptance (PLAN M8 check 4 on a real talk): a 5-minute excerpt of the REAL 13 Sep talk
#                 (~/Prakriti/Dev/Excerpts, cut with -c copy from 2:00) made in development with the edited video on, opened in the
#                 Viewer on Video, and six frames at known plan times compared by PSNR: the MP4's against the Viewer's own player item
#                 with its videoComposition (38 dB or better). Numbers only, no frame of the talk is written. Also writes the
#                 test-pattern video folder look-video captures. Writes acceptance-viewer-video.txt to ../screens/mac/$(MILESTONE)/
#                 (about 3 minutes)
accept-viewer-video:
	./scripts/make-fixtures.sh --if-missing
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=viewer-video TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/ViewerVideoAcceptanceTests

# accept-people-video  v2 part M8d's acceptance (PLAN M8 check 6, and check 3 again, on two-people-mixed.mp4): the fixture made
#                 in development with the Edited video on, everyone included, then Gabriel teaching and everyone else set to Leave
#                 Out and made again: the video must be kept with the corner face hidden and the second voice cut, both output
#                 checks passing inside the gate; the MP4 measured (ffprobe, ebur128, boxes, the last 5 s decoded, the Ready
#                 checklist), transcribed again by Parakeet (0 runs of the say paragraph), the corner's place measured in the made
#                 frames (no face, variance down 80%), the Viewer's composition against the file, and the video made again with
#                 hiding switched off for that track by a test switch, which the gate must stop with the time. Numbers only; one
#                 frame written to for-ivan/ for Ivan. Writes acceptance-people-video.txt to ../screens/mac/$(MILESTONE)/ (about 4 minutes)
accept-people-video:
	./scripts/make-fixtures.sh --if-missing
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=people-video TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/PeopleVideoAcceptanceTests

# accept-style  v2 part M9a's acceptance (PLAN M9 checks 3 and 4 for Clear): the 5-minute excerpt of the REAL 13 Sep talk, then
#                 the whole talk, made in development with the edited video on and the House Style at its standard (Clear); the
#                 plan counted (visual changes a minute and in the first 30 s from cuts and punch changes, every punch-in at most
#                 1.15 on the 1080p source, the scales alternating, back to wide, speech ending 5 s before the last frame), then
#                 three punch-ins and a push-in measured in the MP4 by Vision's pupils (the eye line within the upper third, plus
#                 or minus 5%) and by PSNR against the original framed by Core Graphics. Numbers only; the frames are written to
#                 for-ivan/ and not looked at (D1). STYLE_ONLY="13 Sep excerpt" runs the excerpt alone. Writes
#                 acceptance-style.txt to ../screens/mac/$(MILESTONE)/ (about 10 minutes)
accept-style:
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=style TEST_RUNNER_PRAKRITI_STYLE_ONLY="$(STYLE_ONLY)" TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/StyleAcceptanceTests

# accept-text  v2 part M9b's acceptance (PLAN M9 checks 2 and 4 for the title and the lower third): the typeface contact sheet
#                 (typeface.png: the IAST test string and every IAST letter in Noto Sans, Source Sans 3 and Inter from
#                 ~/Prakriti/Dev/Fonts and the bundled Alegreya Sans, each CTFont asked for every glyph), then the REAL 13 Sep
#                 talk's 5-minute excerpt made in development with a test title and a teacher named, and every text moment of the
#                 made MP4 (every 0.5 s of each text's life) measured: the text's pixels against the same frame without text, inside
#                 title safe, clear of every face Vision finds. Writes acceptance-text.txt; frames of the talk go to for-ivan/ and
#                 are not looked at (about 3 minutes)
accept-text:
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=text TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/TextAcceptanceTests

# accept-direction  v2 part M9c's acceptance (PLAN M9 check 3 for Energetic, Focus and length, and pace-only): the WHOLE REAL 13 Sep
#                 talk made in development (transcript, faces, voices; no video, no writing), then Plan the Edit with a direction each
#                 time, every plan read back and counted: "More energetic. Faster, more frequent cuts." (chips, 12 to 15 changes a minute,
#                 median shot 3 to 4 s, no model asked), "Focus on the parts that are motivating or enlightening. Under 10 minutes." (the
#                 beats by Qwen3.8-27B in LM Studio, timed; 8:30 to 10:00; kept beats score higher), the same at Brisk (0 LM Studio
#                 requests, planned in under 10 s), "Show the students." (nothing changes), then the beats asked for again to see whether
#                 LM Studio honours the seed (DIRECTION_SEED=skip leaves it out; KEEP_BEATS=1 keeps an earlier run's beats.json). Needs LM Studio's server. Nothing goes to a cloud
#                 provider. Writes acceptance-direction.txt to ../screens/mac/$(MILESTONE)/ (about 10 to 30 minutes, most of it the model)
DIRECTION_SEED ?=
KEEP_BEATS ?=
# accept-hook   v2 part M9d's acceptance (PLAN M9 checks 3 for Clear in full, 4 at every text moment, and 6), on the REAL 13 Sep talk,
#                 whole, in development with the video on: the parts of the talk from ~/Prakriti/Dev/Beats when they were made from this
#                 transcript (else Qwen3.8-27B in LM Studio, about 15 minutes), every visual change and every text counted, every text
#                 moment measured (title safe, clear of faces, numbers only), then version 2 with a direction, Play between versions
#                 and Approve into the development Approved folder. Writes acceptance-hook.txt (about 30 minutes)
accept-hook:
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=hook TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/HookAcceptanceTests

# accept-timeline-people  v2 part M10b's acceptance (PLAN M10 check 3, and the left-out microphone track): two-people-mixed.mp4
#                 and two-people-tracks.mov made in development with the edited video and the Timelines on, everyone included (a
#                 clone), then Gabriel teaching and everyone else Leave Out: the timelines kept on privacy-safe media, grep "Studio
#                 Recordings" 0 over both files, Vision on the media five frames a second finds no face in the hidden place,
#                 Parakeet hears 0 runs of the second voice on every track and in the removed stretches, the media the used ranges plus
#                 2 s handles to the frame, the second voice's own microphone track left out. Then writes the round-trip files for
#                 PLAN checks 6 and 7 (push-ins as moves) to ~/Prakriti/Dev/Round trip v2-m10b. Writes acceptance-timeline-people.txt
#                 to ../screens/mac/$(MILESTONE)/ (about 10 minutes)
accept-timeline-people:
	./scripts/make-fixtures.sh --if-missing
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=timeline-people TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/TimelinePeopleAcceptanceTests

# accept-timeline-full  v2 part M10b, the whole talks (the last part of M10): the REAL 13 Sep and 6 Sep talks made in development
#                 with the edited video and the Timelines on (Clear, Gabriel teaching, parts from ~/Prakriti/Dev/Beats): both files valid
#                 and clean, the video's length, a clone; then 13 Sep with every other face set to Hide Face, the timelines on
#                 privacy-safe media of the whole talk, its size and speed measured. About 40 minutes; needs about 15 GB free.
#                 Writes acceptance-timeline-full.txt to ../screens/mac/$(MILESTONE)/
accept-timeline-full:
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=timeline-full TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/TimelinePeopleAcceptanceTests/testTimelinesForTheWholeTalks

# accept-timeline  v2 part M10a's acceptance (PLAN M10 checks 2 and 4): the REAL 13 Sep talk's 5-minute excerpt made in development
#                 with the edited video and the Timelines on (Clear, a test title, Gabriel named; the parts of the talk from ~/Prakriti/Dev/Beats
#                 when made from this transcript, else Qwen3.8-27B in LM Studio, a few minutes): both FCPXML files valid against Final Cut
#                 Pro's own DTDs (copied to build/dtd) and clean under the lint in place; every media-rep src in the Timeline folder, none
#                 in Studio Recordings; every Media/ file a clone proved per file with getattrlist; every Graphics/ clip ProRes 4444 with
#                 alpha, decoded to its end, one frame of each text written to graphics/ to look at (text only); Make Timelines again from
#                 the video already made; refused with the teacher set to Hide Face. Then runs resolve-import (PLAN check 5). Writes
#                 acceptance-timeline.txt to ../screens/mac/$(MILESTONE)/ (about 5 minutes with cached beats)
accept-timeline:
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=timeline TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/TimelineAcceptanceTests
	-$(MAKE) resolve-import MILESTONE=$(MILESTONE)

# resolve-import  PLAN M10 check 5 (not a ship gate): DaVinci Resolve 20.2.1 imports the Resolve timeline accept-timeline wrote, by its
#                 own scripting API, into a new scratch project ("Prakriti scratch v2-m10", never an existing one), and the clip count and
#                 length are compared with the file's. Opens Resolve if it is not open (and quits it again after, only then). The free
#                 edition may refuse outside scripts: then it writes SKIPPED with the reason, and Ivan runs the same script from
#                 Workspace, Scripts (steps in BUILD-LOG). Writes resolve-import.txt to ../screens/mac/$(MILESTONE)/
resolve-import:
	mkdir -p ../screens/mac/$(MILESTONE)
	/usr/bin/python3 scripts/resolve-import.py --open | tee ../screens/mac/$(MILESTONE)/resolve-import.txt

accept-direction:
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=direction TEST_RUNNER_PRAKRITI_DIRECTION_SEED=$(DIRECTION_SEED) TEST_RUNNER_PRAKRITI_DIRECTION_KEEP_BEATS=$(KEEP_BEATS) TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/DirectionAcceptanceTests

# look-video  v2 part M8c's real window (PLAN M8 check 7): a development copy on sample data opens the test-pattern video that
#                 accept-viewer-video wrote, on Video with the Captions overlay on and --debug-playback-log, Space is sent, and
#                 playback is proved from the log (two currentTime lines 3 s apart differ by 2.5 to 3.5 s at rate 1, rendition
#                 video); the window is captured to ../screens/mac/$(MILESTONE)/real/14-viewer-video.png. Takes the screen's focus
#                 for about half a minute
VIDEO_SAMPLE ?= $(HOME)/Prakriti/Dev/Fixtures/viewer-video-sample

look-video: build
	swift scripts/capture-window.swift --video $(APP) "$(VIDEO_SAMPLE)" ../screens/mac/$(MILESTONE)/real

accept-capture:
	./scripts/make-fixtures.sh --if-missing
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=capture TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/CaptureAcceptanceTests

# accept-people  v2 part M6a's acceptance: the face step through the app's runner in development on the REAL 13 Sep
#                 talk (made on engine v0's chain: one face track group over 95% of the frames, or its second faces written
#                 down for Ivan; the episode equal to engine v0's bit for bit), the two-people-mixed and two-people-tracks
#                 fixtures (two faces at once, the corner one from 0:20 to 0:60, the notice once), the face step alone on
#                 the REAL 6 Sep talk timed (under 5 minutes), nothing stored for strangers (no Faces, Voices or FaceIndex
#                 folder, no job folder, no print or picture in a people file, no image under Application Support), the
#                 People tab and cards drawn; then the crash check (scripts/people-crash-check.sh): a face step killed
#                 with SIGKILL leaves its job folder, and the next development launch deletes it before its first look.
#                 Then v2 part M6b's half (VoicesAcceptanceTests): the voices of the 13 Sep talk (diarizer) with Who Is
#                 Teaching set to Gabriel ("Gabriel speaks for N percent."), two-people-tracks (who speaks from tracks 2
#                 and 3, said in the log), two-people-mixed, the whole people pass on the 6 Sep talk timed (under 5
#                 minutes), the privacy lock counted in cloud requests through the writer with a scripted cloud client.
#                 Then v2 part M6c's half (ChoicesAcceptanceTests): two-people-mixed and two-people-tracks made with
#                 everyone included, then Gabriel teaching and everyone else Left Out and made again with the podcast-ready
#                 episode; both episodes transcribed again by Parakeet (0 runs of the second voice, 98% of the 13 Sep words
#                 kept, in order); the audio output check passing, and catching a planted miss; the names said aloud in the
#                 13 Sep talk counted, one muted and measured silent with [name] in the captions.
#                 Writes acceptance-people.txt, acceptance-voices.txt, acceptance-choices.txt and crash-check.txt to
#                 ../screens/mac/$(MILESTONE)/ (about 25 minutes)
accept-people:
	./scripts/make-fixtures.sh --if-missing
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=people TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/PeopleAcceptanceTests -only-testing:PrakritiTests/VoicesAcceptanceTests -only-testing:PrakritiTests/ChoicesAcceptanceTests -only-testing:PrakritiTests/HidingAcceptanceTests
	./scripts/people-crash-check.sh $(APP) ../screens/mac/$(MILESTONE)

# accept-gallery  v2 part M7a's acceptance (PLAN M7 check 2, no release recorded): the two-people-mixed fixture made with
#                 its people check in development; the gallery has no named person and its Unnamed people tile lists the
#                 fixture; Name This Person on the corner face opens at Name Only, and Name Only names it; afterwards
#                 People/Faces, Voices and FaceIndex hold no files (development and live) and the vault keeps nothing;
#                 tmutil isexcluded on the development People folder reports Excluded (the live one is written down).
#                 Writes acceptance-gallery.txt and the gallery's pictures to ../screens/mac/$(MILESTONE)/ (about 2 minutes)
#                 Then v2 part M7b's half (RecognitionAcceptanceTests): PLAN M7 check 3 written as SKIPPED, blocked on Ivan, until
#                 ~/Prakriti/Dev/Fixtures/ivan-clip.mov and his release exist; with nobody learned, recognition does nothing (no
#                 face index, no vote); then the identify pass measured in a scratch folder against an index of one sealed
#                 test-pattern crop (no face of anyone): frames, faces found, how many chosen boxes the analyzer's boxes land on,
#                 every row unnamed, the SHA-256 list of every file under that People/ identical before and after, no job folder
#                 left, and Forget removing the index with the last person. Writes acceptance-recognition.txt (about 2 minutes)
accept-gallery:
	./scripts/make-fixtures.sh --if-missing
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=gallery TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/GalleryAcceptanceTests -only-testing:PrakritiTests/RecognitionAcceptanceTests

# calibrate-people  v2 part M7b (PLAN M7, research-people.md 6.1): copies the DEVELOPMENT store (sqlite3 .backup; the store is
#                 only read) and counts every face row recognition voted on against Ivan's answers (a name he gave, a Yes or a
#                 Not in Review): named and right, the wrong person, a stranger taken for a named person (must stay under 1 in
#                 1,000), asked, missed. SKIPPED until releases are recorded and Review is answered. STORE=<a store> reads
#                 that store instead. Writes calibrate-people.txt to ../screens/mac/$(MILESTONE)/
CALIBRATE_COPY = $(CURDIR)/$(DERIVED)/calibrate-copy/Prakriti.store
STORE ?= $(HOME)/Library/Application Support/Prakriti/Development/Prakriti.store

calibrate-people:
	rm -rf $(DERIVED)/calibrate-copy && mkdir -p $(DERIVED)/calibrate-copy
	/usr/bin/sqlite3 "file:$(STORE)?mode=ro" ".backup '$(CALIBRATE_COPY)'"
	TEST_RUNNER_PRAKRITI_CALIBRATE_STORE=$(CALIBRATE_COPY) TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/CalibrationAcceptanceTests

accept-outputs:
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=outputs TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/OutputsAcceptanceTests

accept-edits:
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=edits TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/EditsAcceptanceTests

accept-models:
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=models TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/ModelsAcceptanceTests

accept-podcast:
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=podcast TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/PodcastReadyAcceptanceTests

accept-episode-text:
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=episode-text TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/EpisodeTextAcceptanceTests

accept-names:
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=names TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/NameRecallAcceptanceTests

# accept-providers v2 part M5b's check 6: each cloud key against its provider's free GET /v1/models, then one write of
#                 synthetic-transcript.json per provider. Costs a few cents, so it runs only with YES=1 (Ivan's yes),
#                 and reads keys only from the TESTS' Keychain items, never the app's. Without a yes or a key it reports
#                 SKIPPED. Writes acceptance-providers.txt to ../screens/mac/$(MILESTONE)/
accept-providers:
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=providers TEST_RUNNER_PRAKRITI_PROVIDERS_YES=$(YES) TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/ProvidersAcceptanceTests

accept-help: build
	swift scripts/capture-window.swift --help $(APP) ../screens/mac/$(MILESTONE)/real

accept-first-launch: build
	swift scripts/capture-window.swift --first-launch $(APP) ../screens/mac/$(MILESTONE)/real

STORE_COPY = $(CURDIR)/$(DERIVED)/store-copy/Prakriti.store

FROM ?= $(HOME)/Library/Application Support/Prakriti/Prakriti.store

migrate-check:
	rm -rf $(DERIVED)/store-copy && mkdir -p $(DERIVED)/store-copy
	/usr/bin/sqlite3 "file:$(FROM)?mode=ro" ".backup '$(STORE_COPY)'"
	TEST_RUNNER_PRAKRITI_STORE_COPY=$(STORE_COPY) $(XCB) test -only-testing:PrakritiTests/StoreMigrationTests

run: build
	open $(APP)

# PLAYBACK: a recording in the DEVELOPMENT store that has an episode, opened in the Viewer for the playback check
PLAYBACK ?= $(HOME)/Prakriti/Dev/Clips/2026-09-13 clip 90s.mp4

look: build
	swift scripts/capture-window.swift $(APP) ../screens/mac/$(MILESTONE)/real
	swift scripts/capture-window.swift --playback $(APP) "$(PLAYBACK)" ../screens/mac/$(MILESTONE)/real

check: build test
	./scripts/check-launch.sh $(APP)
	swift scripts/capture-window.swift $(APP) ../screens/mac/$(MILESTONE)/real

install: build
	./scripts/install.sh $(APP)

drop:
	./scripts/drop-in-app.sh $(MODE) ../screens/mac/$(MILESTONE)/real
