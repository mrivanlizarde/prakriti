#!/usr/bin/env node
// Prakriti engine v0 — the first slice you can actually run (2026-10-08).
//
// Watches folders for new recordings, waits until each file is really finished, checks it has
// sound, then makes a podcast-ready MP3 (-16 LUFS, -1 dBTP, mono) and a timed transcript, and
// tells you on this Mac at each step. NOTHING is published: you listen, then upload by hand.
// This is the bridge to the Swift engine in docs/SCOPE.md §7; it keeps that spec's rules:
//
// - A new file is not a finished recording (OBS creates it when recording STARTS, and iCloud
//   files can be placeholders). Ready = downloaded, size stable, opens, and its last seconds decode.
// - Sound check first. The 09-14 class was recorded silent and nobody knew for 24 days.
// - Under 60 seconds is a test: filed silently, no notification.
// - Coverage check after transcription: the transcript must reach the end of the recording
//   (a filter once dropped 80% of a tape and returned fluent text; Parakeet dropped the last
//   85 s of a clip in our own test).
// - Outputs go to ~/Prakriti/Outputs, never into the shared iCloud folder: transcripts can
//   carry students' words and names, and that folder syncs to every participant.
// - Every run leaves a dated line in ~/Prakriti/log.txt, including "nothing new".
// - Absolute binary paths: launchd starts jobs with a bare PATH (the agency backup failed 66
//   nights on exactly that).
//
// Usage:
//   node prakriti.mjs watch            run forever (the LaunchAgent does this)
//   node prakriti.mjs run <file>       process one file now, ignoring what has been seen
//   node prakriti.mjs status           list everything Prakriti has seen and what happened

import { spawn, execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync, appendFileSync, statSync, readdirSync, watch, copyFileSync } from 'node:fs';
import { join, basename, extname, dirname } from 'node:path';
import { homedir } from 'node:os';

const HOME = homedir();
const ROOT = join(HOME, 'Prakriti');
const OUT = join(ROOT, 'Outputs');
const DROP = join(ROOT, 'Drop');
const STATE = join(ROOT, 'state.json');
const LOG = join(ROOT, 'log.txt');
const WATCH = [
  join(HOME, 'Documents/Design Work/Galindo x Lizarde/Studio Recordings '), // trailing space is real
  DROP, // anything else (a phone recording, an archive file): drop it here
];
const FFMPEG = '/opt/homebrew/bin/ffmpeg';
const FFPROBE = '/opt/homebrew/bin/ffprobe';
const PARAKEET = join(HOME, 'Code/transcribe-3/.venv/bin/parakeet-mlx');
const MEDIA = new Set(['.mp4', '.mov', '.mkv', '.m4a', '.wav', '.mp3', '.aac', '.m4v']);
const STABLE_MS = 60_000;      // size must hold still this long
const SWEEP_MS = 5 * 60_000;   // safety sweep in case a file event is missed

for (const d of [ROOT, OUT, DROP]) mkdirSync(d, { recursive: true });
const now = () => new Date().toLocaleString('sv-SE').slice(0, 19); // local time, sortable
const log = (m) => { const line = `${now()}  ${m}`; appendFileSync(LOG, line + '\n'); console.log(line); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const loadState = () => { try { return JSON.parse(readFileSync(STATE, 'utf8')); } catch { return { files: {} }; } };
const saveState = (s) => writeFileSync(STATE, JSON.stringify(s, null, 2));

function notify(title, body) {
  // osascript notifications appear as "Script Editor" the first time; allow them in System
  // Settings > Notifications if macOS asks. Quotes are stripped so text can never break out.
  const clean = (t) => String(t).replace(/["\\]/g, '');
  try { execFileSync('/usr/bin/osascript', ['-e', `display notification "${clean(body)}" with title "Prakriti" subtitle "${clean(title)}"`]); } catch {}
}

function run(cmd, args, { capture = true } = {}) {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'], env: { ...process.env, PATH: `/opt/homebrew/bin:/usr/bin:/bin:${process.env.PATH || ''}` } });
    let out = '', err = '';
    p.stdout.on('data', (d) => { if (capture) out += d; });
    p.stderr.on('data', (d) => { err += d; if (err.length > 2e6) err = err.slice(-1e6); });
    p.on('close', (code) => code === 0 ? resolve({ out, err }) : reject(new Error(`${basename(cmd)} exited ${code}: ${err.slice(-600)}`)));
  });
}

const fmt = (s) => { s = Math.round(s); const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), x = s % 60; return (h ? `${h}:${String(m).padStart(2, '0')}` : `${m}`) + `:${String(x).padStart(2, '0')}`; };
const label = (file) => {
  const m = basename(file).match(/(\d{4})-(\d{2})-(\d{2})/);
  if (!m) return basename(file, extname(file));
  const d = new Date(`${m[1]}-${m[2]}-${m[3]}T12:00:00`);
  return d.toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short' }).replace(',', '');
};

