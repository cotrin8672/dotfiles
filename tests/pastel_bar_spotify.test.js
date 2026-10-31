const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.join(__dirname, '..', 'dot_glzr', 'zebar', 'pastel-bar');
const source = fs.readFileSync(path.join(root, 'executable_spotify.js'), 'utf8');
const settle = () => new Promise(resolve => setImmediate(resolve));
const deferred = () => {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return { promise, resolve };
};

class Element {
  constructor() {
    this.disabled = true;
    this.attributes = {};
    this.listeners = {};
    this.classes = new Set();
    this.classList = { toggle: (name, enabled) => enabled ? this.classes.add(name) : this.classes.delete(name) };
  }
  setAttribute(name, value) { this.attributes[name] = value; }
  addEventListener(name, callback) { this.listeners[name] = callback; }
  click() { this.listeners.click(); }
}

async function harness({ search = '', importGate, cursorGate, cursorHook, initialOutput = null } = {}) {
  const elements = Object.fromEntries(['spotify', 'track', 'track-title', 'previous', 'togglePlayPause', 'next'].map(id => [id, new Element()]));
  elements['track-title'].textContent = 'Spotify';
  elements['track-title'].scrollWidth = 40;
  elements.track.clientWidth = 76;
  Object.defineProperty(elements.track, 'textContent', { get: () => elements['track-title'].textContent });
  const document = {
    title: 'Pastel Bar - Spotify Hidden', getElementById: id => elements[id], hidden: false,
    addEventListener(name, callback) { this[name] = callback; },
    removeEventListener(name) { delete this[name]; },
  };
  const motion = {
    matches: false,
    addEventListener(name, callback) { this[name] = callback; },
    removeEventListener(name) { delete this[name]; },
  };
  const animations = [];
  elements['track-title'].animate = (frames, timing) => {
    const animation = { frames, timing, currentTime: 0, cancel() { this.cancelled = true; } };
    animations.push(animation);
    return animation;
  };
  let resize, disconnected = false;
  const nativeCalls = [];
  const nativeState = {};
  const controlCalls = [];
  const warnings = [];
  const unload = [];
  const channels = [];
  const intervals = [];
  let onOutput, onError, stopped = false, imports = 0;

  const nativeWindow = {
    setTitle: async value => { nativeCalls.push(['title', value]); nativeState.title = value; },
    setIgnoreCursorEvents: async value => {
      nativeCalls.push(['ignore', value]);
      if (!value && cursorGate) await cursorGate.promise;
      if (cursorHook) await cursorHook(value);
      nativeState.ignore = value;
    },
    clearEffects: async () => { nativeCalls.push(['clearEffects']); },
  };
  const provider = {
    output: initialOutput,
    onOutput: callback => { onOutput = callback; },
    onError: callback => { onError = callback; },
    stop: async () => { stopped = true; },
  };
  class Channel {
    constructor(name) { this.name = name; this.messages = []; channels.push(this); }
    postMessage(message) { this.messages.push(message); }
    close() { this.closed = true; }
    send(data) { this.onmessage({ data }); }
  }
  const context = vm.createContext({
    URLSearchParams, document, location: { search }, BroadcastChannel: Channel,
    matchMedia: () => motion,
    ResizeObserver: class {
      constructor(callback) { resize = callback; }
      observe() {}
      disconnect() { disconnected = true; }
    },
    console: { warn: (...args) => warnings.push(args) },
    setInterval: callback => intervals.push(callback), clearInterval: () => {},
    addEventListener: (name, callback) => { if (name === 'beforeunload') unload.push(callback); },
  });
  const vendor = new vm.SyntheticModule(['currentWidget', 'createProvider'], function () {
    this.setExport('currentWidget', () => ({ window: { tauri: nativeWindow } }));
    this.setExport('createProvider', config => {
      assert.equal(config.type, 'media');
      return provider;
    });
  }, { context });
  await vendor.link(() => {});
  await vendor.evaluate();
  const module = new vm.SourceTextModule(source, {
    context,
    importModuleDynamically: async specifier => {
      assert.equal(specifier, './vendor/zebar.js');
      imports++;
      if (importGate) await importGate.promise;
      return vendor;
    },
  });
  await module.link(() => {});
  const ready = module.evaluate();
  if (!importGate) { await ready; await settle(); }

  const output = sessions => ({
    allSessions: sessions,
    currentSession: sessions[0] ?? null,
    ...Object.fromEntries(['previous', 'togglePlayPause', 'next'].map(action => [action, options => {
      controlCalls.push([action, options.sessionId]);
    }])),
  });
  return {
    elements, document, nativeCalls, nativeState, controlCalls, warnings, channels, ready, output,
    animations, motion, resize: () => resize(),
    get disconnected() { return disconnected; },
    emit: value => { provider.output = value; onOutput(value); },
    error: () => onError(new Error('media failed')),
    close: () => unload.forEach(callback => callback()),
    tick: () => intervals.forEach(callback => callback()),
    get stopped() { return stopped; },
    get imports() { return imports; },
  };
}

