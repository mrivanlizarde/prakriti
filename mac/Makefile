# Prakriti for Mac. Every command runs from this folder:
#   cd ~/Code/prakriti/mac && make build
#
# make generate   regenerate Prakriti.xcodeproj from project.yml (needs: brew install xcodegen)
# make build      build the app (signed, warnings fail the build)
# make test       run every unit test (includes the snapshot render)
# make snapshots  render every screen, light and dark, to ../screens/mac/$(MILESTONE)/
# make accept     milestone 2's acceptance on REAL recordings through the app's pipeline: the 13 Sep
#                 talk, the silent 14 Sep class, a 30 s clip, the 6 Sep talk. Writes episodes to
#                 ~/Prakriti/Dev/Outputs and pictures plus acceptance.txt to ../screens/mac/$(MILESTONE)/
#                 (takes about 4 to 5 minutes)
# make run        build, then open the app
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
XCB       = xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED) -destination 'platform=macOS'

.PHONY: generate build test snapshots accept run look check install drop

generate:
	xcodegen generate

build:
	$(XCB) build

test:
	TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test

snapshots:
	TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/SnapshotTests

accept:
	TEST_RUNNER_PRAKRITI_ACCEPTANCE=1 TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/PipelineAcceptanceTests

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
