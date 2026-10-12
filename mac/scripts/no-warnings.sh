#!/bin/bash
# Fails the build if the build output has any warning. Reason (12 Oct, v2 part M3a): Swift's
# warnings-as-errors setting does not turn every warning into an error. A main-actor property read in a
# Sendable NotificationCenter closure (PrakritiApp.swift) stayed a warning under
# SWIFT_TREAT_WARNINGS_AS_ERRORS=YES and -swift-version 6, the build succeeded, and a "0 warnings" claim
# shipped live. Measured with swiftc -typecheck -warnings-as-errors: exit 0 with the warning printed.
# So the build output itself is read. The one exempt line is Apple's appintentsmetadataprocessor
# notice ("no AppIntents.framework dependency found"), which is a tool's note, not a compiler warning.
#   ./scripts/no-warnings.sh build/build-output.log
set -euo pipefail
LOG="${1:?usage: no-warnings.sh <build log>}"
[ -f "$LOG" ] || { echo "FAIL: no build log at $LOG"; exit 1; }
FOUND=$(grep -E "(^|[ :])warning:" "$LOG" | grep -v "appintentsmetadataprocessor" | grep -vE "^ +\|" | sort -u || true)
if [ -n "$FOUND" ]; then
  echo "FAIL: the build has warnings (a warning is a failed build):"
  echo "$FOUND"
  exit 1
fi
echo "No warnings."
