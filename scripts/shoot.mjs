#!/usr/bin/env node
// Render pages to PNGs and report problems. This is the verification step for any visual
// change: reading the HTML is not verification, looking at the pixels is.
//
//   node scripts/shoot.mjs [--base <url-or-file-dir>] [--out screens] [--width 1440]
//        [--height 1000] [--dark] [--full] [--click <css selector>] /index.html /roadmap.html
//
// --base defaults to the local static site (file://…/web/public), so no server is needed.
// --full captures the whole page height, not just the first screen.
// For each page it also prints: console errors, failed resource loads, and horizontal
// overflow (the page must never scroll sideways, at any width).
//
// Adapted from ~/Code/up-next/scripts/shoot.mjs. No dependencies beyond Node 22 and Chrome.

import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  if (i < 0) return fallback;
  const v = args[i + 1];
  args.splice(i, 2);
  return v;
};
const flag = (name) => {
  const i = args.indexOf(`--${name}`);
  if (i < 0) return false;
  args.splice(i, 1);
  return true;
};
const here = dirname(fileURLToPath(import.meta.url));
const base = opt('base', 'file://' + resolve(here, '../web/public'));
const out = opt('out', resolve(here, '../screens'));
const width = Number(opt('width', '1440'));
const height = Number(opt('height', '1000'));
const dark = flag('dark');
const full = flag('full');
const clicks = opt('click', null);
const paths = args.length ? args : ['/index.html'];

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const port = 9700 + Math.floor(Math.random() * 250);
const chrome = spawn(CHROME, ['--headless=new', `--remote-debugging-port=${port}`, '--no-first-run',
  '--no-default-browser-check', `--user-data-dir=/tmp/prakriti-shoot-${port}`, '--hide-scrollbars',
  '--allow-file-access-from-files', 'about:blank'], { stdio: 'ignore' });
let wsUrl;
for (let i = 0; i < 60 && !wsUrl; i++) {
  await new Promise((r) => setTimeout(r, 150));
  try {
    const targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
    wsUrl = targets.find((t) => t.type === 'page')?.webSocketDebuggerUrl;
  } catch {}
}
if (!wsUrl) { console.error('Chrome did not start.'); chrome.kill(); process.exit(1); }

const ws = new WebSocket(wsUrl);
await new Promise((r) => ws.addEventListener('open', r, { once: true }));
let id = 0;
const pending = new Map();
const problems = [];
ws.addEventListener('message', (e) => {
  const msg = JSON.parse(e.data);
  if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); return; }
  if (msg.method === 'Runtime.exceptionThrown') problems.push('JS exception: ' + (msg.params.exceptionDetails?.exception?.description || msg.params.exceptionDetails?.text));
  if (msg.method === 'Runtime.consoleAPICalled' && msg.params.type === 'error') problems.push('console.error: ' + msg.params.args.map((a) => a.value ?? a.description).join(' '));
  if (msg.method === 'Network.loadingFailed' && !msg.params.canceled) problems.push('failed load: ' + msg.params.errorText + ' ' + (msg.params.requestId || ''));
  if (msg.method === 'Log.entryAdded' && msg.params.entry.level === 'error') problems.push('log error: ' + msg.params.entry.text + ' ' + (msg.params.entry.url || ''));
});
const send = (method, params = {}) => new Promise((res) => { const n = ++id; pending.set(n, res); ws.send(JSON.stringify({ id: n, method, params })); });

await send('Page.enable');
await send('Network.enable');
await send('Runtime.enable');
await send('Log.enable');
await send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: width < 700 });
await send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-color-scheme', value: dark ? 'dark' : 'light' }, { name: 'prefers-reduced-motion', value: 'reduce' }] });

mkdirSync(out, { recursive: true });
for (const p of paths) {
  problems.length = 0;
  const url = /^(https?|file):/.test(p) ? p : `${base}${p}`;
  await send('Page.navigate', { url });
  await new Promise((r) => setTimeout(r, 1600));
  if (clicks) {
    await send('Runtime.evaluate', { expression: `document.querySelector(${JSON.stringify(clicks)})?.click()` });
    await new Promise((r) => setTimeout(r, 700));
  }
  const m = await send('Runtime.evaluate', { returnByValue: true, expression:
    `({sw: document.documentElement.scrollWidth, iw: innerWidth, sh: document.documentElement.scrollHeight,
       wide: [...document.querySelectorAll('body *')].filter(e => e.getBoundingClientRect().right > innerWidth + 1).slice(0,5).map(e => e.tagName + (e.className ? '.' + String(e.className).split(' ')[0] : ''))})` });
  const info = m.result.result.value;
  if (info.sw > info.iw + 1) problems.push(`horizontal overflow: page is ${info.sw}px wide at ${info.iw}px (${info.wide.join(', ')})`);
  let shot;
  if (full) {
    const h = Math.min(info.sh, 16000);
    await send('Emulation.setDeviceMetricsOverride', { width, height: h, deviceScaleFactor: 1, mobile: width < 700 });
    await new Promise((r) => setTimeout(r, 500));
    shot = await send('Page.captureScreenshot', { format: 'png' });
    await send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: width < 700 });
  } else {
    shot = await send('Page.captureScreenshot', { format: 'png' });
  }
  const slug = p.replace(/^.*\//, '').replace(/\.html$/, '').replace(/[^a-z0-9-]/gi, '_') || 'index';
  const name = `${slug}-${width}${dark ? '-dark' : ''}${full ? '-full' : ''}.png`;
  writeFileSync(join(out, name), Buffer.from(shot.result.data, 'base64'));
  console.log('wrote', join(out, name), `(page height ${info.sh}px)`);
  console.log(problems.length ? '  PROBLEMS:\n  - ' + problems.join('\n  - ') : '  no console errors, no failed loads, no horizontal overflow');
}
ws.close();
chrome.kill();
