const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const directory = path.join(__dirname, '..', 'dot_glzr', 'zebar', 'pastel-bar');
const script = fs.readFileSync(path.join(directory, 'executable_calendar.js'), 'utf8');
const ROW = 32;

class Element {
  children = [];
  attributes = {};
  listeners = {};
  hidden = false;
  textContent = '';
  scrollTop = 0;
  scrolls = [];
  classes = new Set();
  classList = {
    add: name => this.classes.add(name),
    remove: name => this.classes.delete(name),
    toggle: (name, enabled) => enabled ? this.classes.add(name) : this.classes.delete(name),
    contains: name => this.classes.has(name),
  };
  get className() { return [...this.classes].join(' '); }
  set className(value) { this.classes = new Set(value.split(' ').filter(Boolean)); }
  append(...children) { this.children.push(...children); }
  replaceChildren(...children) { this.children = children; }
  setAttribute(name, value) { this.attributes[name] = value; }
  addEventListener(name, listener) { this.listeners[name] = listener; }
  scrollTo({ top, behavior }) { this.scrolls.push({ top, behavior }); this.scrollTop = top; }
}

function calendarAt(initialDate, { search = '?preview', tauri = false, reduced = false } = {}) {
  let now = initialDate;
  let imports = 0;
  let hides = 0, shows = 0, focuses = 0;
  let hideError = null;
  const positions = [];
  const ignores = [];
  const timers = [];
  const handlers = {};
  let closeRequested;
  const channel = { messages: [], postMessage(message) { this.messages.push(message); }, close() { this.closed = true; } };
  const elements = Object.fromEntries(['month', 'weeks', 'calendar', 'previous', 'next', 'today'].map(name => [name, new Element()]));
  class Clock extends Date {
    constructor(...args) { super(...(args.length ? args : [now])); }
  }
  const context = vm.createContext({
    Date: Clock,
    URLSearchParams,
    location: { search },
    matchMedia: () => ({ matches: reduced }),
    window: { __TAURI_INTERNALS__: tauri ? {} : undefined, addEventListener: (name, handler) => { handlers[name] = handler; } },
    document: {
      getElementById: id => elements[id],
      querySelector: () => elements.calendar,
      createElement: () => new Element(),
    },
    setTimeout: (callback, delay) => timers.push({ callback, delay }),
    BroadcastChannel: class { constructor(name) { assert.equal(name, 'pastel-bar-calendar'); return channel; } },
    console: { ...console, error: () => {} },
  });
  vm.runInContext(script, context, {
    importModuleDynamically: async specifier => {
      assert.equal(specifier, './vendor/zebar.js');
      imports++;
      const module = new vm.SyntheticModule(['currentWidget'], function () {
        this.setExport('currentWidget', () => ({ window: { tauri: {
          setTitle: async title => { assert.equal(title, 'Pastel Calendar'); },
          setIgnoreCursorEvents: async value => { ignores.push(value); },
          hide: async () => { hides++; if (hideError) throw hideError; },
          show: async () => { shows++; },
          setFocus: async () => { focuses++; throw new Error('Command plugin:window|set_focus not allowed by ACL'); },
          onCloseRequested: async callback => { closeRequested = callback; },
          setPosition: async position => { positions.push({ ...position }); },
        } } }));
      }, { context });
      await module.link(() => {});
      await module.evaluate();
      return module;
    },
  });
  const weeks = elements.weeks;
  const row = (offset = 0) => weeks.children[Math.round(weeks.scrollTop / ROW) + offset];
  return {
    elements,
    timers,
    channel,
    ignores,
    positions,
    get imports() { return imports; },
    get hides() { return hides; },
    get shows() { return shows; },
    get focuses() { return focuses; },
    failHide: () => { hideError = new Error('denied'); },
    send: data => channel.onmessage({ data }),
    nativeClose: () => { let prevented=false; closeRequested({ preventDefault() { prevented=true; } }); assert.equal(prevented,true); },
    row,
    labels: (offset = 0) => row(offset).children.map(cell => cell.attributes['aria-label']),
    top: () => row().children[0].attributes['aria-label'],
    click: name => elements[name].listeners.click(),
    key: key => { const event = { key, prevented: false, preventDefault() { this.prevented = true; } }; handlers.keydown(event); return event; },
    event: (name, event = {}) => handlers[name](event),
    scroll: rows => { weeks.scrollTop += rows * ROW; weeks.listeners.scroll(); },
    wheel: (deltaY, deltaMode = 0) => { const event = { deltaY, deltaMode, prevented: false, preventDefault() { this.prevented = true; } }; weeks.listeners.wheel(event); return event; },
    settle: () => weeks.listeners.scrollend(),
    advance: date => { now = date; timers.shift().callback(); },
    runTimer: delay => { const index = timers.findIndex(timer => timer.delay === delay); assert.notEqual(index, -1); timers.splice(index, 1)[0].callback(); },
  };
}
const flush = async () => { for (let i = 0; i < 5; i++) await new Promise(setImmediate); };