test('standalone templates start hidden and connect the widget assets', () => {
  const html = fs.readFileSync(path.join(root, 'spotify.html.tmpl'), 'utf8');
  const css = fs.readFileSync(path.join(root, 'spotify.css.tmpl'), 'utf8');
  assert.match(html, /<html lang="en">/);
  assert.match(html, /href="\.\/spotify\.css"/);
  assert.match(html, /src="\.\/spotify\.js"/);
  assert.match(html, /id="spotify"[^>]*aria-hidden="true" inert/);
  for (const id of ['previous', 'togglePlayPause', 'next']) assert.match(html, new RegExp(`id="${id}"[^>]*disabled`));
  assert.match(css, /@media \(prefers-reduced-motion: reduce\)/);
  assert.match(css, /grid-template-columns: 22px minmax\(0, 1fr\);/);
  assert.match(css, /text-align: center; overflow: hidden; text-overflow: ellipsis/);
  assert.match(html, /id="track"><span class="track-title" id="track-title">Spotify<\/span><\/span>/);
  assert.match(css, /\.track-title \{[^}]*max-width: 100%; overflow: hidden; text-overflow: ellipsis;/);
  assert.match(css, /\.track\.is-scrolling \{ text-align: left; text-overflow: clip; \}/);
});

test('scrolls only measured overflow at a constant speed, retaining same-title playback updates', async () => {
  const h = await harness();
  h.channels[0].send({ type: 'snapshot', state: { spotifyOpen: true } });
  const song = { sessionId: 'Spotify.exe', title: '夜空', isPlaying: false };
  h.emit(h.output([song]));
  assert.equal(h.animations.length, 0);
  assert.equal(h.elements.track.classes.has('is-scrolling'), false);
  h.elements['track-title'].scrollWidth = 296;
  song.title = 'Long Latin title and 日本語の長いタイトル';
  h.emit(h.output([song]));
  const animation = h.animations[0];
  assert.equal(h.elements.track.title, song.title);
  assert.equal(h.elements.track.classes.has('is-scrolling'), true);
  assert.equal(animation.timing.duration, 12400);
  assert.equal(animation.timing.iterations, Infinity);
  assert.equal(animation.frames[1].offset * animation.timing.duration, 1200);
  assert.equal(animation.frames[2].offset * animation.timing.duration, 11200);
  assert.equal(animation.frames[3].transform, 'translateX(-220px)');
  animation.currentTime = 5000;
  for (const isPlaying of [true, false, false]) {
    song.isPlaying = isPlaying;
    h.emit(h.output([song]));
    h.resize();
  }
  assert.equal(h.animations.length, 1);
  assert.equal(animation.currentTime, 5000);
  assert.equal(animation.cancelled, undefined);
  song.title = 'Different title with the same measured width';
  h.emit(h.output([song]));
  assert.equal(animation.cancelled, true);
  assert.equal(h.animations.length, 2);
  assert.equal(h.animations[1].currentTime, 0);
});

