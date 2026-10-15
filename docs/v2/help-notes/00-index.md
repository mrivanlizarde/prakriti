# Builder notes: 00-index.md

The team's notes for the in-app Help article `mac/Prakriti/Resources/Help/00-index.md` ("Prakriti Help").
Moved out of the article in v2 part M2a so the app bundle holds user text only. Never shown in the app.

## Status after v2 part M2a (Sun 11 Oct 2026)

- The contents page Help opens on (`home`). Its section headings are the sidebar's section names.
- `:::requires style` around Directing the Edit. When a part makes a new article visible, add its line here
  in the same commit, inside the same capability block as the article's `requires`.
- The "How these files work" and "House rules" notes below are superseded by `docs/v2/help/README.md`.

## Notes from the help track (Sat 10 Oct 2026)

### How these files work

- One Markdown file per article. The YAML front matter carries `id`, `title`, `summary` (for search
  results), `keywords` (for Help search), and `related`.
- Links between articles use the file name (`05-outputs.md`). The app maps them to its own Help
  viewer. A heading inside an article can be linked as `05-outputs.md#edited-video` if the viewer
  supports anchors.
- **Everything below the `<!-- builder-notes -->` line in each file is for the team and is never
  shown in the app.** It holds sources, assumptions about v2 features, and `[unverified]` marks.
- `welcome-panels.md` is not a Help article. It is the exact copy for the first-launch panels.
- Suggested placement: Help > Prakriti Help opens this index in a Help window with search; Help >
  Welcome to Prakriti reopens the panels; a small Help button (the "?" circle) on the Sources,
  Outputs, People and Models screens opens the matching article, as Apple's apps do.

### House rules for this copy

- No em dashes or en dashes anywhere (checked by script on 10 Oct 2026). Use "to" for ranges.
- Second person, present tense, short sentences, no "we", no selling words. Describe, never sell.
- Apple Help shape: an imperative or plain-noun title, a one-to-two sentence intro, numbered steps
  for tasks, "Tip:", "Note:" and "Important:" callouts, "See also" at the end. Menus as
  "choose File > Import > XML"; buttons "click"; checkboxes "select"; switches "turn on".
- UI names in **bold** or plain text must match the build exactly. When the build renames a feature,
  update every article in the same commit (project rule: the doc changes with the change).

### UI names these articles assume (confirm against the build)

| Name used | Where | Status on 10 Oct 2026 |
|---|---|---|
| Today, Recordings, Sources, Outputs, Models, Activity, Settings | Sidebar | Built in v1 |
| People | Sidebar, the gallery of named people | v2, assumed |
| People in This Recording | Recording page | v2, assumed |
| Include, Blur, Remove | Per person, per output | v2, from REQUEST.md |
| Name This Person, "This person has agreed to be recognized", Not This Person, Forget This Person | People | v2, assumed |
| The viewer | Recording page | v2, assumed (Ivan's item 10) |
| Direction, presets Clear, Energetic, Calm, Teaching, Highlights | Recording page | v2, assumed |
| Moments From Other Recordings, Add | Recording page | v2, assumed |
| Ready to post (checklist) | Beside the edited video | v2, assumed |
| Capture check | Recording page of a test file | v2, recommended |
| OpenAI API | Models | v2 (Ivan's item 5) |
| Help > Welcome to Prakriti, Help > Show Log in Finder | Help menu | v2, recommended |
| View > Show Recordings With Other People | Recordings | v2, assumed |
| Podcast-ready episode, Upload checklist | Outputs | Being built by another run on 10 Oct |

### Findings that change or refine earlier decisions

1. **OBS records Hybrid MOV by default on a Mac since OBS 32.0**, not Hybrid MP4 (SCOPE SET-04).
   Both are crash-safe; accept either. (03)
2. **Record 4K horizontal and drop the separate vertical canvas** (SCOPE SET-05): a 4K frame gives
   full-size 1080x1920 shorts and sharp 2x punch-ins. Keep the vertical canvas only at 1080p. (03)
3. **4K multiplies what syncs through the shared iCloud folder** several times over. Decide storage
   before the studio visit. (03)
4. **The timeline export must point at privacy-processed media**, or Final Cut Pro shows every face
   and voice Prakriti removed. (05, 07)
5. **The privacy lock leaves smaller Macs unable to edit classes**: classes cannot go to a cloud
   model, and Apple's on-device model is too small for a one-hour class. Needs a decision. (09)
6. **"Blur" is read as face blurred plus speech removed**, which is REQUEST.md's stated default for
   unnamed people. Confirm, or split face and voice choices. (07)
7. **YouTube's thumbnail guidance changed:** 3840 x 2160 recommended, 50 MB on desktop. Shorts can be
   up to 3 minutes. (05)
8. **Approving classes** becomes possible in v2 only if the build lifts v1's "talk, one teacher" rule;
   that is a policy change for Ivan and Serenity, not a default. (06)

## Status after v2 part M9c (Thu 15 Oct 2026)

- "Directing the Edit" moved from `style` to `direction` and now reads "presets, your own words, a pace and a length, and the plan
  before anything is made" (moments from other recordings are M12).