test('calendar markup keeps table, weekday and focusable scroller semantics', () => {
  const html = fs.readFileSync(path.join(directory, 'calendar.html.tmpl'), 'utf8');
  assert.match(html, /<html lang="en">/);
  assert.match(html, /href="\.\/calendar\.css"/);
  assert.match(html, /src="\.\/calendar\.js"/);
  assert.match(html, /role="table" aria-labelledby="month"/);
  assert.match(html, /class="weekdays" role="row"/);
  const headers = [...html.matchAll(/role="columnheader" aria-label="(\w+)">(\w+)</g)].map(match => [match[1], match[2]]);
  assert.deepEqual(headers.map(([full]) => full), ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']);
  assert.ok(headers.every(([full, short]) => full.startsWith(short)));
  assert.match(html, /id="weeks" role="rowgroup" tabindex="0"/);
  assert.match(html, /id="today"/);
});

test('continuous weeks label every date and handle leap days, year ends and today', () => {
  const calendar = calendarAt(new Date(2024, 1, 29, 23, 0));
  const weeks = calendar.elements.weeks.children;
  assert.equal(weeks.length, 42);
  assert.ok(weeks.every(week => week.attributes.role === 'row' && week.children.length === 7 && week.children.every(cell => cell.attributes.role === 'cell')));
  assert.equal(calendar.elements.month.textContent, 'February 2024');
  assert.deepEqual(calendar.labels(), ['Sunday, January 28, 2024', 'Monday, January 29, 2024', 'Tuesday, January 30, 2024', 'Wednesday, January 31, 2024', 'Thursday, February 1, 2024', 'Friday, February 2, 2024', 'Saturday, February 3, 2024']);
  assert.deepEqual(calendar.row().children.map(cell => cell.classes.has('is-outside')), [true, true, true, true, false, false, false]);
  const cells = weeks.flatMap(week => week.children);
  const today = cells.filter(cell => cell.attributes['aria-current'] === 'date');
  assert.equal(today.length, 1);
  assert.equal(today[0].attributes['aria-label'], 'Thursday, February 29, 2024');
  assert.ok(today[0].classes.has('today'));
  assert.equal(cells[cells.indexOf(today[0]) + 1].attributes['aria-label'], 'Friday, March 1, 2024');

  const century = calendarAt(new Date(1900, 1, 10)).labels(4);
  assert.ok(century.includes('Wednesday, February 28, 1900') && century.includes('Thursday, March 1, 1900'));
  assert.ok(calendarAt(new Date(2000, 1, 10)).labels(4).includes('Tuesday, February 29, 2000'));

  const yearEnd = calendarAt(new Date(2024, 11, 31));
  yearEnd.click('next');
  assert.equal(yearEnd.elements.month.textContent, 'January 2025');
  assert.deepEqual(yearEnd.labels().slice(2, 5), ['Tuesday, December 31, 2024', 'Wednesday, January 1, 2025', 'Thursday, January 2, 2025']);
  assert.equal(yearEnd.elements.weeks.scrolls.at(-1).behavior, 'smooth');
});

test('scrolling crosses months and recentres the bounded buffer without moving the view', () => {
  const calendar = calendarAt(new Date(2026, 9, 31));
  assert.equal(calendar.elements.month.textContent, 'October 2026');
  calendar.scroll(5);
  assert.equal(calendar.elements.month.textContent, 'November 2026');
  assert.equal(calendar.row(2).children[3].classes.has('is-outside'), false);
  assert.equal(calendar.row(5).children[6].classes.has('is-outside'), true);

  let expected = new Date(2026, 10, 1, 12); // Sunday at the top after five rows
  for (let i = 0; i < 40; i++) {
    calendar.scroll(5);
    expected = new Date(expected.getFullYear(), expected.getMonth(), expected.getDate() + 35, 12);
    if (i % 3 === 2) calendar.settle();
    assert.equal(calendar.elements.weeks.children.length, 42);
    assert.ok(calendar.elements.weeks.scrollTop >= ROW && calendar.elements.weeks.scrollTop <= 35 * ROW);
    assert.equal(calendar.top(), expected.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' }));
  }
  for (let i = 0; i < 80; i++) calendar.scroll(-5);
  calendar.settle();
  assert.equal(calendar.elements.weeks.children.length, 42);
  expected = new Date(expected.getFullYear(), expected.getMonth(), expected.getDate() - 80 * 35, 12);
  assert.equal(calendar.top(), expected.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' }));
});

test('buttons and keys accumulate, jump far targets, and return to today', () => {
  const calendar = calendarAt(new Date(2024, 1, 29));
  calendar.click('previous');
  calendar.click('previous');
  assert.equal(calendar.elements.month.textContent, 'December 2023');
  assert.equal(calendar.top(), 'Sunday, November 26, 2023');
  calendar.settle();
  assert.equal(calendar.top(), 'Sunday, November 26, 2023');
  assert.equal(calendar.key('PageDown').prevented, true);
  assert.equal(calendar.elements.month.textContent, 'January 2024');
  calendar.settle();
  calendar.key('ArrowDown');
  calendar.key('ArrowDown');
  assert.equal(calendar.top(), 'Sunday, January 14, 2024');
  calendar.settle();
  for (let i = 0; i < 30; i++) calendar.click('previous');
  assert.equal(calendar.elements.month.textContent, 'July 2021');
  assert.equal(calendar.elements.weeks.children.length, 42);
  calendar.settle();
  calendar.key('Home');
  assert.equal(calendar.elements.month.textContent, 'February 2024');
  assert.equal(calendar.top(), 'Sunday, January 28, 2024');
  calendar.click('today');
  assert.equal(calendar.top(), 'Sunday, January 28, 2024');
  assert.equal(calendar.key('Enter').prevented, false);

  const reduced = calendarAt(new Date(2024, 1, 29), { reduced: true });
  reduced.click('next');
  assert.equal(reduced.elements.month.textContent, 'March 2024');
  assert.deepEqual(reduced.elements.weeks.scrolls, []);
});

test('mouse wheel moves one week per notch and trackpads retain small proportional deltas', () => {
  const calendar = calendarAt(new Date(2026, 9, 31));
  const weeks = calendar.elements.weeks;
  const initial = weeks.scrollTop;
  assert.equal(calendar.wheel(120).prevented, true);
  assert.equal(weeks.scrollTop, initial + ROW);
  calendar.wheel(120);
  assert.equal(weeks.scrollTop, initial + 2 * ROW);
  calendar.settle();
  calendar.wheel(-3, 1);
  assert.equal(weeks.scrollTop, initial + ROW);
  calendar.settle();
  calendar.wheel(5);
  assert.equal(weeks.scrollTop, initial + ROW + 2);
  assert.equal(calendar.wheel(0).prevented, false);
  assert.equal(calendar.wheel(NaN).prevented, false);
});

test('midnight refresh follows the current month without interrupting another month', () => {
  const initial = new Date(2024, 11, 31, 23, 59, 59, 250);
  const calendar = calendarAt(initial);
  assert.equal(calendar.timers[0].delay, 750);
  calendar.advance(new Date(2025, 0, 1));
  assert.equal(calendar.elements.month.textContent, 'January 2025');
  const today = calendar.elements.weeks.children.flatMap(week => week.children).filter(cell => cell.attributes['aria-current'] === 'date');
  assert.deepEqual(today.map(cell => cell.attributes['aria-label']), ['Wednesday, January 1, 2025']);
  assert.equal(calendar.timers.length, 1);

  const browsing = calendarAt(initial);
  browsing.click('previous');
  browsing.settle();
  browsing.advance(new Date(2025, 0, 1));
  assert.equal(browsing.elements.month.textContent, 'November 2024');
});

test('preview animates closed on Escape or blur without loading Zebar', async () => {
  const preview = calendarAt(new Date(2024, 1, 1), { tauri: true });
  preview.event('keydown', { key: 'Enter', preventDefault() {} });
  assert.equal(preview.elements.calendar.classes.has('is-closing'), false);
  preview.event('keydown', { key: 'Escape' });
  assert.equal(preview.elements.calendar.classes.has('is-closing'), true);
  assert.equal(preview.elements.calendar.hidden, false);
  await flush();
  preview.runTimer(110);
  await flush();
  assert.equal(preview.elements.calendar.hidden, true);
  assert.equal(preview.imports, 0);

  const browser = calendarAt(new Date(2024, 1, 1), { search: '', reduced: true });
  browser.event('blur');
  await flush();
  browser.runTimer(0);
  await flush();
  assert.equal(browser.elements.calendar.hidden, true);
  assert.equal(browser.imports, 0);
});

test('Zebar prepares hidden, opens, and hides its resident window once after the exit', async () => {
  for (const event of ['outside-click', 'keydown']) {
    const widget = calendarAt(new Date(2024, 1, 1), { search: '', tauri: true });
    assert.equal(widget.elements.calendar.hidden, true);
    await flush();
    assert.deepEqual(widget.channel.messages.map(message => message.type), ['preparing', 'ready']);
    assert.equal(widget.hides, 1);
    widget.send({ type: 'open', x: 800, y: 50 });
    await flush();
    assert.equal(widget.elements.calendar.hidden, false);
    assert.deepEqual(widget.positions, [{ type: 'Logical', x: 800, y: 50 }]);
    assert.equal(widget.shows, 1);
    assert.equal(widget.focuses, 0);
    widget.event('blur');
    await flush();
    assert.equal(widget.elements.calendar.hidden, false);
    assert.equal(widget.elements.calendar.classes.has('is-closing'), false);
    if (event === 'outside-click') widget.nativeClose();
    else widget.event(event, { key: 'Escape' });
    widget.event('blur');
    widget.send({ type: 'close' });
    await flush();
    assert.deepEqual(widget.ignores, [true, false, true]);
    assert.equal(widget.hides, 1);
    widget.runTimer(110);
    await flush();
    assert.equal(widget.imports, 1);
    assert.equal(widget.hides, 2);
    assert.equal(widget.elements.calendar.hidden, true);
    assert.deepEqual(widget.channel.messages.map(message => message.type), ['preparing', 'ready', 'opened', 'closed']);
    widget.send({ type: 'open', x: 700, y: 50 });
    await flush();
    assert.equal(widget.imports, 1);
    assert.equal(widget.shows, 2);
    assert.equal(widget.elements.calendar.hidden, false);
    assert.equal(widget.elements.calendar.classes.has('is-closing'), false);
  }
});

test('a failed close restores an interactive calendar', async () => {
  const widget = calendarAt(new Date(2024, 1, 1), { search: '', tauri: true, reduced: true });
  await flush();
  widget.send({ type: 'open', x: 800, y: 50 });
  await flush();
  widget.failHide();
  widget.nativeClose();
  await flush();
  widget.runTimer(0);
  await flush();
  assert.equal(widget.elements.calendar.classes.has('is-closing'), false);
  assert.deepEqual(widget.ignores, [true, false, true, false]);
  assert.deepEqual(widget.channel.messages.map(message => message.type), ['preparing', 'ready', 'opened', 'closed', 'opened']);
});

test('status discovers the warm window and reopening cancels a pending hide', async () => {
  const widget = calendarAt(new Date(2024, 1, 1), { search: '', tauri: true, reduced: true });
  const types = () => widget.channel.messages.map(message => message.type);
  await flush();
  widget.send({ type: 'status' });
  await flush();
  assert.deepEqual(types(), ['preparing', 'ready', 'ready']);
  widget.send({ type: 'open', x: 800, y: 50 });
  await flush();
  widget.send({ type: 'close' });
  await flush();
  widget.send({ type: 'open', x: 810, y: 50 });
  await flush();
  widget.runTimer(0);
  await flush();
  assert.equal(widget.hides, 1);
  assert.equal(widget.shows, 2);
  assert.equal(widget.elements.calendar.hidden, false);
  assert.deepEqual(types(), ['preparing', 'ready', 'ready', 'opened', 'closed', 'opened']);
  widget.send({ type: 'open', x: NaN, y: 50 });
  await flush();
  assert.equal(widget.shows, 2);
  widget.event('beforeunload');
  assert.equal(types().at(-1), 'gone');
  assert.equal(widget.channel.closed, true);
});
