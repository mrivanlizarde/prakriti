# Pick up here (written Fri 16 Oct 2026, after the v2 run was stopped to save the weekly limit)

State: all 33 v2 parts built and committed; the live app (~/Applications/Prakriti.app) was installed from `main`
at 298b0f0 + README edit, Fri 16 Oct evening. Every part M0 to M12b passed an independent verifier.

## Not done
1. **M13 verifier never ran.** Resume the run to finish only that step and the handover:
   `Workflow({scriptPath: "<session>/workflows/scripts/prakriti-mac-v2-wf_dfc0c5b5-389.js", resumeFromRunId: "wf_dfc0c5b5-389"})`
   (in a new session without that run: open a fresh session, read docs/v2/PLAN.md "M13" and run its checks once,
   by hand, on the 13 Sep and 6 Sep talks).
2. **Handover section** "v2 run: where it stands" in docs/BUILD-LOG.md is not written for M13.
3. **Thumbnail cut-out fix** (halo, leftover background) was built in M13 (`ThumbnailMatte.swift`) but not verified:
   remake 13 Sep thumbnails and look at A, B, C at 1280 and 168 px.

## Only Ivan can do (from verifiers' "blocked" lists)
- Turn on notifications for Prakriti; record each person's release in People.
- Listen: 13 Sep edited video (Clear and versions), episode 1 old vs Podcast-ready.
- Look: thumbnails, shorts frames, hidden-face picture, Dock and menu bar icon in light, dark, tinted.
- Typeface: confirm Alegreya Sans for on-video text (or Noto Sans).
- Open one timeline in Final Cut Pro 12.4 and DaVinci Resolve (round trips were never run by a person).
- Make Again on the 6 Sep talk in live Outputs, so its transcript picks up the TXGAP fix.
- Optional: one private YouTube test upload to confirm the upload checklist.

## Known limits worth knowing
- Video audio is 320 kbps (Mac encoder max), accepted.
- Tests must never quit the live app; if found closed, `open ~/Applications/Prakriti.app`.
- Weekly limit: this run used about 11M tokens; keep the next build small.
