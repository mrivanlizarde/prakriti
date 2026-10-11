# Prakriti for Mac. Every command runs from this folder:
#   cd ~/Code/prakriti/mac && make build
#
# make generate   regenerate Prakriti.xcodeproj from project.yml (needs: brew install xcodegen)
# make build      build the app (signed, warnings fail the build)
# make test       run every unit test (includes the snapshot render)
# make snapshots  render every screen, light and dark, to ../screens/mac/$(MILESTONE)/
#                 (ONLY=recording draws just the recording pages, ONLY=help just the Help window)
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
# make migrate-check  copy the live store (sqlite3 .backup, a consistent snapshot; the live store
#                 is only read) into build/store-copy and open the COPY with this build's models.
#                 Run it before `make install` whenever the models change
# make run        build, then open the app
# make accept-help  v2 part M2a's check of Prakriti Help in the REAL app: the Help window opened on its own
#                 with sample data at three articles and a search, light and dark, captured to
#                 ../screens/mac/$(MILESTONE)/real/; then the Help menu's search handler run for OBS,
#                 notifications and privacy (the debug switch --debug-help-search), each needing its
#                 expected article first. Writes acceptance-help.txt (takes the screen's focus for about
#                 half a minute)
# make look       open the REAL app on sample data, capture every screen light and dark to
#                 ../screens/mac/$(MILESTONE)/real/, and check the selected sidebar row (takes the
#                 screen's focus for about a minute; do not touch the Mac while it runs)
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
XCB       = xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED) -destination 'platform=macOS'

.PHONY: generate build test snapshots fixtures accept regress accept-outputs accept-edits accept-models accept-podcast accept-episode-text accept-help migrate-check run look check install drop

generate:
	xcodegen generate

build:
	$(XCB) build

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

accept-help: build
	swift scripts/capture-window.swift --help $(APP) ../screens/mac/$(MILESTONE)/real

STORE_COPY = $(CURDIR)/$(DERIVED)/store-copy/Prakriti.store

migrate-check:
	rm -rf $(DERIVED)/store-copy && mkdir -p $(DERIVED)/store-copy
	/usr/bin/sqlite3 "$(HOME)/Library/Application Support/Prakriti/Prakriti.store" ".backup '$(STORE_COPY)'"
	TEST_RUNNER_PRAKRITI_STORE_COPY=$(STORE_COPY) $(XCB) test -only-testing:PrakritiTests/StoreMigrationTests

run: build
	open $(APP)

look: build
	swift scripts/capture-window.swift $(APP) ../screens/mac/$(MILESTONE)/real

check: build test
	./scripts/check-launch.sh $(APP)
	swift scripts/capture-window.swift $(APP) ../screens/mac/$(MILESTONE)/real

install: build
	./scripts/install.sh $(APP)

drop:
	./scripts/drop-in-app.sh $(MODE) ../screens/mac/$(MILESTONE)/real