// ---------- readiness ----------
function isDataless(file) {
  try { return execFileSync('/usr/bin/stat', ['-f', '%Sf', file]).toString().includes('dataless'); } catch { return false; }
}
async function waitUntilReady(file) {
  if (isDataless(file)) {
    log(`downloading from iCloud: ${file}`);
    try { execFileSync('/usr/bin/brctl', ['download', file]); } catch {}
    for (let i = 0; i < 360 && isDataless(file); i++) await sleep(10_000); // up to an hour
    if (isDataless(file)) throw new Error('iCloud never finished downloading it');
  }
  let last = -1;
  for (;;) { // size must stop changing (OBS writes the file for the whole session)
    const size = statSync(file).size;
    if (size === last && size > 0) break;
    last = size;
    await sleep(STABLE_MS);
  }
  const probe = JSON.parse((await run(FFPROBE, ['-v', 'error', '-show_entries', 'format=duration:stream=codec_type', '-of', 'json', file])).out);
  const duration = Number(probe.format?.duration);
  if (!duration) throw new Error('the file does not open yet (no duration)');
  const hasAudio = (probe.streams || []).some((s) => s.codec_type === 'audio');
  await run(FFMPEG, ['-v', 'error', '-sseof', '-5', '-i', file, '-f', 'null', '-'], { capture: false }); // last seconds decode
  return { duration, hasAudio };
}

