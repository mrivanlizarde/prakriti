# Prakriti for Mac v2: Ivan's request (Sat 10 Oct 2026), and the decisions already made

## His words (lightly cleaned of typos, nothing removed)
1. "As we make decisions about features that get added or not, let's not base them on the messiness of
   these initial video recordings, let's plan for best case scenarios and clean video inputs."
2. "Create a startup screen that gives initial instructions on usage tips for the app, including how to
   capture the best video." And "start building documentation for the help section of the app."
3. "Serenity isn't worried about her own privacy, just the privacy of her students. Find a way to flag
   for faces in the app. Let me know when it's Gabriel or Serenity in a video, or when it includes other
   people. I would like for all the final edits to let me choose who should be included in the output
   videos and audio."
4. "The final output of a video also has an XML for FCP or DaVinci that is an edited video file that
   removes pauses, umms, bad takes, adds captions, adds text animation and/or motion graphics, adds
   transitions and zoom in / out effects, use MKBHD as the template, and make the output 100% ready for
   distribution. I want to remove as much friction as possible between the raw video file and the
   exported file. Take this to mean the highest level of what you think it can mean."
5. "Add space for me to include an OpenAI or Anthropic API in case a user does not have a computer
   powerful enough to run the work."
6. "Give me a progress on the recordings as it's working on the output."
7. "Give me a way to prompt or adjust the editorialization of the outputs, e.g. make this video more
   energetic, faster and more frequent cuts, focus on aspects that are motivating or enlightening, etc."
8. "Give me a gallery of faces recognized in videos assuming that the user will likely be returning to
   edit content for the same subject, sort of the way that Apple Photos does this with the Faces section."
9. "Give me the option to merge sections from different videos (the subject says something in one video
   whose point can be supported by something he said in a different video). This should be able to be
   added to the video at hand but not always and not as a rule."
10. "I want to be able to preview the videos within the app and not just by navigating to the folder on
    the computer. I.e., build a viewer."
11. "I love the UI, take another pass and ask yourself how Apple would build this. Use iPhoto, FCP, and
    any of the Apple creative apps as your guides."
12. "Design a better icon for both the dock and menu bar."
Earlier the same day: podcast-ready audio (being built now in a separate run) and "I would love for the
videos to also be post ready."

## Decisions already made (Sonny, within Ivan's brief; flag if research proves one wrong)
- **Design for clean inputs.** Features assume good capture (separate mic tracks, clean framing, 1080p or
  4K). Poor inputs get a check, a warning and a capture tip, never a silent publish.
- **Students are the privacy subject.** Gabriel and Serenity may appear in outputs and real-frame
  thumbnails. Every other face or voice is flagged. Per person in each output: Include / Blur (faces) /
  Remove (their segments). Default for unnamed people: Blur faces and Remove their speech.
- **Biometric data policy.** Face and voice prints are stored only for people Ivan names and marks
  "has agreed" (the gallery of recurring subjects). Unnamed people's prints live only for the job that
  found them and are then deleted; the gallery shows them as "Unnamed, this recording only". Reason:
  stored face prints of students are the exact feature biometric-privacy suits target (Illinois BIPA,
  Colorado), see research/08-privacy-rights.md.
- **"MKBHD as the template" means his editing grammar, not his brand:** tight jump cuts, punch-in zooms
  to hide cuts, clean kinetic typography, restrained transitions, crisp audio, sharp pacing. Prakriti
  ships its own house style inspired by that grammar; it never copies his logos, colors, fonts, sound
  stings or intros.
- **"100% ready for distribution"** means every output passes the target platform's published specs and
  carries its metadata and captions, so the only step left is a human pressing Upload. Prakriti still
  never uploads or posts on its own (standing rule).
- **Two deliverables per finished video:** a rendered, ready-to-post MP4 made by Prakriti itself, and an
  editable timeline (FCPXML for Final Cut Pro; a DaVinci Resolve-compatible export) so a person can open
  the same edit and finish it by hand.
- **Thumbnails from real frames** are allowed for Gabriel and Serenity (resolves the open question).
- **Privacy lock relaxed:** "mentions Serenity" no longer forces local models; recordings that are classes
  or where other people appear or speak still do.