test('remeasures viewport and text resizing and responds to reduced-motion changes', async () => {
  const h = await harness({ search: '?preview=paused' });
  h.elements['track-title'].scrollWidth = 120;
  h.resize();
  assert.equal(h.animations[0].timing.duration, 4400);
  h.elements.track.clientWidth = 98;
  h.resize();
  assert.equal(h.animations[0].cancelled, true);
  assert.equal(h.animations[1].timing.duration, 3400);
  h.motion.matches = true;
  h.motion.change();
  assert.equal(h.animations[1].cancelled, true);
  assert.equal(h.elements.track.classes.has('is-scrolling'), false);
  h.resize();
  assert.equal(h.animations.length, 2);
  h.motion.matches = false;
  h.motion.change();
  assert.equal(h.animations.length, 3);
  h.elements['track-title'].scrollWidth = 40;
  h.resize();
  assert.equal(h.animations[2].cancelled, true);
  assert.equal(h.elements.track.classes.has('is-scrolling'), false);
});

test('cancels title motion while hidden and disconnects observers on unload', async () => {
  const h = await harness();
  h.elements['track-title'].scrollWidth = 120;
  const channel = h.channels[0];
  channel.send({ type: 'snapshot', state: { spotifyOpen: true } });
  h.document.hidden = true;
  h.document.visibilitychange();
  assert.equal(h.animations[0].cancelled, true);
  h.document.hidden = false;
  h.document.visibilitychange();
  assert.equal(h.animations.length, 2);
  channel.send({ type: 'snapshot', state: { spotifyOpen: false } });
  assert.equal(h.animations[1].cancelled, true);
  h.resize();
  assert.equal(h.animations.length, 2);
  channel.send({ type: 'snapshot', state: { spotifyOpen: true } });
  h.close();
  assert.equal(h.animations[2].cancelled, true);
  assert.equal(h.disconnected, true);
  assert.equal(h.motion.change, undefined);
  assert.equal(h.document.visibilitychange, undefined);
  h.resize();
  assert.equal(h.animations.length, 3);
});

test('starts hidden, requests a snapshot, and stays disabled without a Spotify session', async () => {
  const h = await harness();
  const channel = h.channels[0];
  assert.equal(channel.name, 'pastel-bar-snapshots');
  assert.equal(channel.messages[0].type, 'request');
  assert.deepEqual(h.nativeCalls.filter(call => call[0] === 'title').at(-1), ['title', 'Pastel Bar - Spotify Hidden']);
  assert.deepEqual(h.nativeCalls.filter(call => call[0] === 'ignore').at(-1), ['ignore', true]);
  h.emit(h.output([{ sessionId: 'chrome.exe', title: 'Other app', isPlaying: true }]));
  channel.send({ type: 'snapshot', state: { spotifyOpen: true } });
  await settle();
  assert.equal(h.elements.spotify.classes.has('is-visible'), true);
  assert.equal(h.elements.spotify.inert, false);
  assert.equal(h.elements.track.textContent, 'Spotify');
  for (const id of ['previous', 'togglePlayPause', 'next']) {
    assert.equal(h.elements[id].disabled, true);
    h.elements[id].click();
  }
  assert.deepEqual(h.controlCalls, []);
  assert.deepEqual(h.nativeCalls.filter(call => call[0] === 'title').at(-1), ['title', 'Pastel Bar - Spotify']);
  assert.deepEqual(h.nativeCalls.filter(call => call[0] === 'ignore').at(-1), ['ignore', false]);
  channel.send({ type: 'snapshot', state: { spotifyOpen: 'false' } });
  assert.equal(h.elements.spotify.classes.has('is-visible'), true);
  h.close();
  await settle();
  assert.equal(channel.closed, true);
  assert.equal(h.stopped, true);
});

