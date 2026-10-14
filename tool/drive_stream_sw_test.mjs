// Exercises web/drive_stream_sw.js with fake clients and a fake Drive:
// token renewal while a stream waits, 401 retries, and ignored requests.
//
//   node tool/drive_stream_sw_test.mjs
import fs from 'node:fs';
import vm from 'node:vm';
const workerPath = process.argv[2] ?? new URL('../web/drive_stream_sw.js', import.meta.url);
const src = fs.readFileSync(workerPath, 'utf8');
const listeners = {};
const posted = [];
let validTokens = new Set(['A']);
const fetchLog = [];
const ctx = {
  console, URL, Headers, Response, Promise, Set, Number, setTimeout, clearTimeout, Date,
  self: {
    addEventListener: (t, f) => (listeners[t] = f),
    registration: { scope: 'https://app.test/' },
    location: { origin: 'https://app.test' },
    skipWaiting() {},
    clients: { claim: async () => {}, matchAll: async () => [{ postMessage: (m) => posted.push(m) }] },
  },
  fetch: async (url, opts) => {
    const token = opts.headers.get('Authorization').slice(7);
    fetchLog.push(token);
    return new Response('video', { status: validTokens.has(token) ? 206 : 401 });
  },
};
vm.createContext(ctx);
vm.runInContext(src, ctx);
function request(url) {
  let responded;
  const ev = {
    request: { url, headers: new Headers({ Range: 'bytes=0-' }), signal: new AbortController().signal },
    respondWith: (p) => (responded = Promise.resolve(p)),
  };
  listeners.fetch(ev);
  return responded;
}
const msg = (data) => listeners.message({ data, waitUntil() {} });
const tick = () => new Promise((r) => setTimeout(r, 20));
let fails = 0;
const check = (name, cond) => { if (!cond) fails++; console.log(cond ? 'PASS' : 'FAIL', name); };
const now = Date.now();

// 1. Valid URL token streams.
let r = await request(`https://app.test/drive-stream/f1?t=A&e=${now + 3600e3}`);
check('valid token streams', r.status === 206);

// 2. Token expired: request waits, page is asked, renewal resumes it.
validTokens = new Set(['B']);
const pending = request(`https://app.test/drive-stream/f1?t=A&e=${now - 1000}`);
await tick();
check('asks page for token when expired', posted.some((m) => m.type === 'drive-token-needed'));
let settled = false; pending.then(() => (settled = true));
await tick();
check('request waits instead of failing', !settled);
msg({ type: 'drive-token', token: 'B', expiresAt: now + 3600e3 });
r = await pending;
check('resumes with renewed token', r.status === 206 && fetchLog.at(-1) === 'B');

// 3. Later requests with the old URL token use the newer posted token.
r = await request(`https://app.test/drive-stream/f1?t=A&e=${now + 60e3}`);
check('prefers newer posted token over URL token', r.status === 206 && fetchLog.at(-1) === 'B');

// 4. Drive rejects early (401): asks for renewal and retries once.
validTokens = new Set(['C']);
posted.length = 0;
const retry = request(`https://app.test/drive-stream/f1?t=A&e=${now + 60e3}`);
await tick();
check('401 triggers token request', posted.some((m) => m.type === 'drive-token-needed'));
msg({ type: 'drive-token', token: 'C', expiresAt: now + 3600e3 });
r = await retry;
check('retries with renewed token after 401', r.status === 206 && fetchLog.at(-1) === 'C');

// 5. Sign-out clears the token; non-stream URLs are ignored.
msg({ type: 'drive-token', token: null });
let ignored = true;
listeners.fetch({ request: { url: 'https://app.test/main.dart.js', headers: new Headers() }, respondWith: () => (ignored = false) });
check('ignores non-stream requests', ignored);
process.exit(fails ? 1 : 0);
