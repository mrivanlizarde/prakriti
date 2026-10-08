// Prakriti front door: the Cloudflare Worker in front of prakriti.therowan.studio.
// Written 2026-10-08. Serves the static pages in web/public/ through env.ASSETS.
//
// Why it is built this way (each rule has cost someone something before):
// - Allowlist, not blocklist. Only the paths named below are ever served. therowan.studio
//   published .git and CLAUDE.md twice by serving a whole folder; here a stray file in
//   public/ still stays private unless it is added on purpose.
// - Security headers on EVERY response, including redirects, 404s and errors. wrangler.jsonc
//   sets run_worker_first so no response can bypass this file.
// - Strict-Transport-Security only over https. Sent from http://localhost it locks the browser
//   out of local development (memory: no-hsts-from-local-dev).
// - A real 404 status for unknown paths. A soft 404 (the homepage with a 200) hides broken
//   links and invites crawlers to index junk.
// - No inline scripts or styles anywhere: the CSP below forbids them, so a script injected into
//   a page cannot run.
// - Same-name assets get a short cache, never "immutable": an immutable same-name file served
//   a stale poster for the life of the cache on another site (memory: never-overwrite-an-
//   immutable-asset).
// - Conditional requests are passed through. With a short cache, browsers revalidate often;
//   forwarding If-None-Match and If-Modified-Since lets the asset binding answer 304 Not
//   Modified with no body, instead of resending every file in full. A 304 still passes through
//   secure(), so it carries the same security headers as a 200. The 404 page never takes a
//   conditional: a 304 there would hide the real status.

const PAGES = new Map([
  ['/', '/'],                 // index.html: features + sign-in
  ['/roadmap', '/roadmap'],   // roadmap.html
]);

const REDIRECTS = new Map([
  ['/index.html', '/'],
  ['/index', '/'],
  ['/roadmap.html', '/roadmap'],
  ['/roadmap/', '/roadmap'],
]);

const FILES = new Set(['/robots.txt']);

// One level under /assets/, a plain file name, and only file types a page needs. This rejects
// dotfiles, path tricks, source maps and anything that is not a web asset.
const ASSET = /^\/assets\/[a-z0-9][a-z0-9_-]*(?:\.[a-z0-9_-]+)*\.(?:css|js|svg|png|jpg|jpeg|webp|avif|woff2|ico)$/i;

const CSP = [
  "default-src 'none'",
  "script-src 'self'",
  "style-src 'self' https://fonts.googleapis.com",
  "font-src 'self' https://fonts.gstatic.com",
  "img-src 'self'",
  "connect-src 'self'",
  "manifest-src 'self'",
  "object-src 'none'",
  "base-uri 'none'",
  "form-action 'none'",
  "frame-ancestors 'none'",
].join('; ');

// http to https (round 2, E15: Ivan's web security baseline asks for it, and the round 2 review
// found it missing). A request on plain http is sent to the same address on https, except in
// local development. Two tests decide "local", and both are needed:
// - the hostname is localhost, 127.0.0.1 or [::1]; and
// - the request did not come through Cloudflare's edge, which stamps every request with CF-Ray
//   (and CF-Visitor). `wrangler dev` rewrites request.url to the route's hostname,
//   http://prakriti.therowan.studio/, so the hostname test alone answered every local request
//   with a 301 to itself, an endless loop (measured 8 Oct under wrangler 4.148).
// If the edge ever stopped sending both headers, the redirect would quietly not happen rather
// than loop, which is why the deploy checks include: curl -sI http://prakriti.therowan.studio/
// must answer 301 with a Location on https.
const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', '[::1]']);

function needsHttps(request, url) {
  if (url.protocol !== 'http:') return false;
  if (LOCAL_HOSTS.has(url.hostname)) return false;
  return request.headers.has('cf-ray') || request.headers.has('cf-visitor');
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const https = url.protocol === 'https:';
    if (needsHttps(request, url)) {
      const to = new URL(url);
      to.protocol = 'https:';
      // Through secure() like every other response, so the redirect carries the same headers.
      // No HSTS here: it is only ever sent over https.
      return secure(new Response(null, { status: 301, headers: { Location: to.toString(), 'Cache-Control': 'public, max-age=3600' } }), false);
    }
    try {
      return secure(await route(request, env, url), https);
    } catch (err) {
      console.error('prakriti web: unhandled', err && err.stack ? err.stack : err);
      return secure(text('Something went wrong. Try again in a minute.', 500), https);
    }
  },
};