test('renders paused and playing Spotify sessions and respects disabled skip controls', async () => {
  const h = await harness();
  h.channels[0].send({ type: 'snapshot', state: { spotifyOpen: true } });
  const spotify = { sessionId: 'SPOTIFY.EXE', title: '  A Song  ', isPlaying: false, isPreviousEnabled: false, isNextEnabled: true };
  h.emit(h.output([{ sessionId: 'chrome.exe', title: 'Video' }, spotify]));
  assert.equal(h.elements.track.textContent, 'A Song');
  assert.equal(h.elements.spotify.classes.has('is-playing'), false);
  assert.equal(h.elements.togglePlayPause.attributes['aria-label'], 'Play');
  assert.equal(h.elements.previous.disabled, true);
  assert.equal(h.elements.next.disabled, false);
  spotify.isPlaying = true;
  h.emit(h.output([{ sessionId: 'chrome.exe', title: 'Video' }, spotify]));
  assert.equal(h.elements.spotify.classes.has('is-playing'), true);
  assert.equal(h.elements.togglePlayPause.attributes['aria-label'], 'Pause');
  h.error();
  assert.equal(h.elements.track.textContent, 'Spotify');
  assert.equal(h.elements.togglePlayPause.disabled, true);
  assert.equal(h.elements.spotify.classes.has('is-visible'), true);
});

test('controls only a verified Spotify desktop session with an explicit sessionId', async () => {
  const h = await harness();
  h.channels[0].send({ type: 'snapshot', state: { spotifyOpen: true } });
  h.emit(h.output([
    { sessionId: 'spotify-helper.exe', title: 'Other app', isPlaying: true },
    { sessionId: 'SPOTIFYAB.SPOTIFYMUSIC_ZPDNEKDRZREA0!SPOTIFY', title: 'Spotify', isPlaying: true },
  ]));
  for (const id of ['previous', 'togglePlayPause', 'next']) h.elements[id].click();
  assert.deepEqual(h.controlCalls, [
    ['previous', 'SPOTIFYAB.SPOTIFYMUSIC_ZPDNEKDRZREA0!SPOTIFY'],
    ['togglePlayPause', 'SPOTIFYAB.SPOTIFYMUSIC_ZPDNEKDRZREA0!SPOTIFY'],
    ['next', 'SPOTIFYAB.SPOTIFYMUSIC_ZPDNEKDRZREA0!SPOTIFY'],
  ]);
  h.emit(h.output([{ sessionId: 'spotify-helper.exe', title: 'Other app' }]));
  h.elements.next.click();
  assert.equal(h.controlCalls.length, 3);
  h.emit(h.output([{ sessionId: 'Spotify.exe', title: 'Spotify' }]));
  h.channels[0].send({ type: 'snapshot', state: { spotifyOpen: false } });
  h.elements.togglePlayPause.click();
  assert.equal(h.controlCalls.length, 3);
});

test('receives snapshots while the Zebar import is pending', async () => {
  const gate = deferred();
  const h = await harness({ importGate: gate });
  h.channels[0].send({ type: 'snapshot', state: { spotifyOpen: true } });
  assert.equal(h.elements.spotify.classes.has('is-visible'), true);
  assert.equal(h.elements.togglePlayPause.disabled, true);
  gate.resolve();
  await h.ready;
  await settle();
  assert.deepEqual(h.nativeCalls.filter(call => call[0] !== 'clearEffects'), [
    ['title', 'Pastel Bar - Spotify'], ['ignore', false],
  ]);
});

test('hides immediately and converges on hidden native state after a delayed open', async () => {
  const gate = deferred();
  const h = await harness({ cursorGate: gate });
  const channel = h.channels[0];
  channel.send({ type: 'snapshot', state: { spotifyOpen: true } });
  await settle();
  channel.send({ type: 'snapshot', state: { spotifyOpen: false } });
  assert.equal(h.elements.spotify.classes.has('is-visible'), false);
  assert.equal(h.elements.spotify.inert, true);
  assert.equal(h.elements.spotify.attributes['aria-hidden'], 'true');
  await settle();
  assert.deepEqual(h.nativeCalls.filter(call => call[0] === 'title').at(-1), ['title', 'Pastel Bar - Spotify Hidden']);
  assert.deepEqual(h.nativeCalls.filter(call => call[0] === 'ignore').at(-1), ['ignore', true]);
  assert.equal(h.nativeState.ignore, true);
  gate.resolve();
  await settle();
  assert.deepEqual(h.nativeCalls.filter(call => call[0] === 'title').at(-1), ['title', 'Pastel Bar - Spotify Hidden']);
  assert.deepEqual(h.nativeCalls.filter(call => call[0] === 'ignore').at(-1), ['ignore', true]);
  assert.equal(h.nativeState.ignore, true);
});