// ---------- the pipeline ----------
async function processFile(file, state) {
  const key = file;
  const st = statSync(file);
  const rec = state.files[key] = { ...(state.files[key] || {}), size: st.size, mtime: st.mtimeMs, status: 'checking', at: now() };
  saveState(state);
  const name = label(file);
  const { duration, hasAudio } = await waitUntilReady(file);
  rec.duration = duration;

  if (duration < 60) { rec.status = 'test'; saveState(state); log(`test clip (${Math.round(duration)}s), filed: ${file}`); return; }
  notify(`New Recording Found: ${name}`, `${fmt(duration)} long. Checking it now.`);
  log(`found ${fmt(duration)}: ${file}`);

  // sound check: the whole audio track, fast (about 2 s per hour)
  let maxDb = -Infinity, meanDb = -Infinity;
  if (hasAudio) {
    const { err } = await run(FFMPEG, ['-hide_banner', '-nostats', '-i', file, '-vn', '-af', 'volumedetect', '-f', 'null', '-']);
    maxDb = Number(err.match(/max_volume: (-?[\d.]+|-inf) dB/)?.[1] ?? -Infinity);
    meanDb = Number(err.match(/mean_volume: (-?[\d.]+|-inf) dB/)?.[1] ?? -Infinity);
  }
  if (!hasAudio || !(maxDb > -60)) {
    rec.status = 'silent'; saveState(state);
    notify(`Needs a Decision: ${name}`, `This recording has no usable sound (loudest point ${hasAudio ? maxDb + ' dB' : 'no audio track'}). Nothing was made from it.`);
    log(`SILENT (max ${maxDb} dB): ${file}`);
    return;
  }

  const dir = join(OUT, basename(file, extname(file)));
  mkdirSync(dir, { recursive: true });
  const minutes = Math.max(1, Math.round(duration / 60 / 20));
  notify(`Started: ${name}`, `Transcribing and mastering. About ${minutes} minute${minutes > 1 ? 's' : ''}.`);
  rec.status = 'processing'; saveState(state);
  log(`started: ${file}`);
  const t0 = Date.now();

  // 1. mono 16 kHz audio for transcription
  const wav = join(dir, 'speech.wav');
  await run(FFMPEG, ['-y', '-v', 'error', '-i', file, '-vn', '-ac', '1', '-ar', '16000', wav], { capture: false });

  // 2. transcription (Parakeet on Apple Silicon), then the coverage check
  await run(PARAKEET, [wav, '--output-dir', dir, '--output-format', 'all', '--output-template', 'transcript'], { capture: false });
  let lastEnd = 0, words = 0;
  try {
    const srt = readFileSync(join(dir, 'transcript.srt'), 'utf8');
    for (const m of srt.matchAll(/--> (\d+):(\d+):(\d+)[,.](\d+)/g)) lastEnd = Math.max(lastEnd, +m[1] * 3600 + +m[2] * 60 + +m[3]);
    words = readFileSync(join(dir, 'transcript.txt'), 'utf8').split(/\s+/).filter(Boolean).length;
  } catch {}
  const gap = duration - lastEnd;
  const coverage = gap <= 120 ? `reaches ${fmt(lastEnd)} of ${fmt(duration)}` : `STOPS at ${fmt(lastEnd)} of ${fmt(duration)}; the last ${fmt(gap)} is missing (it may be silence; listen before trusting it)`;

  // 3. mastering: two-pass loudness to -16 LUFS, -1 dBTP, mono MP3 128k (Apple Podcasts spec).
  //    The limiter MUST have level=disabled: its default "auto level" re-normalizes to 0 dBFS after
  //    limiting, which shipped a +2.2 dBFS peak on the first test (8 Oct). Limit -2 dB leaves room
  //    for the overshoot MP3 encoding adds. Mono mix and sample rate are set INSIDE the filter chain,
  //    before the limiter: as output options ffmpeg applies them after it, and resampling after
  //    a limiter put the peak back over 0 dBFS (second test, 8 Oct).
  const m1 = (await run(FFMPEG, ['-hide_banner', '-nostats', '-i', file, '-vn', '-af', `aformat=channel_layouts=mono,aresample=48000,loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json`, '-f', 'null', '-'])).err;
  const j = JSON.parse(m1.slice(m1.lastIndexOf('{'), m1.lastIndexOf('}') + 1));
  const mp3 = join(dir, 'episode.mp3');
  await run(FFMPEG, ['-y', '-v', 'error', '-i', file, '-vn', '-af',
    `aformat=channel_layouts=mono,aresample=48000,loudnorm=I=-15.4:TP=-1.5:LRA=11:measured_I=${j.input_i}:measured_TP=${j.input_tp}:measured_LRA=${j.input_lra}:measured_thresh=${j.input_thresh}:offset=${j.target_offset}:linear=true,alimiter=limit=0.84:level=disabled:attack=5:release=50`, '-ar', '48000',
    '-c:a', 'libmp3lame', '-b:a', '128k', mp3], { capture: false });
  const m2 = (await run(FFMPEG, ['-hide_banner', '-nostats', '-i', mp3, '-af', 'ebur128=peak=true', '-f', 'null', '-'])).err;
  const outI = m2.match(/I:\s+(-?[\d.]+) LUFS/g)?.pop()?.match(/-?[\d.]+/)?.[0];
  const outTP = m2.match(/Peak:\s+(-?[\d.]+) dBFS/g)?.pop()?.match(/-?[\d.]+/)?.[0];
  await run(FFMPEG, ['-v', 'error', '-sseof', '-5', '-i', mp3, '-f', 'null', '-'], { capture: false }); // the MP3's own tail decodes

  // 4. the report you read before you listen
  const secs = Math.round((Date.now() - t0) / 1000);
  const report = `# ${name}: ${basename(file)}

Made by Prakriti engine v0 on ${now()} in ${fmt(secs)}. **Nothing has been published.**

| | |
|---|---|
| Recording | ${fmt(duration)}, ${(st.size / 1e9).toFixed(2)} GB |
| Sound in | average ${meanDb} dB, loudest ${maxDb} dB; loudness ${j.input_i} LUFS |
| Episode audio | \`episode.mp3\`, mono 128 kbps, ${outI ?? '?'} LUFS, true peak ${outTP ?? '?'} dBFS (target -16 LUFS, peak at or under -1) |
| Transcript | \`transcript.txt\`, \`.srt\`, \`.vtt\`, ${words} words; ${coverage} |

## Before this goes anywhere
1. **Listen.** Start, end, and anywhere the transcript shows someone other than the teacher.
2. **Other voices and names.** v0 does not yet label speakers or mute names. If a student speaks
   or is named, do not publish until Serenity's rule is decided (PLAN.md).
3. **Claims.** Check any income or health claim and any offer that may be closed (enrollment has
   been paused since January).
4. Spellings: "Yoga Marga" and Sanskrit terms are often mis-heard; search the transcript.
`;
  writeFileSync(join(dir, 'REPORT.md'), report);
  try { execFileSync('/bin/rm', ['-f', wav]); } catch {}
  rec.status = 'ready'; rec.output = dir; rec.seconds = secs; saveState(state);
  log(`READY in ${fmt(secs)}: ${dir} (${outI} LUFS, ${coverage})`);
  notify(`Ready for Your Yes: ${name}`, `Episode audio and transcript are ready. Listen before anything goes out.`);
}

