// Streams Google Drive videos to the <video> element.
//
// Drive only accepts the OAuth token in the Authorization header for
// `alt=media` downloads, and a <video> element cannot set headers. The app
// points the player at `drive-stream/<fileId>?t=<token>&e=<expiry ms>` on its
// own origin; this worker moves the token into the header and forwards the
// request (including Range, so seeking and progressive playback work) to
// Drive.
//
// Tokens last about an hour while a film runs longer, so the page also posts
// every renewed token here. When the token runs out, range requests wait for
// the page to renew it instead of failing, so the player only stalls.

const STREAM_PREFIX = 'drive-stream/';

// Treat a token as expired slightly early so a request doesn't race it.
const EXPIRY_MARGIN_MS = 30 * 1000;

// The browser may stop a worker whose event stays pending for 5 minutes.
const TOKEN_WAIT_MS = 4 * 60 * 1000;

/** The newest token known: {token, expiresAt} (expiresAt 0 if unknown). */
let current = null;

/** Tokens Drive refused (revoked or expired early). */
const rejected = new Set();

/** Resolvers of requests waiting for a renewed token. */
let waiters = [];

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('message', (event) => {
  const data = event.data;
  // A hard reload (Shift+Reload) leaves the page uncontrolled even though
  // this worker is already active, so `activate` won't run again; the page
  // asks us to take control instead.
  if (data === 'claim') {
    event.waitUntil(self.clients.claim());
    return;
  }
  if (data && data.type === 'drive-token') {
    // null on sign-out.
    current = data.token ? { token: data.token, expiresAt: data.expiresAt || 0 } : null;
    if (current) {
      const resolve = waiters;
      waiters = [];
      resolve.forEach((wake) => wake());
    }
  }
});

function isUsable(entry) {
  return (
    entry != null &&
    !rejected.has(entry.token) &&
    (!entry.expiresAt || entry.expiresAt - EXPIRY_MARGIN_MS > Date.now())
  );
}

async function askPageForToken() {
  const windows = await self.clients.matchAll({ type: 'window' });
  windows.forEach((client) => client.postMessage({ type: 'drive-token-needed' }));
}

function waitForToken(signal) {
  return new Promise((resolve) => {
    let wake;
    const timer = setTimeout(() => finish(false), TOKEN_WAIT_MS);
    const finish = (renewed) => {
      clearTimeout(timer);
      waiters = waiters.filter((w) => w !== wake);
      if (signal) signal.removeEventListener('abort', onAbort);
      resolve(renewed);
    };
    const onAbort = () => finish(false);
    wake = () => finish(true);
    waiters.push(wake);
    if (signal) signal.addEventListener('abort', onAbort);
  });
}

async function tokenFor(fromUrl, signal) {
  // The URL carries the token from when playback started; a newer one may
  // have been posted since (or this worker restarted and forgot it).
  if (isUsable(fromUrl) && (!isUsable(current) || fromUrl.expiresAt > current.expiresAt)) {
    current = fromUrl;
  }
  while (!isUsable(current)) {
    await askPageForToken();
    if (!(await waitForToken(signal))) return null;
  }
  return current.token;
}

async function stream(request, fileId, fromUrl) {
  // Two tries: a token Drive refuses early gets one renewal.
  for (let attempt = 0; attempt < 2; attempt++) {
    const token = await tokenFor(fromUrl, request.signal);
    if (!token) break;

    const headers = new Headers({ Authorization: `Bearer ${token}` });
    const range = request.headers.get('Range');
    if (range) headers.set('Range', range);

    const response = await fetch(`https://www.googleapis.com/drive/v3/files/${fileId}?alt=media`, {
      headers,
      signal: request.signal,
    });
    if (response.status !== 401) return response;
    rejected.add(token);
  }
  return new Response('Google Drive access expired', { status: 401 });
}

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  const scopePath = new URL(self.registration.scope).pathname;
  if (url.origin !== self.location.origin) return;
  if (!url.pathname.startsWith(scopePath + STREAM_PREFIX)) return;

  const fileId = url.pathname.slice((scopePath + STREAM_PREFIX).length);
  const token = url.searchParams.get('t');
  if (!fileId || !token) {
    event.respondWith(new Response('Missing Drive file id or token', { status: 400 }));
    return;
  }
  const expiresAt = Number(url.searchParams.get('e')) || 0;

  event.respondWith(stream(event.request, fileId, { token, expiresAt }));
});
