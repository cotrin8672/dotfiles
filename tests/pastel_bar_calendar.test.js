const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const directory = path.join(__dirname, '..', 'dot_glzr', 'zebar', 'pastel-bar');
const script = fs.readFileSync(path.join(directory, 'executable_calendar.js'), 'utf8');

class Element {
  children = [];
  attributes = {};
  listeners = {};
  hidden = false;
  textContent = '';
  append(...children) { this.children.push(...children); }
  replaceChildren(...children) { this.children = children; }
  setAttribute(name, value) { this.attributes[name] = value; }
  addEventListener(name, listener) { this.listeners[name] = listener; }
}

function calendarAt(initialDate, { search = '?preview', tauri = false } = {}) {
  let now = initialDate;
  let imports = 0;
  let closes = 0;
  const timers = [];
  const handlers = {};
  const channel = { messages: [], postMessage(message) { this.messages.push(message); } };
  const elements = Object.fromEntries(['month', 'days', 'calendar', 'previous', 'next'].map(name => [name, new Element()]));
  class Clock extends Date {
    constructor(...args) { super(...(args.length ? args : [now])); }
  }
  const context = vm.createContext({
    Date: Clock,
    URLSearchParams,
    location: { search },
    window: { __TAURI_INTERNALS__: tauri ? {} : undefined, addEventListener: (name, handler) => { handlers[name] = handler; } },
    document: {
      getElementById: id => elements[id],
      querySelector: () => elements.calendar,
      createElement: () => new Element(),
    },
    setTimeout: (callback, delay) => timers.push({ callback, delay }),
    BroadcastChannel: class { constructor(name) { assert.equal(name, 'pastel-bar-calendar'); return channel; } },
    console,
  });
  vm.runInContext(script, context, {
    importModuleDynamically: async specifier => {
      assert.equal(specifier, './vendor/zebar.js');
      imports++;
      const module = new vm.SyntheticModule(['currentWidget'], function () {
        this.setExport('currentWidget', () => ({ window: { tauri: { close: () => { closes++; } } } }));
      }, { context });
      await module.link(() => {});
      await module.evaluate();
      return module;
    },
  });
  return {
    elements,
    timers,
    channel,
    get imports() { return imports; },
    get closes() { return closes; },
    cells: () => elements.days.children.flatMap(row => row.children),
    click: name => elements[name].listeners.click(),
    event: (name, event = {}) => handlers[name](event),
    advance: date => { now = date; timers.shift().callback(); },
  };
}

function numberedCells(calendar) {
  return calendar.cells().filter(cell => cell.children.length).map(cell => cell.children[0]);
}

test('calendar markup connects the standalone assets and accessible weekday table', () => {
  const html = fs.readFileSync(path.join(directory, 'calendar.html.tmpl'), 'utf8');
  assert.match(html, /<html lang="en">/);
  assert.match(html, /href="\.\/calendar\.css"/);
  assert.match(html, /src="\.\/calendar\.js"/);
  assert.match(html, /<tbody id="days">/);
  assert.equal((html.match(/<th scope="col"/g) || []).length, 7);
});

test('six Sunday-first rows handle leap days, year boundaries, and a current date', () => {
  const calendar = calendarAt(new Date(2024, 1, 29, 23, 0));
  assert.equal(calendar.elements.month.textContent, 'February 2024');
  assert.equal(calendar.elements.days.children.length, 6);
  assert.ok(calendar.elements.days.children.every(row => row.children.length === 7));
  assert.ok(calendar.cells().slice(0, 4).every(cell => !cell.children.length));
  assert.equal(numberedCells(calendar).length, 29);
  assert.equal(numberedCells(calendar)[28].attributes['aria-current'], 'date');
  calendar.click('previous');
  calendar.click('previous');
  assert.equal(calendar.elements.month.textContent, 'December 2023');
  assert.equal(numberedCells(calendar).length, 31);
  assert.ok(numberedCells(calendar).every(day => !day.attributes['aria-current']));
  calendar.click('next');
  calendar.click('next');
  assert.equal(calendar.elements.month.textContent, 'February 2024');
  assert.equal(numberedCells(calendar).length, 29);

  assert.equal(numberedCells(calendarAt(new Date(2000, 1, 1))).length, 29);
  assert.equal(numberedCells(calendarAt(new Date(1900, 1, 1))).length, 28);
  const sixWeeks = calendarAt(new Date(2026, 7, 1));
  assert.ok(sixWeeks.cells().slice(0, 6).every(cell => !cell.children.length));
  assert.deepEqual(sixWeeks.cells().slice(35, 37).map(cell => cell.children[0].textContent), ['30', '31']);
  const endOfMonth = calendarAt(new Date(2025, 0, 31));
  endOfMonth.click('next');
  assert.equal(endOfMonth.elements.month.textContent, 'February 2025');
  assert.equal(numberedCells(endOfMonth).length, 28);
});

test('midnight refresh follows the current month without interrupting another month', () => {
  const initial = new Date(2024, 11, 31, 23, 59, 59, 250);
  const calendar = calendarAt(initial);
  assert.equal(calendar.timers[0].delay, 750);
  calendar.advance(new Date(2025, 0, 1));
  assert.equal(calendar.elements.month.textContent, 'January 2025');
  assert.equal(numberedCells(calendar)[0].attributes['aria-current'], 'date');
  assert.equal(calendar.timers.length, 1);

  const browsing = calendarAt(initial);
  browsing.click('previous');
  browsing.advance(new Date(2025, 0, 1));
  assert.equal(browsing.elements.month.textContent, 'November 2024');
});

test('preview closes on Escape or blur without loading Zebar', () => {
  const preview = calendarAt(new Date(2024, 1, 1), { tauri: true });
  preview.event('keydown', { key: 'Enter' });
  assert.equal(preview.elements.calendar.hidden, false);
  preview.event('keydown', { key: 'Escape' });
  assert.equal(preview.elements.calendar.hidden, true);
  assert.equal(preview.imports, 0);

  const browser = calendarAt(new Date(2024, 1, 1), { search: '' });
  browser.event('blur');
  assert.equal(browser.elements.calendar.hidden, true);
  assert.equal(browser.imports, 0);
});

test('Zebar closes its Tauri window once on Escape or blur', async () => {
  for (const event of ['blur', 'keydown']) {
    const widget = calendarAt(new Date(2024, 1, 1), { search: '', tauri: true });
    widget.event(event, { key: 'Escape' });
    widget.event('blur');
    for (let i = 0; i < 3 && !widget.closes; i++) await new Promise(setImmediate);
    assert.equal(widget.imports, 1);
    assert.equal(widget.closes, 1);
    assert.equal(widget.elements.calendar.hidden, false);
  }
});

test('announces itself and closes when the date pill toggles it', async () => {
  const widget = calendarAt(new Date(2024, 1, 1), { search: '', tauri: true });
  const types = () => widget.channel.messages.map(message => message.type);
  assert.deepEqual(types(), ['opened']);
  widget.channel.onmessage({ data: { type: 'status' } });
  assert.deepEqual(types(), ['opened', 'opened']);
  widget.channel.onmessage({ data: { type: 'close' } });
  for (let i = 0; i < 3 && !widget.closes; i++) await new Promise(setImmediate);
  assert.equal(widget.closes, 1);
  widget.channel.onmessage({ data: { type: 'status' } });
  assert.deepEqual(types(), ['opened', 'opened', 'closed']);
});
