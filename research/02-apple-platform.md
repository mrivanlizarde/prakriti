# Prakriti research 02: Apple platform survey and architecture recommendation

Written 2026-10-08 by a Sonny research agent. Track: every Apple framework or API that could
serve Prakriti, checked against current developer.apple.com documentation and against this Mac's
own SDK, plus a grounded architecture recommendation.

Read-only research. The only file written is this one. Benchmarks ran on copies in the session
scratchpad, which were deleted afterwards. Nothing was sent, posted or changed in any account.

Conventions: every claim carries a source (URL or local path). "Measured" means a command was run
on this Mac today and the number is ours. `[unverified]` means I could not confirm it from a primary
source. `[inferred]` means a reasoned reading of evidence, not a stated fact. No em dashes, per the
brief.

---

## 0. The answer in one screen

**Recommendation: hybrid.** A small native Mac agent ("the engine") on one Mac does the watching,
the heavy compute and the local notifications. The web app at `prakriti.therowan.studio`
(Cloudflare Workers + D1 + R2, the Up Next / VeraSales stack) is where all three people review,
browse the library, approve and trigger publishing, and it is what sends notifications to
Gabriel's and Serenity's Macs and iPhones (Web Push). The features page doubles as the login page.

Why not pure web: a browser cannot watch a folder on its own. Safari (through 27.x) and Firefox do
not implement the File System Access API at all ([caniuse](https://caniuse.com/native-filesystem-api)),
and `FileSystemObserver` is non-standard, Chrome-only, and needs an open tab
([MDN](https://developer.mozilla.org/en-US/docs/Web/API/FileSystemObserver),
[Chrome origin trial 129 to 134](https://developer.chrome.com/blog/file-system-observer)). Each studio
recording is 2.5 to 3.3 GB (measured), Workers cap request bodies at 100 MB on Free/Pro
([Cloudflare limits](https://developers.cloudflare.com/workers/platform/limits)), and Workers cannot
run ffmpeg or Apple's speech and vision models.

Why not native only: three people in three places need one shared library, one approval queue and
notifications on phones. That needs a server regardless, and a native app on three Macs triples
the signing, notarization and macOS-version surface for a non-engineer to maintain.

Why the hybrid is cheap: on this M5 Pro, a 55-minute studio talk needs roughly 2 to 3 minutes of
machine time for transcription, speaker separation, sound classification and thumbnail scoring,
plus about 6 minutes if the video is re-encoded (all measured or extrapolated from measured runs,
section 2). Local compute costs nothing per minute. Claude does the editorial writing for cents per
recording (section 7).

**The one decision Ivan has to make:** which Mac is the engine. Ivan's MacBook Pro works today but
travels and sleeps when the lid closes; an always-on Mac at the studio (Mac mini, about $1,499 to
$1,699 configured, section 12.4) makes "every new recording live within 72 hours" true while he
travels. The code is identical either way, so this can be decided after v1 works.

---

## 1. What was checked, and how

- Apple documentation was read through the documentation JSON endpoint
  (`https://developer.apple.com/tutorials/data/documentation/<path>.json`), which returns the same
  content as developer.apple.com including per-platform `introducedAt` availability.
- The macOS 27.0 SDK shipped with Xcode 27.0 on this Mac was grepped directly for ground truth:
  `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk`.
- Small Swift probes were compiled with `-target arm64-apple-macos27.0` and run to read live values
  (speech locales, Foundation Models context size, SoundAnalysis labels, Shazam limits, Vision speed).
- Benchmarks used copies of one studio recording (`2026-09-20 18-07-58.mp4`) in the scratchpad;
  copies and transcripts were deleted after measuring. No recording content is reproduced here.

---

## 2. Ground truth from this Mac and the raw material (measured)

### 2.1 The machine

| Fact | Value | Source |
|---|---|---|
| OS | macOS 27.2, build `26B5101f` (lowercase suffix suggests a beta build `[inferred]`) | `sw_vers` |
| Chip | Apple M5 Pro, 18 CPU cores (6 Super + 12 Performance), 20-core GPU, Metal 4 | `system_profiler SPHardwareDataType`, `SPDisplaysDataType` |
| Memory | 64 GB | `sysctl hw.memsize` |
| Toolchain | Xcode 27.0 (27A266a), Swift 6.4, SDK MacOSX27.0 | `xcodebuild -version`, `swift --version` |
| Disk | 804 GB free of 1.8 TB | `df -h /` |
| iCloud | about 1.62 TB of quota remaining | `brctl quota` |
| Optimize Mac Storage | ON (`optimize-storage = 1`) | `defaults read com.apple.bird` |
| Code signing identities | one: "Apple Development: ilizarde@mac.com (K55TBYNKUC)". No Developer ID Application certificate. | `security find-identity -v -p codesigning` |
| ffmpeg | 9.0.1 with `h264_videotoolbox`, `hevc_videotoolbox`, `prores_videotoolbox` | `ffmpeg -encoders` |
| Pro apps installed | Final Cut Pro (Creator Studio) 12.4, Compressor 5.4, Motion 6.4, Pixelmator Pro 4.4, DaVinci Resolve, Descript 2.4.0, CapCut 8.2.0 | `/Applications`, `CFBundleShortVersionString` |
| `fm` CLI (Foundation Models) | present at `/usr/bin/fm`, blocked until `sudo fm license` accepts Apple's terms | `fm --help` |

### 2.2 The studio folder

Path: `/Users/ivanlizarde/Documents/Design Work/Galindo x Lizarde/Studio Recordings /` (trailing
space). Facts below are measured with `ls -lO`, `mdls`, `ffprobe`, and a top-level MP4 box scan.

- **It is an iCloud shared folder and Ivan is the owner**: `kMDItemIsShared = 1`,
  `kMDItemSharedItemCurrentUserRole = NSURLUbiquitousSharedItemRoleOwner` on `Galindo x Lizarde`.
- **Contents**: 12 `.mp4` files across 9 dated folders, 17 GB total. That is 10 horizontal recordings
  plus 2 vertical twins (`-vertical.mp4`, 1080x1920) on 2026-09-06. 11 `.txt` transcripts; the
  2026-09-14 recording has none. Three files are short tests (6 to 9 MB: 09-17, 09-26, 10-02).
- **The `.txt` transcripts are not made at recording time.** They use Hark's `Speaker 1:` format and
  their modification times are 2026-10-07 12:57 to 13:04, while the videos are from September
  `[inferred: batch-run through Hark on 10-07]`.
- **All files are currently materialized** (no `dataless` flag), but with Optimize Mac Storage on,
  macOS may evict any of them at any time (section 4.1).
- **Video**: H.264 High, 1920x1080, 29.97 fps, about 6.0 Mbps; a 55-minute talk is about 2.55 GB.
- **Audio**: one AAC-LC track, 48 kHz, 2 channels, about 128 to 160 kbps. **The two channels are
  identical (dual mono)**: the RMS of left minus right over a 2-minute window is `-inf` dB while the
  left channel alone is -30.7 dB. There is no per-person microphone separation in the files today.
- **Container**: classic MP4 with the `moov` index at the end (`ftyp, free, mdat, moov`), muxed by
  libavformat `Lavf62.12.102`. Not fragmented or "hybrid" MP4. Consequence: an unfinished or crashed
  recording has no index and cannot be opened; "has a `moov` box" is a reliable completeness test.
- **Keyframes every about 1.9 s**, so stream-copy cuts land within 2 s of the requested point.
- **Loudness** of the 55-minute talk: integrated -21.2 LUFS, true peak -2.9 dBTP, loudness range
  20.6 LU (ffmpeg `loudnorm`, 72 s to analyze). Apple Podcasts asks for about -16 LKFS plus or minus
  1 dB and true peak no higher than -1 dBFS
  ([Apple Podcasts audio requirements](https://podcasters.apple.com/support/audio-requirements)).
  So every episode needs about +5 dB of gain with compression and a limiter, not just normalization.

### 2.3 Speed on the M5 Pro (measured)

| Step | Input | Wall time | Speed vs real time |
|---|---|---|---|
| Extract audio, stream copy | full 55-min recording | 1.85 s | about 1,800x |
| Loudness analysis (ffmpeg `loudnorm`) | 55 min | 72 s | about 46x |
| Transcription, Apple `SpeechAnalyzer` only (Hark debug build, `--no-speakers`) | 10 min excerpt | 6.2 s | about 97x |
| Transcription + diarization (`SpeechAnalyzer` + FluidAudio) | 10 min excerpt | 14.3 s | about 42x |
| Sound classification, `SoundAnalysis` v1, 3 s windows | 55 min | 4.6 s | about 720x |
| Vision aesthetics + face capture quality, one frame per 2 s | 120 s of 1080p | 2.9 s | about 41x |
| HEVC encode, `hevc_videotoolbox` 6 Mbps | 120 s of 1080p30 | 13.7 to 13.8 s | about 8.7x |
| H.264 encode, `h264_videotoolbox` 8 Mbps | 120 s | 13.1 s | about 9x |
| ProRes 422 encode, `prores_videotoolbox` | 120 s | 3.1 s | about 39x |
| H.264 software encode, `libx264 -preset medium -crf 20` | 120 s | 9.8 s | about 12x |
| AVFoundation export (`avconvert` HEVC 1920x1080 preset) | 120 s | 15.1 s | about 8x |

Extrapolated per 55-minute talk: transcription about 34 s, with speakers about 80 s, sound map
about 5 s, thumbnail scoring about 80 s, full HEVC re-encode about 6.3 minutes. Total under 10
minutes of machine time with a re-encode, about 3 minutes without. Hark's numbers are from a debug
build; a release build should not be slower `[unverified]`.

The M5 Pro has one video encode engine and one ProRes engine (the M5 Max has two of each)
([MacBook Pro tech specs](https://www.apple.com/macbook-pro/specs/),
[Apple support 126318](https://support.apple.com/126318)). Through ffmpeg the hardware HEVC path was
not faster than 18-core libx264; hardware encode matters more for battery and heat than for speed
here `[inferred from the table]`.

---

## 3. Framework survey: one row per framework

Verdicts: **use** (v1), **consider** (later or conditional), **skip**.

| # | Framework / API | What it does for Prakriti | OS availability | Verdict |
|---|---|---|---|---|
| 1 | FSEvents | Watches the studio folder tree, replays changes missed while the engine was off | macOS 10.5; file-level events 10.7 | **use** |
| 2 | URL resource keys + `startDownloadingUbiquitousItem` + `SF_DATALESS` | Detects evicted iCloud placeholders and pulls the real bytes down before processing | macOS 10.7 to 10.10 | **use** |
| 3 | Finder "Keep Downloaded" (pin) | Stops macOS evicting the studio folder on the engine Mac | macOS 15+ | **use** (one-time manual) |
| 4 | `NSFileCoordinator` | Coordinated, dataless-safe reads of iCloud items | macOS 10.7 | **use** for reads |
| 5 | `NSFilePresenter` | Change callbacks, but only for coordinated writes | macOS 10.0 | **skip** as a watcher |
| 6 | `DispatchSource` file-system object | Per-file-descriptor vnode events | all | **skip** |
| 7 | `NSMetadataQuery` | Spotlight-backed live queries; iCloud container scopes | macOS 10.4 | **skip** as primary |
| 8 | Shortcuts folder automation | No-code "file added" trigger | macOS 26+ | **consider** (prototype only) |
| 9 | `SMAppService` launch agent / login item | Keeps the engine running across logins, registered from the app bundle | macOS 13 | **use** |
| 10 | `ProcessInfo.beginActivity`, IOPM assertions, `caffeinate` | Prevents App Nap and idle sleep while a job runs | macOS 10.9 / 10.6 | **use** |
| 11 | `NSBackgroundActivityScheduler` | Low-priority deferrable jobs (nightly archive batches, cleanup) | macOS 10.10 | **consider** |
| 12 | `NSWorkspace` sleep/wake notifications | Pause cleanly on sleep, rescan on wake | macOS | **use** |
| 13 | UserNotifications (local) | Detected / started / complete notifications on the engine Mac | macOS 10.14; interruption levels macOS 12 | **use** |
| 14 | APNs to a native Mac or iPhone app | Pushes to Gabriel's and Serenity's devices | needs native apps | **skip** v1 |
| 15 | Web Push (Safari, Mac web apps in the Dock, iPhone Home Screen web apps), Declarative Web Push | Pushes from the web app to all three people's Macs and iPhones | Safari 16 / macOS 13; Dock web apps macOS 14; iOS 16.4; declarative iOS 18.4 / macOS 15.5 | **use** |
| 16 | `MenuBarExtra` (SwiftUI) | Engine status, pause, open web app | macOS 13 | **use** |
| 17 | WidgetKit desktop widget | Queue at a glance | macOS 14 (desktop widgets) | **consider** later |
| 18 | Live Activities | Live progress | `Activity` is unavailable on macOS; Mac only mirrors iPhone ones | **skip** |
| 19 | Control Center controls (`ControlWidget`) | Pause/resume toggle | macOS 26 | **consider** later |
| 20 | App Intents / Shortcuts / Spotlight / Siri | "Process this file", "What's in the queue", searchable transcripts | macOS 13; `IndexedEntity` macOS 15 | **consider** v2 |
| 21 | Speech: `SpeechAnalyzer` + `SpeechTranscriber` | Fast on-device long-form transcript with word timings | macOS 26; file/asset input provider macOS 27 | **use** |
| 22 | Speech: `DictationTranscriber` | Custom vocabulary (max 100 phrases), custom language model | macOS 26 | **consider** |
| 23 | Speech: `SpeechDetector` (VAD) | Skips silence | macOS 26 | **skip** (VAD trap) |
| 24 | Speaker diarization | Who spoke when | **Apple has none**, still absent from the macOS 27 SDK | FluidAudio (third party): **use** |
| 25 | Foundation Models, on-device | Small local text tasks; 8,192-token context measured | macOS 26; images in 27 | **consider** (minor role) |
| 26 | Foundation Models, Private Cloud Compute | 32K-context Apple server model | macOS 27; managed entitlement | **skip** |
| 27 | NaturalLanguage `NLLanguageRecognizer` | Detects English vs Spanish to pick the transcriber locale | macOS 10.14 | **use** |
| 28 | NaturalLanguage `NLContextualEmbedding` | On-device semantic vectors (512 dims, en and es measured) | macOS 14 | **skip** for web search |
| 29 | Translation | On-device translation (Spanish captions) | macOS 14.4; headless session macOS 26.4 | **consider** later |
| 30 | Vision: `VideoProcessor` + `CalculateImageAestheticsScoresRequest` + `GenerateImageFeaturePrintRequest` | Picks three distinct, best-looking frames for thumbnails; feeds the video quality score | macOS 15 | **use** |
| 31 | Vision: `DetectFaceCaptureQualityRequest`, face rectangles, saliency | Face sharpness/lighting for thumbnails; smart crops for 16:9, 1:1, 9:16 | macOS 15 | **use** |
| 32 | Vision: body pose 2D/3D, `GeneratePersonInstanceMaskRequest`, human rectangles | Yoga pose detection, chaptering classes by movement, student blur, subject cut-outs for thumbnails | macOS 15 | **consider** |
| 33 | Vision: `DetectLensSmudgeRequest`, `RecognizeTextRequest`, `GenerateIterativeSegmentationRequest` | Hazy-camera flag, on-screen text, tap-to-segment | macOS 26 / 15 / 27 | **consider** |
| 34 | SoundAnalysis built-in classifier (303 labels) | Speech/music/silence map, singing bowl, gong, bell, breathing, laughter, applause, cough, ringtone | macOS 10.15; v1 classifier macOS 12 | **use** |
| 35 | ShazamKit | Flags copyrighted music in recordings before YouTube Content ID does | macOS 12; signature from asset macOS 13 | **use** |
| 36 | `AUSoundIsolation` audio unit (High Quality Voice) | On-device voice isolation for podcast cleanup and voice-model training audio | macOS 13; HQ voice macOS 15 | **use** (after ASR, never before) |
| 37 | AVFoundation (reader, writer, composition, export, image generator, `AVAudioEngine` offline render) | Audio extraction, cut lists, intro/outro assembly, frame grabs, offline audio processing | macOS 10.7+ | **use** |
| 38 | VideoToolbox / media engine | Hardware HEVC/H.264/ProRes encode and decode | macOS 10.8 | **use** (via AVFoundation/ffmpeg) |
| 39 | Core Image | Thumbnail compositing, color, crops | macOS 10.4 | **consider** |
| 40 | Image Playground / `ImageCreator` | Generated images in animation, illustration or sketch styles | macOS 15.4 | **skip** |
| 41 | Core ML / Core AI / MLX / Create ML | Run second-opinion speech models; train custom sound or pose classifiers | Core AI macOS 27 | **consider** |
| 42 | CloudKit / CloudKit JS | Apple-hosted database readable from the web | macOS 10.10; CloudKit JS 2 | **skip** |
| 43 | Sign in with Apple JS, passkeys | Web login | web | passkeys **use**, Sign in with Apple **consider** |
| 44 | Final Cut Pro interop (FCPXML 1.14), Compressor CLI | Hand the edit to a human editor in FCP; batch encodes | FCP 12.4 installed | FCPXML **consider** v2; Compressor **skip** |
| 45 | Photos | Library integration | | **skip** |
| 46 | Apple Developer Program: Developer ID, notarization, push entitlement | Run the engine on any Mac other than Ivan's without Gatekeeper and TCC breakage | | **use** |

Sections 4 to 11 give the detail, limits and sources behind each row.

---

## 4. Folder watching and iCloud

### 4.1 iCloud Drive facts that shape the watcher

- Since macOS Sonoma, iCloud Drive runs on Apple's File Provider. With Optimize Mac Storage on it
  is "nonreplicated": files can be evicted to **dataless** placeholders that keep size and metadata
  but no data
  ([Eclectic Light, Sonoma changed iCloud Drive](https://eclecticlight.co/2023/10/25/macos-sonoma-has-changed-icloud-drive-radically/),
  [Explainer: File Provider, 2026-05-09](https://eclecticlight.co/2026/05/09/explainer-file-provider-and-cloud-services/)).
- Optimize Mac Storage is ON on Ivan's Mac (measured, section 2.1).
- Apple's **TN3150** is the authority: accessing a dataless file triggers "materialization", which
  can take a long time for large files, can stall the calling thread, and even enumerating a
  directory or `fileExists(atPath:)` can trigger it. Detect with `stat`/`getattrlist` and the
  `SF_DATALESS` flag in `st_flags`, or opt a thread or process out of materialization with
  `setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_THREAD or
  IOPOL_SCOPE_PROCESS, IOPOL_MATERIALIZE_DATALESS_FILES_OFF)` (constants confirmed in the macOS 27
  SDK's `usr/include/sys/resource.h`, lines 512 and 546). Do the work off the main thread
  ([TN3150](https://developer.apple.com/documentation/technotes/tn3150-getting-ready-for-data-less-files)).
- Pinning: macOS 15 added "Keep Downloaded" in Finder for files and whole folders, which shields
  them from eviction; Eclectic Light calls pinning somewhat unpredictable
  ([Eclectic Light, Sequoia pinning](https://eclecticlight.co/2024/09/30/how-icloud-has-changed-in-sequoia-pinning-and-more/),
  [Macworld](https://www.macworld.com/article/2378054/ios-18-macos-sequoia-icloud-keep-downloaded-option.html)).
  No public API for pinning was found `[unverified]`; it is a one-time manual step on the engine Mac.
- Forcing a download: `FileManager.startDownloadingUbiquitousItem(at:)` starts or refreshes the
  download; progress and state come from `URLResourceValues.ubiquitousItemDownloadingStatus` and
  `ubiquitousItemIsDownloadingKey`
  ([startDownloadingUbiquitousItem](https://developer.apple.com/documentation/foundation/filemanager/startdownloadingubiquitousitem(at:)),
  [ubiquitousItemDownloadingStatus](https://developer.apple.com/documentation/foundation/urlresourcevalues/ubiquitousitemdownloadingstatus)).
  `brctl download <path>` and `brctl evict <path>` do the same from a shell (`man brctl`, local).
- Shared folders: Apple's own documents disagree on how quickly a collaborator's new file appears
  ("real time" vs "next time you open")
  ([Mac Help](https://support.apple.com/guide/mac-help/mchl91854a7a),
  [iCloud User Guide](https://support.apple.com/en-mide/guide/icloud/mm19ef899373/icloud)). Whether a
  file still being written by OBS on the studio Mac can sync to other Macs as partial versions is
  **unknown** `[unverified]`. Because the files have their `moov` index at the end (section 2.2), a
  partial copy will not open, which makes the completeness test reliable, but the engine must not
  treat "a file appeared" as "a recording finished".

### 4.2 The watcher APIs

**FSEvents: use.** File-level events with `kFSEventStreamCreateFlagFileEvents` (macOS 10.7)
([doc](https://developer.apple.com/documentation/coreservices/kfseventstreamcreateflagfileevents)).
The decisive feature: events persist across reboots, so the engine stores the last processed event
ID and passes it as `sinceWhen` to `FSEventStreamCreate` on launch to replay everything that happened
while it was asleep or quit. Apple's caveats, all of which the engine must honor: treat history as
advisory and do a periodic full sweep; on `MustScanSubDirs`, `KernelDropped` or `UserDropped`
rescan; watch the root with `kFSEventStreamCreateFlagWatchRoot`; start monitoring before the
initial scan
([FSEvents Programming Guide](https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/FSEvents_ProgGuide/UsingtheFSEventsFramework/UsingtheFSEventsFramework.html)).

**`NSFilePresenter`: skip as a watcher.** Presenters "are not notified about changes made directly
using low-level read and write calls to the file. Only changes that go through a file coordinator
result in notifications" ([NSFilePresenter](https://developer.apple.com/documentation/foundation/nsfilepresenter)).
OBS writes through ordinary file I/O `[inferred]`.

**`NSFileCoordinator`: use for reads** of iCloud items; TN3150 says coordinated access handles
dataless files correctly
([NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator), TN3150).

**`DispatchSource.makeFileSystemObjectSource`: skip.** It watches one open file descriptor
([doc](https://developer.apple.com/documentation/dispatch/dispatchsource/makefilesystemobjectsource(filedescriptor:eventmask:queue:)));
the studio folder is a tree of dated subfolders.

**`NSMetadataQuery`: skip as primary.** Spotlight-backed queries batch at 1 s by default
([NSMetadataQuery](https://developer.apple.com/documentation/foundation/nsmetadataquery)), but dataless
files lose Spotlight search until materialized (Eclectic Light, above), and the iCloud scopes target
an app's own ubiquity container rather than an arbitrary shared iCloud Drive folder `[unverified]`.

**Shortcuts folder automation: prototype only.** macOS 26 Tahoe added a Folder automation trigger
that passes a "Folder Change Summary" (added, modified, removed) to a shortcut, with "Ignore
subfolders" and Run Immediately options
([Six Colors](https://sixcolors.com/post/2025/08/get-started-with-folder-automation-in-macos-tahoe/),
[MacMost](https://macmost.com/an-introduction-to-shortcuts-automation-in-macos-tahoe.html)). It fires on
"added", which for OBS means the moment recording starts, and no source documents its behavior with
iCloud placeholders. Useful to demo the idea in an afternoon, not to rely on.

### 4.3 The completeness rule (recommended)

A recording is ready for processing only when all of these hold, checked in order:

1. Not dataless (`SF_DATALESS` clear). If dataless, call `startDownloadingUbiquitousItem` and wait
   for `ubiquitousItemDownloadingStatus == .current`.
2. Size unchanged for a quiet period (suggest 5 minutes, configurable).
3. A top-level `moov` box exists (cheap scan of box headers, as done in this research) and AVFoundation
   loads a duration within a few seconds of what the box says.
4. Optional, if the engine runs on the OBS machine: OBS's built-in WebSocket server (OBS 28+) emits
   `RecordStateChanged` with state `OBS_WEBSOCKET_OUTPUT_STOPPED` and the saved file's `outputPath`
   ([Streamer.bot wiki](https://wiki.streamer.bot/en/Broadcasters/OBS/Events/Output-Events/RecordStateChanged),
   [OBS forum](https://obsproject.com/forum/resources/obs-websocket-websocket-api-for-obs-studio.466/updates)).
   This is the only signal that means "the human pressed Stop".

Vertical twins (`-vertical.mp4`) are paired with their horizontal sibling by timestamp, not treated
as separate recordings.

---

## 5. Running in the background on macOS

- **`SMAppService`** (macOS 13) registers login items, launch agents and launch daemons that live
  inside the app bundle; agent plists go in `Contents/Library/LaunchAgents`
  ([SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice),
  [agent(plistName:)](https://developer.apple.com/documentation/servicemanagement/smappservice/agent(plistname:))).
  Registered items appear under System Settings, General, Login Items, "Allow in the Background",
  where the user can switch them off, and macOS shows a "Background Items Added" notice
  ([Apple deployment guide](https://support.apple.com/guide/deployment/depdca572563/web)). There is no
  notification when the user toggles it; re-read `status` when the app becomes active
  ([Apple forums 784801](https://developer.apple.com/forums/thread/784801)). Coffee Cup's notes: it
  needs a real `.app` bundle, so `swift run` cannot exercise it (`~/Code/coffee-cup/START_HERE.md`).
  A launch agent runs inside Ivan's login session, which is also what iCloud Drive needs
  `[inferred]`; a launch daemon (no login) is the wrong tool.
- **App Nap and idle sleep.** Wrap each job in `ProcessInfo.beginActivity(options: [.userInitiated,
  .idleSystemSleepDisabled], reason:)`
  ([beginActivity](https://developer.apple.com/documentation/foundation/processinfo/beginactivity(options:reason:)),
  [idleSystemSleepDisabled](https://developer.apple.com/documentation/foundation/processinfo/activityoptions/idlesystemsleepdisabled)).
  Equivalent shell form, already proven in Coffee Cup: `caffeinate -i -w <pid>` so a crash can never
  leave the Mac pinned awake (`~/Code/coffee-cup/START_HERE.md`).
- **Power assertions are suggestions.** `kIOPMAssertionTypePreventSystemSleep` may be overridden in
  low power or thermal emergencies
  ([doc](https://developer.apple.com/documentation/iokit/kiopmassertiontypepreventsystemsleep));
  `caffeinate -s` "is valid only when system is running on AC power" (`man caffeinate`, local).
- **Closing a MacBook lid sleeps it.** `caffeinate` prevents idle sleep, not lid-close sleep;
  clamshell operation needs an external display (and in practice power)
  ([Macworld](https://www.macworld.com/article/673295/how-to-use-macbook-with-lid-closed-stop-closed-mac-sleeping.html),
  [openreplay](https://blog.openreplay.com/mac-awake-overnight-agent-runs-caffeinate/)). The only
  software override is the system-wide `sudo pmset -a disablesleep 1`, which is a security and
  battery trap and is not recommended. On a traveling laptop, Prakriti pauses when the lid closes and
  catches up on wake (FSEvents replay plus a sweep).
- **Sleep and wake.** `NSWorkspace.willSleepNotification` lets an observer delay sleep up to 30 s;
  use it to checkpoint the current job; use the wake notification to trigger a rescan
  ([willSleepNotification](https://developer.apple.com/documentation/appkit/nsworkspace/willsleepnotification)).
- **`NSBackgroundActivityScheduler`** suits deferrable work at intervals of 10 minutes or more
  (nightly archive batches, R2 cleanup), letting the system pick an energy-efficient moment
  ([doc](https://developer.apple.com/documentation/foundation/nsbackgroundactivityscheduler)).
- **Privacy permissions (TCC).** The studio folder is inside `~/Documents`, which is protected; a
  background process without a grant gets permission errors, not a prompt, in some cases
  ([StepSecurity](https://docs.stepsecurity.io/developer-machines/installation/script/mdm-deployment/macos)).
  Grants are tied to the code signature: an ad-hoc signed build gets a new identity on every rebuild
  and silently loses the grant while System Settings still shows it ticked
  ([OpenClaw signing notes](https://docs.openclaw.ai/platforms/mac/signing),
  [MacPorts thread](https://lists.macports.org/pipermail/macports-dev/2021-April/043246.html)).
  **The engine must be signed with a stable certificate from day one** (Ivan's Apple Development
  certificate is enough on his own Mac). Hark is ad-hoc signed today (`codesign -dvv
  ~/Applications/Hark.app` reports `Signature=adhoc`), so copying its build approach unchanged would
  reintroduce this bug.

---

## 6. Notifications

### 6.1 Local notifications on the engine Mac (UserNotifications)

- Local and remote notifications, categories, actions and delivered-notification management
  ([UserNotifications](https://developer.apple.com/documentation/usernotifications)). Requires an app
  bundle with a bundle identifier `[inferred; the framework is per-app]`.
- **Categories and actions**: up to 10 actions with unlimited space, 2 when space is limited
  ([UNNotificationCategory](https://developer.apple.com/documentation/usernotifications/unnotificationcategory));
  HIG says a detail view shows up to four buttons, use short title-case labels, prefer nondestructive
  actions ([HIG Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications)).
- **`threadIdentifier`** groups related notifications visually; give every recording its own thread
  so "detected, started, complete" stack as one conversation
  ([threadIdentifier](https://developer.apple.com/documentation/usernotifications/unmutablenotificationcontent/threadidentifier)).
- **Interruption levels** (macOS 12): passive, active, time sensitive, critical. Time sensitive
  breaks through Focus and scheduled summaries and needs the time-sensitive capability; critical
  needs a special Apple entitlement
  ([UNNotificationInterruptionLevel](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel),
  [timeSensitive](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel/timesensitive),
  [defaultCritical](https://developer.apple.com/documentation/usernotifications/unnotificationsound/defaultcritical)).
  HIG: use Time Sensitive "only for notifications that are relevant in the moment", about something
  happening now or within an hour
  ([HIG Managing notifications](https://developer.apple.com/design/human-interface-guidelines/managing-notifications)).
- **Provisional authorization** delivers quietly to Notification Center without a permission prompt
  ([provisional](https://developer.apple.com/documentation/usernotifications/unauthorizationoptions/provisional)).
  Not needed on a Mac Ivan sets up himself.
- **Attachments**: images up to 10 MB, audio up to 5 MB
  ([UNNotificationAttachment](https://developer.apple.com/documentation/usernotifications/unnotificationattachment)).
  The "complete" notification can carry the top thumbnail candidate.
- **`relevanceScore`** (0 to 1) picks the featured item in a notification summary
  ([doc](https://developer.apple.com/documentation/usernotifications/unmutablenotificationcontent/relevancescore)).

### 6.2 Getting notifications to Gabriel's and Serenity's Macs and iPhones

**Web Push from the web app: use.** Apple's guidance: web push works for "Home Screen web apps in
iOS 16.4 or later and Webpages in Safari 16 for macOS 13 or later", follows cross-browser standards,
needs a user gesture to subscribe, and "You don't need to join the Apple Developer Program to send
web push notifications"
([Apple: Sending web push notifications](https://developer.apple.com/documentation/usernotifications/sending-web-push-notifications-in-web-apps-and-browsers)).
Mac web apps added to the Dock (Safari 17, macOS Sonoma) support push and badging
([WWDC23 What's new in web apps](https://developer.apple.com/videos/play/wwdc2023/10120/)).
**Declarative Web Push** (no service worker required; JSON payload with `"web_push": 8030`, a
required `title` and `navigate` URL, optional `app_badge`) shipped in iOS/iPadOS 18.4 and Safari 18.5
on macOS 15.5 ([WebKit blog](https://webkit.org/blog/16535/meet-declarative-web-push/),
[MacTech](https://www.mactech.com/2025/05/12/with-safari-18-5-included-in-macos-15-5-apple-added-declarative-web-push/amp/)).
One report says Safari 18.5 crashed on a payload with `app_badge`; test before using it
([Modern Web Weekly 54](https://modernwebweekly.substack.com/p/modern-web-weekly-54)).

The result: Gabriel and Serenity install nothing. They open `prakriti.therowan.studio` in Safari,
choose File, Add to Dock (Mac) and Share, Add to Home Screen (iPhone), tap "Allow notifications"
once, and Prakriti's notifications arrive as ordinary macOS and iOS notifications from the
"Prakriti" web app. The Worker sends them; the engine only tells the Worker what happened.

**Native APNs: skip for v1.** A Developer ID Mac app can use Push Notifications and Time Sensitive
Notifications (Apple's macOS capability table marks both supported for Developer ID; Sign in with
Apple is not) ([Supported capabilities, macOS](https://developer.apple.com/help/account/reference/supported-capabilities-macos)).
But that means a native app on every person's Mac and an iPhone app for phones, which is the
maintenance load the hybrid avoids.

**Email (Resend)** stays as the fallback and the daily digest channel, since push permission can be
revoked silently by the user.

### 6.3 The three notifications Ivan asked for, designed to the HIG

HIG rules applied: concise, no instructions to "go do X", do not repeat the app name, accurate
urgency, nondestructive actions (HIG pages above). Publishing is outward-facing and stays behind a
review screen (standing safety rule in `BRIEF.md`; `content-engine/PLAN.md` rule 3), so no
notification button publishes anything.

| Event | Example text | Level | Actions | Who |
|---|---|---|---|---|
| New raw material detected | "New studio recording: Sun 20 Sep, 55 min" | active | Open, Hold | all three (configurable) |
| Processing started | "Working on Sun 20 Sep. About 10 minutes." | passive by default | Open | Ivan; others opt in |
| Processing complete | "Sun 20 Sep is ready to review: podcast, video, 3 thumbnails" (top thumbnail attached) | active | Review | all three |
| Needs a decision (extra) | "Students speak in this one. Held for review." | active | Review | Serenity + Ivan |
| Failed (extra) | "Couldn't finish Sun 20 Sep: audio track missing" | active | Details | Ivan |

Same `threadIdentifier` locally and the same notification `tag` on the web for each recording, so
the three stages read as one story instead of three interruptions. Nothing here qualifies as Time
Sensitive. Weekday labels must be computed, not recalled (working memory: "Compute weekdays, never
recall them").

---

## 7. Speech, audio and language intelligence

### 7.1 Apple Speech (`SpeechAnalyzer`, macOS 26+)

- Modules: `SpeechTranscriber` (general conversation, long-form), `DictationTranscriber` (system
  dictation models, custom vocabulary), `SpeechDetector` (voice activity), with `AssetInventory`
  managing model downloads
  ([Speech](https://developer.apple.com/documentation/speech),
  [SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber),
  [DictationTranscriber](https://developer.apple.com/documentation/speech/dictationtranscriber),
  [SpeechDetector](https://developer.apple.com/documentation/speech/speechdetector)). Apple pitched it
  for long-form and distant audio such as lectures and meetings
  ([WWDC25 session 277](https://developer.apple.com/videos/play/wwdc2025/277/)).
- **macOS 27 additions found in the SDK** (`Speech.swiftmodule/arm64e-apple-macos.swiftinterface`,
  marked `@available(anyAppleOS 27, *)`): `AssetInputSequenceProvider.provider(from: AVAsset,
  track:, compatibleWith:)` feeds a video file's audio track straight in (no extraction step, and a
  specific track can be chosen); `CaptureInputSequenceProvider`; `AnalyzerInputConverter`;
  `SpeechAnalyzer.Options(... ignoresResourceLimits:)`. Exact semantics of `ignoresResourceLimits`
  are undocumented `[unverified]`.
- **Languages (measured on this Mac):** `SpeechTranscriber.supportedLocales` returns 45 locales,
  including `es-US`, `es-MX`, `es-ES`, `es-CL`, `pt-BR`, `hi-IN` and other Indian languages;
  installed today are only English variants. `DictationTranscriber` supports 54. Spanish assets would
  download on first use through `AssetInventory`.
- **No automatic language detection.** A transcriber is created with a locale. Route by running
  `NLLanguageRecognizer` on a short first pass (section 7.6). Code-switched speech is a known weak
  spot for single-locale engines, and the transcription skill notes Whisper with `language=en`
  silently translates Spanish into English (`~/.claude/skills/transcribe-audio/SKILL.md`).
- **Custom vocabulary**: only `DictationTranscriber` honors `AnalysisContext.contextualStrings`
  (keep phrases to one or two words, at most 100 total) and custom language models
  ([contextualStrings](https://developer.apple.com/documentation/speech/analysiscontext/contextualstrings)).
  `SpeechTranscriber` has none (also stated by
  [Argmax](https://www.argmaxinc.com/blog/apple-and-argmax)). Sanskrit and yoga vocabulary
  ("pranayama", "Patanjali", "Yoga Marga") will need a correction pass: Claude with a glossary is the
  practical fix. Vocabulary accuracy was not evaluated in this research.
- **Accuracy evidence**: on long-form English earnings calls (earnings22 subset, about 12 h),
  SpeechTranscriber scored 14.0% WER vs whisper-base.en 15.2%, whisper-small.en 12.8%, Parakeet v2
  11.7%, at 70x real time on an M4 Mac mini running a macOS 26 beta
  ([Argmax, 2025-06-20](https://www.argmaxinc.com/blog/apple-and-argmax)). On LibriSpeech, a vendor
  test reported 2.12% (clean) and 4.56% (other) vs Whisper Small 3.74% and 7.95%
  ([Gigazine summary, 2026-07-14](https://www.gigazine.net/gsc_news/en/20260714-apple-speech-analyzer-benchmark/)).
  No published comparison against Whisper large-v3 was found. Reading: fast and good enough for
  search, chapters and editing; not the last word for a published, quotable transcript.
- **`SpeechDetector`: keep off.** Apple itself warns VAD can drop speech
  ([SpeechDetector](https://developer.apple.com/documentation/speech/speechdetector)), and a VAD gate
  dropped 80% of a tape without error on a past job (`~/.claude/skills/transcribe-audio/SKILL.md`,
  working memory "Verify filter stages by coverage"). Always run a coverage check: last word time vs
  file duration.
- **Speed**: about 97x real time measured (section 2.3).

### 7.2 Diarization: Apple has none

- The macOS 27.0 SDK's Speech interface contains zero symbols matching "diariz" or "speaker"
  (`grep -ciE "diariz|speaker"` returns 0 on the swiftinterface). Hark's docs say the same for
  macOS 26 (`~/Code/transcribe-app/START_HERE.md`). A developer asked on Apple's forums whether
  diarization is coming in 27 and got no answer
  ([forum 829751](https://developer.apple.com/forums/thread/829751)).
- **FluidAudio** (Apache 2.0, used by Hark at `from: 0.12.4`) provides offline diarization
  (Pyannote Community-1 segmentation, WeSpeaker embeddings, VBx clustering), speaker embeddings with
  **pre-enrollment of known speakers**, Silero VAD, Parakeet ASR (Parakeet TDT v3 covers 25 European
  languages, reported about 190x real time on an M4 Pro), and beta speech enhancement
  ([FluidAudio README](https://github.com/FluidInference/FluidAudio)).
- **Enrollment is the important part for Prakriti.** Enroll Gabriel's and Serenity's voices once
  from clean studio talks; every later recording gets segments labeled "Gabriel", "Serenity" or
  "Other voice". That one capability feeds four features: the speaker-tagged Markdown transcript, the
  per-person knowledge base, speaker-only audio for ElevenLabs training, and Serenity's privacy rule
  (any "Other voice" segment is held out of public outputs by default).
- Limits: the transcription skill found pyannote-class diarization unreliable on poor, band-limited
  audio with similar voices (`~/.claude/skills/transcribe-audio/SKILL.md`). Studio audio is
  wideband, but the files are a single mixed mic track (section 2.2). On a 10-minute class excerpt
  the pipeline returned 2 speakers; whether that was right was not checked. **Treat diarization as a
  suggestion that fails closed**: anything unsure is "Other voice".
- The cheaper, more reliable path is hardware: if the studio has (or adds) one mic per person, OBS
  can record each to its own audio track, and macOS 27's `AssetInputSequenceProvider(...track:)`
  transcribes each track separately. Then "who spoke when" is a fact, not a model's guess
  `[recommendation; studio mic setup unknown]`.

### 7.3 SoundAnalysis (use)

- Built-in classifier with over 300 sounds; `SNAudioFileAnalyzer` for files
  ([SoundAnalysis](https://developer.apple.com/documentation/soundanalysis),
  [Classifying sounds in a file](https://developer.apple.com/documentation/soundanalysis/classifying-sounds-in-an-audio-file),
  [version1](https://developer.apple.com/documentation/soundanalysis/snclassifieridentifier/version1)).
- **Measured**: 303 labels on this Mac, including `speech`, `music`, `singing`, `silence`,
  `singing_bowl`, `gong`, `bell`, `breathing`, `whispering`, `laughter`, `applause`, `clapping`,
  `cough`, `sneeze`, `ringtone`, `telephone`, `dog_bark`, `chatter`, `crowd`, `tabla`, `sitar`,
  `flute`. A full 55-minute talk classified in 4.6 s: 1,005 of 1,101 three-second windows were speech,
  32 were music.
- Uses for Prakriti: a timeline map for the editor (talk vs practice vs music vs silence); singing
  bowl, gong and bell as natural chapter boundaries in classes; laughter and applause as "moment"
  signals for shorts; ringtone, cough and dog as audio-quality deductions; music windows handed to
  ShazamKit. Custom sounds can be trained with Create ML's `MLSoundClassifier` (same doc).

### 7.4 ShazamKit (use)

- Matches audio against the Shazam catalog or a custom catalog; signatures are one-way
  ([ShazamKit](https://developer.apple.com/documentation/shazamkit)).
  `SHSignatureGenerator.signature(from: AVAsset)` (macOS 13) builds a signature from any asset with
  audio ([doc](https://developer.apple.com/documentation/shazamkit/shsignaturegenerator/generatesignature(from:completionhandler:))).
- **Measured**: the Shazam catalog accepts query signatures between 3.0 and 12.0 seconds
  (`SHSession().catalog.minimumQuerySignatureDuration` / `maximum...`). Longer audio returns
  `signatureDurationInvalid` ([doc](https://developer.apple.com/documentation/shazamkit/sherror/code/signaturedurationinvalid)),
  so the engine slices SoundAnalysis "music" regions into 12-second windows.
- Requires an App ID with the ShazamKit App Service enabled in the developer account
  ([ShazamKit service](https://developer.apple.com/help/account/services/shazamkit)). Matching
  copyrighted music before upload is a direct defense against YouTube Content ID claims on yoga
  classes that play background music `[inferred]`. A match is a warning in the review screen, not an
  automatic cut.

### 7.5 Foundation Models (consider, minor role) vs Claude

- **On-device model**: measured `SystemLanguageModel.default.contextSize = 8192` tokens on this
  Mac, input and output combined ([contextSize](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/contextsize)).
  Supported languages include English and Spanish (measured). Guided generation (`@Generable`), tool
  calling, and in macOS 27 image input, a Spotlight search tool for local retrieval, OCR and barcode
  tools, Dynamic Profiles, an `fm` CLI and a Python SDK
  ([Foundation Models](https://developer.apple.com/documentation/foundationmodels),
  [WWDC26 session 241](https://developer.apple.com/videos/play/wwdc2026/241/)). Apple also says
  Anthropic is publishing a Swift package so Claude can sit behind the same `LanguageModelSession`
  API (WWDC26 241).
- **Why it cannot do the editorial work**: a 10-minute studio excerpt produced 1,339 words, so a
  55-minute talk is about 7,400 words (measured, extrapolated), roughly 10,000 tokens `[unverified
  tokens-per-word ratio]`. That exceeds 8,192 before any output. Titles, chapters, quotes and quality
  scoring need the whole talk in view.
- **Private Cloud Compute model**: 32,000-token context, reasoning levels, no API cost
  (WWDC26 241), but only for developers in the App Store Small Business Program with a managed
  entitlement, for App Store distribution (TestFlight and ad hoc for testing)
  ([Accessing Private Cloud Compute](https://developer.apple.com/private-cloud-compute),
  [PrivateCloudComputeLanguageModel](https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel)).
  For Developer ID apps an Apple staff member wrote "I think the answer is no"
  ([forum 842810](https://developer.apple.com/forums/thread/842810)). **Skip.** Do not use the `fm`
  CLI as a backdoor either: its legal notice restricts programmatic use
  ([Daring Fireball on TwoMillionKit](https://daringfireball.net/linked/2026/07/12/twomillionkit)), and
  it needs `sudo fm license` (measured).
- **Claude** (current API reference cached 2026-10-06 in the `claude-api` skill): Opus 5.5 $4 / $20
  per million input / output tokens, Sonnet 5.5 $2 / $10, Haiku 5.5 $0.10 / $0.50, all with 1M-token
  context; the Batch API halves cost for non-urgent work. Closer measured about 19,000 tokens and
  about $0.20 for a 62-minute call (`Gabriel Galindo/content-engine/PLAN.md`); Ivan's working memory
  records measured per-call costs of about $0.13 (Sonnet) and $0.83 (Opus)
  (`memory/model-choice-is-the-cost-lever.md`). The 900-recording archive is a two- or three-figure
  dollar job for the writing step, not a budget problem.
- **Verdict**: Claude writes titles, descriptions, chapters, quotes, show notes and the "message"
  quality score. On-device Foundation Models is optional for tiny private tasks (file naming, a
  one-line "what kind of session is this" label) and must handle the "model unavailable or
  rate-limited in background" case (WWDC26 241 Q&A notes background calls can be rate-limited).

### 7.6 NaturalLanguage and Translation

- `NLLanguageRecognizer` gives the dominant language or ranked hypotheses; reliable on longer text
  ([doc](https://developer.apple.com/documentation/naturallanguage/nllanguagerecognizer)). **Use** to
  choose `en-US` vs `es-US` before full transcription.
- `NLContextualEmbedding` (macOS 14): measured 512 dimensions with assets present for both English
  and Spanish ([doc](https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding)).
  **Skip for the library search**: search runs in the web app, the Worker cannot compute Apple
  embeddings for a query, and mixing models breaks vector search `[inferred]`. Use one server-side
  embedding model for both documents and queries (another track).
- **Translation** (macOS 14.4): on-device; a headless `TranslationSession(installedSource:target:)`
  exists from macOS 26.4 but throws `notInstalled` until the language pack is downloaded, which only a
  UI-hosted session can trigger
  ([Translation](https://developer.apple.com/documentation/translation),
  [TranslationSession](https://developer.apple.com/documentation/translation/translationsession),
  `~/Code/transcribe-app/START_HERE.md`). iOS 27 adds languages including US and Mexican Spanish in the
  Translate app ([Cult of Mac](https://www.cultofmac.com/news/apple-translate-ios-27-9-new-language-support)).
  **Consider later** for Spanish captions; Claude likely handles dharma vocabulary better
  `[unverified]`.

### 7.7 Audio cleanup (use, carefully)

- `kAudioUnitSubType_AUSoundIsolation` ('vois', macOS 13) isolates voice;
  `kAUSoundIsolationSoundType_HighQualityVoice` arrived in macOS 15; parameters are wet/dry mix and
  sound type (`AUComponent.h`, `AudioUnitParameters.h` in the macOS 27 SDK). Run it offline through
  `AVAudioEngine` manual rendering
  ([enableManualRenderingMode](https://developer.apple.com/documentation/avfaudio/avaudioengine/enablemanualrenderingmode(_:format:maximumframecount:))).
- Use it for the podcast master and for voice-model training clips, **never before transcription**:
  the transcription skill found denoising before ASR lowers accuracy
  (`~/.claude/skills/transcribe-audio/SKILL.md`). Keep a wet/dry mix below 100% for natural sound
  `[recommendation]`.
- Loudness: AVFoundation has no LUFS meter `[unverified]`; ffmpeg `loudnorm` (two-pass) is proven and
  measured at 72 s per hour of audio. Target -16 LKFS plus or minus 1, true peak -1 dBFS, measured
  per ITU-R BS.1770-5 (Apple Podcasts page above).

---

## 8. Vision and imaging

- **Thumbnails, done the Apple way.** Apple's sample "Generating high-quality thumbnails from videos"
  runs `VideoProcessor` over about 100 sampled frames with `CalculateImageAestheticsScoresRequest`,
  rejects near-duplicates with `GenerateImageFeaturePrintRequest`, and grabs the winning frames with
  AVFoundation: exactly the "three thumbnail options for A/B tests" feature
  ([sample](https://developer.apple.com/documentation/vision/generating-thumbnails-from-videos),
  [VideoProcessor](https://developer.apple.com/documentation/vision/videoprocessor),
  [aesthetics request](https://developer.apple.com/documentation/vision/calculateimageaestheticsscoresrequest)).
  The aesthetics observation also flags "utility" images (screenshots, documents). Measured: 61 frames
  of 1080p scored for aesthetics and face quality in 2.9 s; scores ranged 0.60 to 0.74 on the excerpt.
- **Faces**: `DetectFaceCaptureQualityRequest` scores 0 to 1 for "better lit, sharper, and more
  centrally positioned" faces
  ([doc](https://developer.apple.com/documentation/vision/detectfacecapturequalityrequest)). Prefer
  frames where the teacher's face quality is high and eyes are open `[eyes-open check not verified]`.
- **Crops**: `GenerateAttentionBasedSaliencyImageRequest` heat maps and objectness saliency drive
  automatic 16:9, 1:1 and 9:16 crops for YouTube, podcast art and shorts
  ([doc](https://developer.apple.com/documentation/vision/generateattentionbasedsaliencyimagerequest)).
- **Subjects**: `GeneratePersonInstanceMaskRequest` returns a mask per person
  ([doc](https://developer.apple.com/documentation/vision/generatepersoninstancemaskrequest)): the
  teacher cut-out over a brand background is a classic thumbnail treatment.
- **Yoga-specific (consider)**: `DetectHumanBodyPoseRequest` and `DetectHumanBodyPose3DRequest`
  ([2D](https://developer.apple.com/documentation/vision/detecthumanbodyposerequest),
  [3D](https://developer.apple.com/documentation/vision/detecthumanbodypose3drequest)). Uses: split a
  class into "talking" vs "in practice" segments, pick thumbnails where the pose is complete and
  centered, and later train a Create ML action classifier to name poses for chapters ("Dragon",
  "Sphinx"). Pose names would need a labeled set; not v1.
- **Student privacy in video (consider, fail closed)**: Vision detects faces and people, but there is
  no face identity API in Vision `[inferred from the topic list]`, so it can blur "every face that is
  not where the teacher sits" only by position rules, not by recognizing who is who. Classes stay
  gated on Serenity's answer, per the brief.
- **Other**: `DetectLensSmudgeRequest` (macOS 26) flags hazy captures, useful for the video quality
  score ([doc](https://developer.apple.com/documentation/vision/detectlenssmudgerequest));
  `RecognizeTextRequest` reads on-screen text ([doc](https://developer.apple.com/documentation/vision/recognizetextrequest));
  `GenerateIterativeSegmentationRequest` (macOS 27) segments from taps or boxes
  ([doc](https://developer.apple.com/documentation/vision/generateiterativesegmentationrequest)).
- **Core Image**: compositing, color and crops for thumbnails `[general; consider]`. Thumbnail layout
  with type could equally be rendered as HTML in the web stack; another track decides.
- **Image Playground / `ImageCreator`: skip.** Styles are animation, illustration and sketch (plus an
  external provider) ([ImagePlaygroundStyle](https://developer.apple.com/documentation/imageplayground/imageplaygroundstyle),
  [ImageCreator](https://developer.apple.com/documentation/imageplayground/imagecreator)); no
  photographic style suits real-teacher thumbnails. The earlier plan chose Midjourney prompts for
  generated art (`content-engine/PLAN.md`).

---

## 9. Media pipeline: AVFoundation, VideoToolbox, ffmpeg

- `AVAssetReader` / `AVAssetWriter` read and write media and can re-encode
  ([reader](https://developer.apple.com/documentation/avfoundation/avassetreader),
  [writer](https://developer.apple.com/documentation/avfoundation/avassetwriter)).
- `AVMutableComposition` builds a new timeline from time ranges of existing assets: the cut list for
  the edited video and the podcast (intro, body, mid-roll, outro)
  ([doc](https://developer.apple.com/documentation/avfoundation/avmutablecomposition)); export with
  `AVAssetExportSession.export(to:as:)`
  ([doc](https://developer.apple.com/documentation/avfoundation/avassetexportsession/export(to:as:isolation:))).
- `AVAssetImageGenerator` grabs exact frames for thumbnails
  ([doc](https://developer.apple.com/documentation/avfoundation/avassetimagegenerator)).
- VideoToolbox is the low-level hardware codec layer; apps that do not need direct access should go
  through AVFoundation ([VideoToolbox](https://developer.apple.com/documentation/videotoolbox)).
- **Known trap from Hark**: AVFoundation decode fails with a bare `_GenericObjCError` inside an
  Automator "Run Shell Script" sandbox; launch through LaunchServices (`open -g -a`) instead
  (`~/Code/transcribe-app/START_HERE.md`). The engine should never be invoked from Automator.
- **ffmpeg stays in the toolbox** for loudness, encodes and anything AVFoundation makes awkward.
  It is a Homebrew dependency on the engine Mac, which is one more thing to keep installed
  `[maintenance note]`.
- Encode timings and the M5 Pro media-engine count are in section 2.3.

---

## 10. Surfaces on the Mac: menu bar, widgets, intents

- **`MenuBarExtra`** (macOS 13): a scene that lives in the menu bar; `LSUIElement` hides the Dock
  icon ([MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)). HIG: "Display
  a menu, not a popover" unless the content is too complex; let people decide whether it shows; do
  not rely on its presence, since the system hides extras when crowded
  ([HIG The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar)).
  Suggested menu: status line ("Watching Studio Recordings", "Working on Sun 20 Sep, 40%"), Open
  Prakriti (web), Pause Watching, Process a File..., Settings, Quit. Hark already ships a
  `MenuBarExtra` with a runtime Dock toggle (`~/Code/transcribe-app/CHANGELOG.md`).
- **WidgetKit desktop widget and `ControlWidget`** (`ControlWidget` is `@available(iOS 18.0,
  macOS 26.0, ...)` in the SDK). Both are app extensions, and Hark's notes say extensions cannot be
  expressed in SwiftPM, so they force a real Xcode project (`~/Code/transcribe-app/CHANGELOG.md`).
  **Consider later**; the menu bar covers the need.
- **Live Activities: skip.** ActivityKit says Live Activities appear "On Mac, in the Menu bar"
  ([ActivityKit](https://developer.apple.com/documentation/activitykit)), but `Activity` is marked
  `@available(macOS, unavailable)` throughout the macOS 27 SDK interface: a Mac app cannot start one;
  the Mac only shows iPhone-started ones.
- **App Intents** (macOS 13) expose actions and entities to Siri, Spotlight and Shortcuts
  ([App Intents](https://developer.apple.com/documentation/appintents)); `IndexedEntity` (macOS 15)
  puts entities into Spotlight ([doc](https://developer.apple.com/documentation/appintents/indexedentity));
  Core Spotlight indexes stay on device and do not sync
  ([Core Spotlight](https://developer.apple.com/documentation/corespotlight)). **Consider v2**:
  "Process with Prakriti" in Finder and Shortcuts, and Spotlight search of transcripts on the engine
  Mac. They do not help Gabriel and Serenity, who live in the web app.

---

## 11. ML runtimes, pro apps, cloud and identity

- **Core AI** (new in macOS 27, successor to Core ML) runs models across CPU, GPU and Neural Engine,
  with `.aimodel` conversion tools and an Evaluations framework
  ([Core AI](https://developer.apple.com/documentation/coreai),
  [InfoQ](https://infoq.com/news/2026/06/apple-core-ai-wwdc)). Its model catalog reportedly includes
  Whisper large-v3-turbo but no diarization model
  ([DeepWiki summary of apple/coreai-models](https://deepwiki.com/apple/coreai-models/2-model-catalog), `[unverified]`).
  **Consider** for a second transcription engine. MLX and `parakeet-mlx` are already installed in
  `~/Code/transcribe-3/.venv` and used by the transcription skill.
- **Create ML** trains sound, image, text and action classifiers on the Mac
  ([Create ML](https://developer.apple.com/documentation/createml)). **Consider** for custom cues
  (Yoga Marga's bell, a recurring intro) and pose classification.
- **Final Cut Pro**: version 12.4 is installed with DTDs up to `FCPXMLv1_14.dtd` (inside the app
  bundle); its AppleScript dictionary only exposes `get` on library, event, project, sequence
  (`ProEditor.sdef`), so automation means FCPXML files, not scripting. FCP 12.0 (January 2026) added
  Transcript Search, Visual Search and Beat Detection
  ([Newsshooter](https://www.newsshooter.com/2026/01/28/final-cut-pro-12-0/),
  [Apple release notes](https://support.apple.com/en-uz/102825)). FCPXML describes media, timelines,
  markers, keywords and metadata
  ([FCPXML Reference](https://developer.apple.com/documentation/professional-video-applications/fcpxml-reference)).
  **Consider v2**: export every Prakriti edit as FCPXML with chapter markers so a human editor can
  open it and polish rather than start over. **Compressor** has a CLI (`Compressor -batchname -jobpath
  -settingpath -locationpath`, from its `-help`) but adds nothing ffmpeg and AVFoundation do not:
  **skip**.
- **CloudKit / CloudKit JS: skip.** CloudKit JS (version 2, hosted at `cdn.apple-CloudKit.com/ck/2/`)
  requires an existing CloudKit app container
  ([CloudKit JS](https://developer.apple.com/documentation/cloudkitjs)). It cannot read an iCloud Drive
  shared folder, and Cloudflare D1/R2 already serve the web app.
- **Sign-in**: Up Next already ships Google sign-in plus passkeys on this stack
  (`~/Code/up-next/START_HERE.md`). Passkeys sync through iCloud Keychain for Apple users
  `[general]`. Sign in with Apple JS works for websites but needs a developer-account setup
  ([Sign in with Apple JS](https://developer.apple.com/documentation/signinwithapplejs)). **Use
  passkeys plus an email link; Sign in with Apple optional.** Another track owns the login design.
- **Photos, ScreenCaptureKit, MusicKit, Background Assets: skip** (no Prakriti job for them).

---

## 12. Distribution, signing and maintenance

### 12.1 Facts

- Ivan is in the paid Apple Developer Program, team `K55TBYNKUC`
  (`~/Code/coffee-cup/CHANGELOG.md`, `START_HERE.md`).
- Only an **Apple Development** certificate exists on this Mac; no **Developer ID Application**
  certificate yet (`security find-identity`, measured). Coffee Cup's PLAN still lists "Create the
  Developer ID Application certificate (Ivan, in Xcode)" as open (`~/Code/coffee-cup/PLAN.md`).
- **Stale truth found**: Coffee Cup's README says "The app is signed and notarized with Apple, so it
  opens without any warnings" (`~/Code/coffee-cup/README.md`), but the installed app is signed with the
  Apple Development certificate and Gatekeeper rejects it (`spctl -a -vv "/Applications/Coffee
  Cup.app"`: `rejected`), and `gh release list -R mrivanlizarde/coffee-cup` returned no releases.
  Hark is ad-hoc signed (`Signature=adhoc`).
- Notarization is an automated malware and signing check (not App Review) for Developer ID software,
  submitted with `notarytool` ([Apple](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)).
- Since macOS Sequoia, Control-click no longer bypasses Gatekeeper; users must go to System Settings,
  Privacy & Security, Open Anyway, and macOS 15.1 reports showed even that failing for some unsigned
  apps ([Cult of Mac](https://www.cultofmac.com/864843/macos-sequoia-removes-handy-shortcut-bypass-gatekeeper-security/),
  [OSnews](https://www.osnews.com/story/141055/bug-or-intentional-macos-15-1-completely-removes-ability-to-launch-unsigned-applications/)).
- Coffee Cup's notes: notarization of builds made on a beta macOS occasionally fails on Apple's side
  (`~/Code/coffee-cup/START_HERE.md`). This Mac runs a 27.2 beta build `[inferred]`.
- Hark's notes: the toolchain here defaults to a future macOS deployment target; any `swiftc` call
  must pin `-target` or the binary refuses to run on other Macs (`~/Code/transcribe-app/START_HERE.md`).

### 12.2 What this means for Prakriti

- On Ivan's Mac only: Apple Development signing is enough and keeps TCC grants stable. Do not ship
  an ad-hoc build of the engine.
- On any second Mac (a studio Mac mini, Gabriel's M2): create the Developer ID certificate, sign,
  notarize, staple. Push and time-sensitive capabilities are available to Developer ID apps if ever
  needed (capability table, section 6.2).
- macOS version floor: `SpeechAnalyzer` needs macOS 26; the asset-input provider used for
  track-specific transcription and the PCC model need macOS 27. Pin the deployment target to the
  lowest OS the engine Mac will run and gate 27-only features with availability checks.

### 12.3 Who maintains it

Ivan is a non-engineer and Sonny writes the code. That argues for:

1. **A thin engine.** It watches, materializes, runs the pipeline steps, uploads results, and reports
   state. No review UI, no library, no settings screens beyond the menu. Everything a person looks at
   lives in the web app, which the existing Cloudflare stack and its smoke/screenshot scripts already
   know how to verify.
2. **Pipeline steps as separate command-line tools** (a Swift CLI for the Apple frameworks, ffmpeg
   for audio/video), orchestrated by the engine and each runnable by hand on one file. That is how
   Hark proved its core (`diarize-proto`) and it is how a failure gets reproduced without the app.
3. **SwiftPM plus a Makefile**, the Coffee Cup and Hark pattern (`~/Code/coffee-cup/START_HERE.md`),
   with a real `.app` bundle assembled for notifications, `SMAppService` and stable TCC identity.
4. **The engine never decides to publish.** It uploads to YouTube or the podcast host only after a
   human approval recorded by the web app.

### 12.4 Engine host options

| Host | Pros | Cons | When |
|---|---|---|---|
| Ivan's MacBook Pro (M5 Pro, 64 GB) | Exists; fastest; already has the shared folder, ffmpeg, Hark, FluidAudio models | Travels; sleeps with the lid closed; Optimize Storage evicts files; processing stops while he is away | v1, now |
| Always-on Mac at the studio | 72-hour promise holds while Ivan travels; can sit next to OBS; wired network | New hardware cost; someone owns updates and power cuts | when v1 is proven |
| The OBS Mac itself, if it is always on | No iCloud wait; OBS WebSocket "recording stopped" signal; no extra hardware | Specs and OS unknown; heavy jobs could compete with a live recording unless paused while OBS records `[inferred]` | if specs allow |
| Gabriel's M2 Mac | Exists | He travels too `[unverified]`; owner is not the maintainer; RAM unknown | not recommended |

Mac mini prices (Macworld review, 2026-09-22): M6 base $899 with 16 GB and 256 GB; +$600 for 32 GB
and 512 GB (so about $1,499); M5 Pro base $1,699 with 24 GB and 512 GB
([Macworld](https://www.macworld.com/article/3239233/mac-mini-m5-pro-review-killer-performance-at-a-lethal-price.html)).
Apple's spec page lists the same media-engine feature set for both chips
([Mac mini specs](https://images.apple.com/mac-mini/specs/)). Storage for the archive should be an
external SSD, not iCloud: the archive in 1080p is on the order of 1 TB or more `[unverified estimate:
900 recordings at about 1 to 2 GB per hour]`, while audio-only extracts are about 64 MB per hour
(measured: 55-minute AAC extract was 66.7 MB). Whose money buys it is a decision for Ivan and
Gabriel, not a technical one (working memory: "Name the money question in the moment").

---

## 13. Architecture recommendation (detail)

### 13.1 Shape

```
[OBS Mac at studio] --writes .mp4--> [iCloud shared folder "Studio Recordings "]
                                              |
                                   (iCloud sync, may arrive as dataless)
                                              v
[ENGINE: native Mac agent on one Mac]  FSEvents watch -> completeness rule -> materialize
   menu bar + launch agent              -> pipeline CLIs (Speech, FluidAudio, SoundAnalysis,
   local UserNotifications                 ShazamKit, Vision, AVFoundation/ffmpeg, Claude API)
                                        -> uploads derived files to R2 (multipart, presigned)
                                        -> posts job events to the Worker (HTTPS, signed token)
                                        -> after human approval: uploads to YouTube / podcast host
                                              |
                                              v
[WEB: prakriti.therowan.studio on Cloudflare]  Worker + D1 (jobs, people, approvals)
   features page = login page                  + R2 (podcast audio, proxies, thumbnails, transcripts)
   review / library / approvals                + Web Push to all three people's Macs and iPhones
   drag-and-drop upload (direct to R2)         + Resend email fallback and digest
```

### 13.2 How each constraint is answered

| Constraint | Answer | Evidence |
|---|---|---|
| Watch folders autonomously | FSEvents in the engine, with persisted event IDs and a periodic sweep | section 4 |
| Browser cannot watch | Correct: Safari has no File System Access API; `FileSystemObserver` is Chrome-only and tab-bound | section 0 |
| macOS notifications at three stages | Local `UserNotifications` on the engine Mac; Web Push to everyone else's Mac (Dock web app) and iPhone (Home Screen web app) | section 6 |
| Compute cost | Local on Apple Silicon, about 3 to 10 min of machine time per hour of footage, zero per-minute fees; Claude for writing at cents per recording | sections 2.3, 7.5 |
| The laptop travels | v1 pauses and catches up on wake; v2 moves the engine to an always-on Mac with no code change | sections 5, 12.4 |
| iCloud shared folder sync | Dataless-aware: detect `SF_DATALESS`, request download, wait for `.current`, pin the folder | section 4.1 |
| Large files | Engine uploads derived files to R2 with multipart presigned uploads; web drag-and-drop also goes direct to R2, never through the Worker body (100 MB cap) | [Cloudflare limits](https://developers.cloudflare.com/workers/platform/limits), [R2 uploads](https://developers.cloudflare.com/r2/objects/upload-objects) |
| Maintainer is Sonny, owner is a non-engineer | Thin engine, CLI steps, all UI on the web stack Sonny already verifies | section 12.3 |
| Nothing outward without a human yes | Engine publishes only on an approval recorded in D1 | `BRIEF.md`, `content-engine/PLAN.md` |

### 13.3 What the web app needs from Apple, specifically

- Safari-friendly Web Push (and Declarative Web Push payloads where supported), with a clear
  "Allow notifications" button, since permission requires a user gesture.
- A web app manifest so "Add to Dock" and "Add to Home Screen" produce a proper app with icon and
  name `[general]`.
- Upload of a raw file from a browser must work in Safari without File System Access: a plain
  `<input type="file">` and drag-and-drop, uploading in parts directly to R2. The tab must stay open
  during upload; the engine path does not have that limitation.

### 13.4 Phasing (Apple-specific pieces only; the roadmap track sequences features)

1. **Engine v0 on Ivan's Mac**: watcher, completeness rule, materialization, audio extract, loudness,
   SpeechTranscriber transcript, FluidAudio speakers with enrollment, SoundAnalysis map, local
   notifications, upload of podcast audio and transcript to R2, events to the Worker. Podcast audio
   first, as agreed.
2. **Web Push** to Gabriel and Serenity, review screen, approve-to-publish.
3. **Vision thumbnails and video quality score**, ShazamKit music check, edited video via
   `AVMutableComposition`.
4. **Always-on host decision**, Developer ID signing and notarization if the engine moves Macs.
5. Later: FCPXML export, App Intents, pose-based class chaptering, Translation, second ASR engine.

---

## 14. Traps and blind spots (raised before anyone asks)

1. **"File appeared" is not "recording finished."** OBS creates the file when recording starts. Use
   the completeness rule (section 4.3) or the engine will process half a class.
2. **Optimize Mac Storage is on.** The studio folder can turn into placeholders at any time. A
   watcher that opens files on the main thread will hang (TN3150). Pin the folder on the engine Mac
   and handle dataless files anyway.
3. **TCC plus ad-hoc signing equals silent permission loss** after every rebuild (section 5). Sign
   with the Apple Development certificate from the first build.
4. **Apple has no diarization**, and the studio audio is one mixed track. Speaker labels, the
   per-person knowledge base, voice-training audio and the student-privacy rule all rest on
   FluidAudio's guesses until there is one mic per person on separate OBS tracks.
5. **Fail closed on privacy.** Any segment not confidently Gabriel or Serenity is "Other voice" and
   stays out of public outputs by default. A diarization miss here is a privacy incident, not a
   quality issue.
6. **VAD and denoise traps from past work.** Keep `SpeechDetector` off for the main pass, check
   coverage against duration, and isolate voices only after transcription.
7. **Foundation Models looks free but does not fit the job** (8,192-token context measured). PCC is
   not available to a Developer ID tool. Do not let "on-device AI" become a reason to build the
   editorial layer twice.
8. **The laptop is the single point of failure in v1.** If the 72-hour promise is published to
   anyone, it must say "while the engine Mac is on", or the always-on host must exist first.
9. **Stale docs.** Coffee Cup's README claims notarization that never happened (section 12.1).
   `content-engine/PLAN.md` (2026-07-19) says "There is no input source... Gabriel is not recording";
   the studio has recorded since 2026-09-06. Its warnings (no auto-publish, YouTube upload quota,
   Closer's LLM-call traps) still apply; its premise does not. Mark it as history beside the new plan.
10. **Beta OS and toolchain.** This Mac runs a macOS 27.2 beta build `[inferred]` and the toolchain
    has defaulted to a future deployment target before (Hark). Pin targets; test the built engine on
    a release macOS before moving it to another Mac.
11. **Loudness is not a checkbox.** The studio talk is 5 dB under the podcast target with a 20.6 LU
    range; plain normalization will either stay quiet or clip. Compress, then normalize, then limit.
12. **Content ID.** Classes with background music will draw claims; ShazamKit catches catalog music
    before upload, but only in 3 to 12 s windows, so it needs the SoundAnalysis music map to know
    where to look.

---

## 15. How to verify each piece (render it, run it, look at it)

- **Watcher**: record a 2-minute OBS test into the shared folder; on the engine Mac log the times of
  (a) first FSEvents event, (b) file no longer dataless, (c) `moov` present, (d) size stable. Expect
  (a) well before (c). Repeat with the engine quit during the recording to prove FSEvents replay.
- **Eviction**: `brctl evict` one finished recording, then confirm the engine materializes it and
  processes it without hanging the menu bar.
- **Sleep**: start a job on battery, close the lid, reopen: job resumes or restarts, nothing
  duplicated, `pmset -g assertions` shows the assertion only while a job runs.
- **TCC**: rebuild the engine twice; confirm it still reads `~/Documents` without a new prompt.
- **Transcript**: coverage line (last word time vs duration) on every file; read 3 random minutes
  against the audio; count glossary terms spelled right on a 20-term yoga/Sanskrit list.
- **Speakers**: on a talk with both teachers, listen to 10 random segment boundaries and score
  attribution; confirm a student's voice lands in "Other voice".
- **Podcast audio**: re-measure the master with `loudnorm` print mode: -16 plus or minus 1 LKFS,
  true peak at or under -1 dBFS; listen to intro, mid-roll and outro joins.
- **Thumbnails**: open the three chosen frames and look at them; they must be distinct scenes.
- **ShazamKit**: run on a clip with known music; expect a match.
- **Notifications**: receive all three stages on the engine Mac, on a Mac with the Dock web app, and
  on an iPhone Home Screen web app; confirm they group per recording.
- **Signing**: `codesign -dvv` shows the expected authority; on a second Mac, `spctl -a -vv`
  says accepted (Developer ID, notarized) before installing there.

---

## 16. Open questions

1. Which Mac runs OBS at the studio, is it always on, and what are its chip, RAM and macOS version?
   Could it host the engine?
2. Does Ivan want to fund (or ask Yoga Marga to fund) an always-on engine Mac, or is v1 on the
   MacBook Pro with "pauses while traveling" acceptable?
3. How many microphones does the studio have, and can OBS record one track per person?
4. What macOS and iOS versions do Gabriel and Serenity run? (Safari Web Push needs macOS 13+, Dock web
   apps macOS 14+, iPhone Home Screen push iOS 16.4+.)
5. Is any archive or studio content in Spanish or code-switched?
6. Does OBS write directly into the iCloud shared folder on the studio Mac, and what does a
   collaborator's Mac see while a recording is still in progress? (Needs the test in section 15.)
7. Will Ivan create the Developer ID Application certificate now (needed before the engine runs on any
   second Mac), and fix Coffee Cup's README claim at the same time?
8. Do Gabriel and Serenity want all three stage notifications, or only "ready to review"?
9. Archive ingest from unlisted YouTube (download method, storage location) is outside this track but
   decides disk sizing for the engine Mac.

---

## 17. Local evidence index

- `~/Code/prakriti/research/BRIEF.md`, `2026-10-07-call-gabriel-transcript.txt`
- `~/Code/transcribe-app/README.md`, `START_HERE.md`, `PLAN.md`, `CHANGELOG.md`, `Package.swift`
- `~/Code/coffee-cup/README.md`, `START_HERE.md`, `PLAN.md`, `CHANGELOG.md`
- `~/.claude/skills/transcribe-audio/SKILL.md`
- `~/Documents/Claude/Projects/Gabriel Galindo/content-engine/START_HERE.md`, `PLAN.md`
- `~/Code/up-next/START_HERE.md`
- macOS 27.0 SDK interfaces: `Speech`, `ActivityKit`, `WidgetKit`, `AudioToolbox` headers
- `/Applications/Final Cut Pro Creator Studio.app/Contents/Resources/ProEditor.sdef` and bundled
  `FCPXMLv1_14.dtd`
- Commands run: `sw_vers`, `system_profiler`, `security find-identity`, `codesign -dvv`, `spctl`,
  `brctl quota`, `brctl status`, `defaults read com.apple.bird`, `mdls`, `ls -lO`, `ffprobe`, `ffmpeg`
  (encode, loudnorm, astats), `avconvert`, Hark `diarize-proto`, and four Swift probes (Speech
  locales and Foundation Models context; SoundAnalysis labels and Shazam limits; Vision
  `VideoProcessor`; SoundAnalysis on a full talk)
