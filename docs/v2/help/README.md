# Prakriti Help: where the articles live now

Since v2 part M2a (Sun 11 Oct 2026) the Help articles are part of the app, and this folder only points at
them.

| What | Where |
|---|---|
| The eleven Help articles the app shows (`00-index.md` to `10-troubleshooting.md`), user text only | `mac/Prakriti/Resources/Help/` |
| The team's notes for each article (sources, assumptions, what is unverified, keywords to add when a feature lands) | `docs/v2/help-notes/<same file name>` |
| The welcome panels' copy (the source for part M2b; not a Help article) | `docs/v2/help-notes/welcome-panels.md` |

## How an article is written

- **Front matter**, every field required except `requires`:

  ```yaml
  id: sources-and-watching        # stable: links, the Help menu and the remembered article use it
  title: Sources and watching
  summary: One sentence, shown in search results.
  section: recording              # get-started, recording, reviewing, people, direction, outputs, settings, troubleshooting
  order: 3                        # place inside the section
  keywords: [sources, folders]    # only words for what is built
  related: [outputs, troubleshooting]   # article ids; the window draws them as Related links
  requires: style                 # optional: the whole article is hidden until this is built
  ```

- **Body:** `#` title (the same as the front matter's), `##` and `###` headings, paragraphs, numbered
  and bulleted lists, bold, italics, inline code, code blocks for Terminal commands, and links. No
  tables, images or HTML: the Help test fails on them. "**Tip:**", "**Note:**" and "**Important:**" at
  the start of a paragraph draw it with a symbol.
- **Links:** another article by file name (`[Outputs](05-outputs.md)`) or `prakriti-help://<id>`; a place
  in the app as `[Show Me](prakriti://show/<screen>)`, drawn as a button (screens: today, recordings,
  sources, outputs, models, activity, settings). The `prakriti://` scheme works only inside the Help
  window and is never registered with macOS. Nothing in Help opens a web page.
- **Only what is built.** A block that describes a feature of a later part is wrapped:

  ```
  :::requires video
  Text shown only once the edited video is built.
  :::
  :::unless video
  Text that is true until then.
  :::
  ```

  The fence lines are removed before parsing, so a block can sit between two items of a list. Blocks
  cannot be nested; an unclosed block, a stray `:::` or an unknown capability fails the Help test. The
  capabilities and the part that switches each one on are in `mac/Prakriti/Help/Capabilities.swift`.
- **Copy rules (tested):** no em or en dashes, no "we", no "Processing", "click" never "tap", and none
  of the feature names a capability not yet built introduces (the list is in `HelpTests`).

## The welcome window follows the same rule

Its words are in `mac/Prakriti/Views/Welcome/WelcomeContent.swift`, not in Markdown. Every row names the
capabilities it describes (`requires`), and a sentence true only until a part lands names that part
(`unless`), with its `-v2` twin beside it. `WelcomeTests` checks the copy rules, the symbols, the same
unbuilt feature names as Help, and every stage of the build. The copy source and its status:
`docs/v2/help-notes/welcome-panels.md`.

## When a part builds a feature

In the same commit: switch its capability on in `Capabilities.built`, read every block that requires it
and make each sentence true of what was built (rename to the build's own words), do the same for every
welcome row that names it, delete the `:::unless`
text it replaces, add its keywords, and move what the notes in `docs/v2/help-notes/` said was assumed
into what was measured. `make test` then runs the Help test with the new capability on.
