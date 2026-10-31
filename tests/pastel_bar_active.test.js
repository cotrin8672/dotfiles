const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../dot_glzr/zebar/pastel-bar/executable_ui.js'), 'utf8');

function harness() {
  const animations = [], events = new Map(), documentEvents = new Map();
  class Element {
    constructor() { this.textContent = ''; this.dataset = {}; this.attributes = {}; this.children = new Map(); this.classes = new Set(); this.classList = { toggle: (name, enabled) => enabled ? this.classes.add(name) : this.classes.delete(name) }; }
    querySelector(selector) { if (!this.children.has(selector)) this.children.set(selector, new Element()); return this.children.get(selector); }
    setAttribute(name, value) { this.attributes[name] = value; }
    getAttribute(name) { return this.attributes[name]; }
    addEventListener() {}
    replaceChildren() {}
    append() {}
    animate(keyframes, options) {
      const animation = { keyframes, options, currentTime: 0, cancelled: false, cancel() { this.cancelled = true; } };
      animations.push(animation);
      return animation;
    }
  }
  const elements = Object.fromEntries(['window-title', 'window-title-text', 'active-window', 'app-icon', 'cpu', 'gpu', 'ram', 'codex', 'claude'].map(id => [id, new Element()]));
  elements['window-title'].clientWidth = 284;
  elements['window-title-text'].scrollWidth = 40;
  elements['window-title-text'].textContent = 'Desktop';
  const preference = { matches: false, addEventListener(name, fn) { this.listener = fn; }, removeEventListener(name, fn) { if (this.listener === fn) this.listener = null; } };
  const document = {
    hidden: false, body: new Element(), getElementById: id => elements[id], querySelectorAll: () => [], createElement: () => new Element(),
    addEventListener: (name, fn) => documentEvents.set(name, fn), removeEventListener: name => documentEvents.delete(name),
  };
  let resize;
  class ResizeObserver {
    constructor(callback) { this.callback = callback; this.observed = []; resize = this; }
    observe(element) { this.observed.push(element); }
    disconnect() { this.disconnected = true; }
  }
  const window = {};
  vm.runInNewContext(source, { document, window, URLSearchParams, location: { search: '' }, matchMedia: () => preference, ResizeObserver, setInterval: () => {}, addEventListener: (name, fn) => events.set(name, fn) });
  return {
    elements, animations, document, preference, resize, update: window.pastelBar.update,
    title(value, width) { elements['window-title-text'].scrollWidth = width; window.pastelBar.update({ activeWindow: { title: value, app: 'Demo', icon: null } }); },
    visibility(value) { document.hidden = value; documentEvents.get('visibilitychange')(); },
    close: () => events.get('beforeunload')(), documentEvents,
  };
}

test('active title scrolls only measured overflow and preserves progress between snapshots', () => {
  const h = harness();
  h.title('Short', 40);
  assert.equal(h.animations.length, 0);
  h.title('Long window title', 484);
  const first = h.animations[0];
  assert.equal(first.options.duration, 2400 + 200 / 22 * 1000);
  assert.equal(first.options.iterations, Infinity);
  assert.equal(first.keyframes[1].offset * first.options.duration, 1200);
  assert.equal(first.keyframes.at(-1).transform, 'translateX(-200px)');
  first.currentTime = 3000;
  h.update({ connected: true });
  h.title('Long window title', 484);
  assert.equal(h.animations.length, 1);
  assert.equal(first.currentTime, 3000);
  assert.equal(first.cancelled, false);
  h.title('Different window title', 484);
  assert.equal(first.cancelled, true);
  assert.equal(h.animations.length, 2);
  assert.equal(h.animations[1].currentTime, 0);
  assert.equal(h.elements['active-window'].title, 'Demo\nDifferent window title');
  h.title('Short', 40);
  assert.equal(h.animations[1].cancelled, true);
  assert.equal(h.elements['window-title'].classes.has('is-scrolling'), false);
});

test('active title remeasures size changes and respects motion and visibility preferences', () => {
  const h = harness();
  h.title('Long', 484);
  h.elements['window-title'].clientWidth = 200;
  h.resize.callback();
  assert.equal(h.animations[0].cancelled, true);
  assert.equal(h.animations.at(-1).keyframes.at(-1).transform, 'translateX(-284px)');
  h.resize.callback();
  assert.equal(h.animations.length, 2);
  h.preference.matches = true;
  h.preference.listener();
  assert.equal(h.animations.at(-1).cancelled, true);
  assert.equal(h.elements['window-title'].classes.has('is-scrolling'), false);
  h.preference.matches = false;
  h.preference.listener();
  assert.equal(h.animations.length, 3);
  h.visibility(true);
  assert.equal(h.animations.at(-1).cancelled, true);
  h.visibility(false);
  assert.equal(h.animations.length, 4);
});

test('inactive pills and unloading do not leave title animations or observers running', () => {
  const h = harness();
  h.elements['window-title'].clientWidth = 0;
  h.title('Hidden title', 484);
  assert.equal(h.animations.length, 0);
  h.elements['window-title'].clientWidth = 284;
  h.resize.callback();
  assert.equal(h.animations.length, 1);
  assert.equal(h.resize.observed.length, 2);
  h.close();
  assert.equal(h.animations[0].cancelled, true);
  assert.equal(h.resize.disconnected, true);
  assert.equal(h.preference.listener, null);
  assert.equal(h.documentEvents.has('visibilitychange'), false);
  h.resize.callback();
  assert.equal(h.animations.length, 1);
});