test('a delayed hide cannot leave a reopened widget ignoring the cursor', async () => {
  const gate = deferred();
  let delayHides = false;
  const h = await harness({ cursorHook: value => value && delayHides ? gate.promise : undefined });
  const channel = h.channels[0];
  channel.send({ type: 'snapshot', state: { spotifyOpen: true } });
  await settle();
  assert.equal(h.nativeState.ignore, false);
  delayHides = true;
  channel.send({ type: 'snapshot', state: { spotifyOpen: false } });
  await settle();
  channel.send({ type: 'snapshot', state: { spotifyOpen: true } });
  await settle();
  gate.resolve();
  await settle();
  assert.equal(h.nativeState.title, 'Pastel Bar - Spotify');
  assert.equal(h.nativeState.ignore, false);
});

test('a rejected native call does not block later visibility updates', async () => {
  const h = await harness({ cursorHook: value => { if (!value) throw new Error('unavailable'); } });
  const channel = h.channels[0];
  channel.send({ type: 'snapshot', state: { spotifyOpen: true } });
  await settle();
  assert.equal(h.warnings.length, 1);
  channel.send({ type: 'snapshot', state: { spotifyOpen: false } });
  await settle();
  assert.equal(h.nativeState.title, 'Pastel Bar - Spotify Hidden');
  assert.equal(h.nativeState.ignore, true);
});

test('hides and disables the controls when collector snapshots stop', async () => {
  const h = await harness();
  const channel = h.channels[0];
  channel.send({ type: 'snapshot', state: { spotifyOpen: true } });
  h.emit(h.output([{ sessionId: 'Spotify.exe', title: 'Song', isPlaying: true }]));
  for (let i = 0; i < 4; i++) h.tick();
  channel.send({ type: 'snapshot', state: { spotifyOpen: true } });
  for (let i = 0; i < 4; i++) h.tick();
  assert.equal(h.elements.spotify.classes.has('is-visible'), true);
  h.tick();
  await settle();
  assert.equal(h.elements.spotify.classes.has('is-visible'), false);
  assert.equal(h.elements.togglePlayPause.disabled, true);
  h.elements.togglePlayPause.click();
  assert.deepEqual(h.controlCalls, []);
  assert.equal(h.nativeState.title, 'Pastel Bar - Spotify Hidden');
  assert.equal(h.nativeState.ignore, true);
  assert.equal(channel.messages.at(-1).type, 'request');
});

test('preview works without Zebar and provides playing, paused, empty and closed states', async () => {
  const paused = await harness({ search: '?preview=paused' });
  assert.equal(paused.imports, 0);
  assert.equal(paused.elements.track.textContent, 'Midnight Drive');
  assert.equal(paused.elements.spotify.classes.has('is-playing'), false);
  paused.elements.togglePlayPause.click();
  assert.equal(paused.elements.spotify.classes.has('is-playing'), true);
  paused.elements.next.click();
  assert.equal(paused.elements.track.textContent, 'Quiet Morning');
  const playing = await harness({ search: '?preview' });
  assert.equal(playing.elements.spotify.classes.has('is-playing'), true);
  const empty = await harness({ search: '?preview=no-session' });
  assert.equal(empty.elements.track.textContent, 'Spotify');
  assert.equal(empty.elements.next.disabled, true);
  const closed = await harness({ search: '?preview=closed' });
  assert.equal(closed.elements.spotify.classes.has('is-visible'), false);
  assert.equal(closed.document.title, 'Pastel Bar - Spotify Hidden');
});
