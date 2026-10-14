// Runs the landing page's join script (public/index.html) against fake
// browser objects: which room it finds in the address, where it sends
// people with the app, and where the "join in the browser" button goes.
//
//   node tool/landing_join_test.mjs

import fs from 'node:fs';
import vm from 'node:vm';

const html = fs.readFileSync(new URL('../public/index.html', import.meta.url), 'utf8');
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
if (scripts.length !== 1) throw new Error(`expected one inline script, found ${scripts.length}`);

function visit(pathname) {
  const elements = {};
  const element = (id) =>
    (elements[id] ??= { id, href: '#', textContent: '', style: {}, onclick: null });
  const window = { location: { pathname, href: `https://emotional-app-b42af.web.app${pathname}` } };
  const context = {
    window,
    document: { getElementById: element, title: '', hidden: false },
    console: { log() {} },
    setTimeout() {},
  };
  vm.createContext(context);
  vm.runInContext(scripts[0], context);
  window.onload();
  return {
    redirect: window.location.href,
    appLink: element('join-btn').href,
    webLink: element('web-join-btn').href,
    roomShown: element('room-id-display').textContent,
  };
}

let fails = 0;
const check = (name, actual, expected) => {
  const ok = actual === expected;
  if (!ok) fails++;
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${ok ? '' : `: got ${actual}, want ${expected}`}`);
};

let page = visit('/join/123456');
check('invite opens the app', page.appLink, 'emotional://join/123456');
check('and tries it right away', page.redirect, 'emotional://join/123456');
check('offers the web app for the same room', page.webLink, 'https://emoti-izle.web.app/join/123456');
check('shows the room', page.roomShown, 'Oda #123456');

page = visit('/join/123456/');
check('a trailing slash keeps the room clean', page.appLink, 'emotional://join/123456');

page = visit('/654321');
check('a bare room path works too', page.webLink, 'https://emoti-izle.web.app/join/654321');

page = visit('/');
check('no room: open the app home', page.appLink, 'emotional://home');
check('no room: web app home', page.webLink, 'https://emoti-izle.web.app/');

page = visit('/favicon.ico');
check('files are not rooms', page.appLink, 'emotional://home');

page = visit('/join/%E0%A4%A');
check('broken encoding does not break the page', page.appLink, 'emotional://home');

page = visit('/join/<script>');
check('odd characters are not rooms', page.webLink, 'https://emoti-izle.web.app/');

process.exit(fails ? 1 : 0);