// ---------- watching ----------
function candidates() {
  const found = [];
  const walk = (d, depth = 0) => {
    let entries = [];
    try { entries = readdirSync(d, { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      if (e.name.startsWith('.')) continue;
      const p = join(d, e.name);
      if (e.isDirectory() && depth < 3) walk(p, depth + 1);
      else if (e.isFile() && MEDIA.has(extname(e.name).toLowerCase()) && !/-vertical\./i.test(e.name)) found.push(p);
    }
  };
  WATCH.forEach((d) => walk(d));
  return found;
}

let busy = false;
async function sweep(state, reason) {
  if (busy) return;
  busy = true;
  try {
    const todo = candidates().filter((f) => {
      const r = state.files[f];
      if (!r) return true;
      if (r.status === 'failed' && (r.tries || 0) < 3) return true; // automatic retries, then stop
      return false;
    });
    if (!todo.length) { log(`sweep (${reason}): nothing new`); return; }
    for (const f of todo) {
      try { await processFile(f, state); }
      catch (e) {
        const r = state.files[f] || (state.files[f] = {});
        r.status = 'failed'; r.tries = (r.tries || 0) + 1; r.error = e.message; saveState(state);
        log(`FAILED (try ${r.tries}): ${f}: ${e.message}`);
        if (r.tries >= 3) notify(`Couldn't Finish: ${label(f)}`, `Tried three times. The reason is in ~/Prakriti/log.txt.`);
      }
    }
  } finally { busy = false; }
}

const [cmd, arg] = process.argv.slice(2);
const state = loadState();

if (cmd === 'status') {
  for (const [f, r] of Object.entries(state.files)) console.log(`${(r.status || '').padEnd(10)} ${r.duration ? fmt(r.duration).padStart(8) : '        '}  ${basename(f)}${r.error ? '  (' + r.error.slice(0, 80) + ')' : ''}`);
  console.log(`\nOutputs: ${OUT}\nDrop folder: ${DROP}\nLog: ${LOG}`);
} else if (cmd === 'run' && arg) {
  if (!existsSync(arg)) { console.error('No such file: ' + arg); process.exit(1); }
  delete state.files[arg];
  processFile(arg, state).catch((e) => { log(`FAILED: ${arg}: ${e.message}`); notify(`Couldn't Finish: ${label(arg)}`, e.message.slice(0, 120)); process.exit(1); });
} else if (cmd === 'watch') {
  // First ever start: everything already in the folders is the past, not new raw material.
  if (!state.baselined) {
    for (const f of candidates()) state.files[f] = state.files[f] || { status: 'existing', at: now() };
    state.baselined = now(); saveState(state);
    log(`first start: ${Object.keys(state.files).length} existing files marked as already seen`);
  }
  log(`watching: ${WATCH.join(' | ')}`);
  for (const d of WATCH) {
    try { watch(d, { recursive: true }, () => { clearTimeout(globalThis.__t); globalThis.__t = setTimeout(() => sweep(state, 'file event'), 5000); }); }
    catch (e) { log(`cannot watch ${d}: ${e.message}`); }
  }
  sweep(state, 'start');
  setInterval(() => sweep(state, 'timer'), SWEEP_MS);
} else {
  console.log('Usage: node prakriti.mjs watch | run <file> | status');
}