async function route(request, env, url) {
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    return text('Method not allowed.', 405, { Allow: 'GET, HEAD' });
  }
  const head = request.method === 'HEAD';
  const path = url.pathname;

  if (REDIRECTS.has(path)) {
    return new Response(null, { status: 301, headers: { Location: REDIRECTS.get(path), 'Cache-Control': 'public, max-age=3600' } });
  }

  if (PAGES.has(path)) {
    const res = await fromAssets(env, url, PAGES.get(path), request);
    if (res.status === 304) return notModified(res, 'no-cache');
    if (res.ok) return finish(res, head, 'no-cache');
    return notFound(env, url, head);
  }

  if (FILES.has(path)) {
    const res = await fromAssets(env, url, path, request);
    if (res.status === 304) return notModified(res, 'public, max-age=3600');
    if (res.ok) return finish(res, head, 'public, max-age=3600');
    return notFound(env, url, head);
  }

  if (ASSET.test(path)) {
    const res = await fromAssets(env, url, path, request);
    if (res.status === 304) return notModified(res, 'public, max-age=300');
    if (res.ok) return finish(res, head, 'public, max-age=300');
    return notFound(env, url, head);
  }

  return notFound(env, url, head);
}

// Asks the static-asset binding for a path. Cloudflare's default html_handling may answer an
// .html path with a redirect to its clean URL, so up to two same-origin redirects are followed
// here, inside the Worker, and never shown to the visitor. When the visitor's request is passed
// in, its two conditional headers go with it (and nothing else from it), so the binding can
// answer 304.
const CONDITIONAL = ['If-None-Match', 'If-Modified-Since'];

async function fromAssets(env, url, path, request) {
  const headers = new Headers();
  if (request) {
    for (const name of CONDITIONAL) {
      const value = request.headers.get(name);
      if (value) headers.set(name, value);
    }
  }
  let target = new URL(path, url.origin);
  for (let i = 0; i < 3; i++) {
    const res = await env.ASSETS.fetch(new Request(target.toString(), { method: 'GET', headers }));
    const loc = res.status >= 300 && res.status < 400 ? res.headers.get('Location') : null;
    if (!loc) return res;
    const next = new URL(loc, target);
    if (next.origin !== target.origin) return res;
    target = next;
  }
  return new Response(null, { status: 508 });
}

async function notFound(env, url, head) {
  const res = await fromAssets(env, url, '/404.html');
  if (!res.ok) return text('Not found.', 404);
  // 404.html uses relative asset paths so it renders from disk. Served at a deep address such
  // as /a/b/c, a relative path would resolve to /a/b/assets/ and fail, so it is pinned to the
  // root here. The page is a few kilobytes, so reading it whole is fine.
  const html = (await res.text()).replace(/(href|src)="assets\//g, '$1="/assets/');
  return new Response(head ? null : html, {
    status: 404,
    headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' },
  });
}

// 304 Not Modified: no body, the validators the browser needs, and the same cache rule as the
// full response would carry.
function notModified(res, cacheControl) {
  const headers = new Headers();
  for (const name of ['ETag', 'Last-Modified']) {
    const value = res.headers.get(name);
    if (value) headers.set(name, value);
  }
  headers.set('Cache-Control', cacheControl);
  return new Response(null, { status: 304, headers });
}

function finish(res, head, cacheControl) {
  const out = new Response(head ? null : res.body, { status: 200, headers: new Headers(res.headers) });
  out.headers.set('Cache-Control', cacheControl);
  return out;
}

function text(body, status, extra = {}) {
  return new Response(body, {
    status,
    headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store', ...extra },
  });
}

// Every response passes through here. Copied first, because responses from the asset binding
// have immutable headers.
function secure(res, https) {
  const out = new Response(res.body, res);
  const h = out.headers;
  h.set('Content-Security-Policy', https ? `${CSP}; upgrade-insecure-requests` : CSP);
  if (https) h.set('Strict-Transport-Security', 'max-age=63072000; includeSubDomains');
  h.set('X-Content-Type-Options', 'nosniff');
  h.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  h.set('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=(), usb=()');
  h.set('X-Frame-Options', 'DENY');
  h.set('X-Robots-Tag', 'noindex, nofollow');
  h.set('Cross-Origin-Opener-Policy', 'same-origin');
  h.set('Cross-Origin-Resource-Policy', 'same-origin');
  return out;
}
