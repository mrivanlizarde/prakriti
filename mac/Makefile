# Prakriti for Mac. Every command runs from this folder:
#   cd ~/Code/prakriti/mac && make build
#
# make generate   regenerate Prakriti.xcodeproj from project.yml (needs: brew install xcodegen)
# make build      build the app (signed, warnings fail the build)
# make test       run every unit test (includes the snapshot render)
# make snapshots  render every screen, light and dark, to ../screens/mac/$(MILESTONE)/
# make run        build, then open the app
# make check      build, test, launch, and prove it keeps running with its window closed

PROJECT   = Prakriti.xcodeproj
SCHEME    = Prakriti
DERIVED   = build
APP       = $(DERIVED)/Build/Products/Debug/Prakriti.app
MILESTONE ?= latest
XCB       = xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED) -destination 'platform=macOS'

.PHONY: generate build test snapshots run check

generate:
	xcodegen generate

build:
	$(XCB) build

test:
	TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test

snapshots:
	TEST_RUNNER_PRAKRITI_SNAPSHOT_MILESTONE=$(MILESTONE) $(XCB) test -only-testing:PrakritiTests/SnapshotTests

run: build
	open $(APP)

check: build test
	./scripts/check-launch.sh $(APP)
