#!/usr/bin/env python3
"""PLAN M10 check 5 (v2 part M10a), not a ship gate: DaVinci Resolve imports the timeline Prakriti wrote for it.

It makes a NEW scratch project ("Prakriti scratch v2-m10", never an existing one of Ivan's), imports the Resolve file with
Resolve's own scripting API (MediaPool.ImportTimelineFromFile, documented in Resolve's scripting README on this Mac), and prints
the clip count on the first video track and the length in frames, against the file's own (what accept-timeline wrote to
~/Prakriti/Dev/resolve-import-expected.txt). Nothing else in Resolve is touched.

Two ways to run it:
- From Terminal (make resolve-import): it connects from outside. Resolve must be open, and Preferences, System, General,
  "External scripting using" set to Local; the free edition may refuse outside scripts whatever that says. With --open it opens
  Resolve first when it is not running, and quits it again afterwards (only then). If it cannot connect it prints SKIPPED and why.
- From inside Resolve (Ivan, about 3 minutes): copy this file to
  ~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/, then in Resolve choose
  Workspace > Scripts > resolve-import. It reads the file's path from ~/Prakriti/Dev/resolve-import.txt and prints to the Console
  (Workspace > Console).
"""
import os
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
API = "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting"
LIB = "/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fusionscript.so"
PROJECT = "Prakriti scratch v2-m10"


def say(line):
    print(line, flush=True)


def connect():
    """The Resolve object: inside Resolve its own, else through fusionscript from outside, or None."""
    for name in ("resolve",):
        if name in globals() and globals()[name] is not None:
            return globals()[name]
    try:
        return app.GetResolve()  # noqa: F821 (defined inside Resolve)
    except Exception:
        pass
    try:
        return bmd.scriptapp("Resolve")  # noqa: F821
    except Exception:
        pass
    os.environ.setdefault("RESOLVE_SCRIPT_API", API)
    os.environ.setdefault("RESOLVE_SCRIPT_LIB", LIB)
    sys.path.append(os.path.join(API, "Modules"))
    try:
        import DaVinciResolveScript as dvr  # type: ignore
    except Exception as error:  # the module or the library cannot be loaded
        say(f"SKIPPED: Resolve's scripting module could not be loaded ({error}).")
        return None
    try:
        return dvr.scriptapp("Resolve")
    except Exception as error:
        say(f"SKIPPED: Resolve did not answer ({error}).")
        return None


def running():
    return subprocess.run(["/usr/bin/pgrep", "-x", "Resolve"], capture_output=True).returncode == 0


def main():
    path_file = os.path.join(HOME, "Prakriti/Dev/resolve-import.txt")
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    path = args[0] if args else (open(path_file).read().strip() if os.path.exists(path_file) else "")
    if not path or not os.path.exists(path):
        say(f"SKIPPED: no Resolve timeline to import ({path or path_file} is not there). Run make accept-timeline first.")
        return 0
    expected = None
    expected_file = os.path.join(HOME, "Prakriti/Dev/resolve-import-expected.txt")
    if os.path.exists(expected_file):
        clips, frames = open(expected_file).read().split()
        expected = (int(clips), int(frames))
    say(f"File: {path}")
    opened = False
    if "--open" in sys.argv and not running() and os.path.exists("/Applications/DaVinci Resolve/DaVinci Resolve.app"):
        say("Resolve is not open: opening it, to try once.")
        subprocess.run(["/usr/bin/open", "-g", "-a", "/Applications/DaVinci Resolve/DaVinci Resolve.app"])
        opened = True
        for _ in range(90):
            if running():
                break
            time.sleep(1)
        time.sleep(45)  # its start-up: databases, panels
    try:
        resolve = connect()
        if resolve is None:
            say("SKIPPED: Prakriti could not reach DaVinci Resolve from outside it. The free edition allows scripts only from "
                "Workspace > Scripts inside Resolve, or External scripting is not set to Local. Ivan: run this script from "
                "Workspace > Scripts (steps in BUILD-LOG, v2 part M10a).")
            return 0
        say(f"Connected: {resolve.GetProductName()} {resolve.GetVersionString()}")
        manager = resolve.GetProjectManager()
        project = manager.CreateProject(PROJECT)
        if project is None:
            # Only our own scratch project, from an earlier try, is ever loaded again.
            project = manager.LoadProject(PROJECT)
        if project is None:
            say(f"FAIL: the scratch project {PROJECT} could not be made.")
            return 1
        pool = project.GetMediaPool()
        timeline = pool.ImportTimelineFromFile(path, {"timelineName": "Prakriti " + time.strftime("%H%M%S"), "importSourceClips": True})
        if timeline is None:
            say("FAIL: ImportTimelineFromFile returned nothing: Resolve did not import the file.")
            return 1
        items = timeline.GetItemListInTrack("video", 1) or []
        frames = timeline.GetEndFrame() - timeline.GetStartFrame()
        say(f"Imported: {len(items)} clips on video track 1, {timeline.GetTrackCount('video')} video tracks, "
            f"{timeline.GetTrackCount('subtitle')} subtitle tracks, {frames} frames.")
        if expected:
            ok = len(items) == expected[0] and abs(frames - expected[1]) <= 1
            say(f"{'PASS' if ok else 'FAIL'}: the file holds {expected[0]} clips and {expected[1]} frames.")
            return 0 if ok else 1
        return 0
    finally:
        if opened and running():
            subprocess.run(["/usr/bin/osascript", "-e", 'tell application "DaVinci Resolve" to quit'])
            say("Resolve quit again (it was opened for this try).")


try:
    INSIDE = app is not None  # noqa: F821 (Resolve defines `app` for scripts run from Workspace > Scripts)
except NameError:
    INSIDE = False

if INSIDE:
    main()
else:
    sys.exit(main())
