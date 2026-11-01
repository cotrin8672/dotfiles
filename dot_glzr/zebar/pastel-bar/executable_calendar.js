const ROW = 32; // px per week, matches .week in calendar.css
const VISIBLE = 6;
const WEEKS = 42; // bounded buffer of 294 day cells
const HOME = 18; // buffer row placed at the top after recentring
const MARGIN = 10; // recentre once scrolling settles this close to either end
const monthLabel = document.getElementById('month');
const weeks = document.getElementById('weeks');
const calendar = document.querySelector('.calendar');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const fullDate = new Intl.DateTimeFormat('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' });
let start; // Sunday, at noon, of the first buffered week
let cells = [];
let focusKey = null;
let anchor = null; // where a button or key is scrolling to, so repeated presses accumulate

const at = (year, month, day) => new Date(year, month, day, 12);
const addDays = (date, days) => at(date.getFullYear(), date.getMonth(), date.getDate() + days);
const weekOf = date => addDays(date, -date.getDay());
const monthKey = date => date.getFullYear() * 12 + date.getMonth();
// Noon dates keep a DST hour from changing the rounded week count.
const rowOf = date => Math.round((weekOf(date) - start) / 6048e5);
const topRow = () => weeks.scrollTop / ROW;
const inside = row => row >= 1 && row <= WEEKS - VISIBLE - 1;
// The month owning the Wednesday of the third visible week: a month takes the heading once its first week reaches the top.
const middle = () => addDays(start, Math.round(topRow() + 2) * 7 + 3);

function build(first) {
  start = first;
  const today = new Date();
  const rows = [];
  cells = [];
  for (let week = 0; week < WEEKS; week++) {
    const row = document.createElement('div');
    row.className = 'week';
    row.setAttribute('role', 'row');
    for (let weekday = 0; weekday < 7; weekday++) {
      const date = addDays(start, week * 7 + weekday);
      const day = document.createElement('span');
      const isToday = date.getFullYear() === today.getFullYear() && date.getMonth() === today.getMonth() && date.getDate() === today.getDate();
      day.className = isToday ? 'day today' : 'day';
      day.textContent = String(date.getDate());
      day.setAttribute('role', 'cell');
      day.setAttribute('aria-label', fullDate.format(date));
      if (isToday) day.setAttribute('aria-current', 'date');
      cells.push({ day, key: monthKey(date) });
      row.append(day);
    }
    rows.push(row);
  }
  weeks.replaceChildren(...rows);
  focusKey = null;
}

function update() {
  const date = middle();
  const key = monthKey(date);
  if (key === focusKey) return;
  focusKey = key;
  monthLabel.textContent = date.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
  for (const cell of cells) cell.day.classList.toggle('is-outside', cell.key !== key);
}

function recenter(force) {
  const top = topRow();
  if (!force && top >= MARGIN && top <= WEEKS - VISIBLE - MARGIN) return;
  const shift = Math.round(top) - HOME;
  if (!shift) return;
  const next = weeks.scrollTop - shift * ROW; // the same dates stay under the same pixels
  build(addDays(start, shift * 7));
  weeks.scrollTop = next;
  update();
}

function go(date, smooth) {
  let row = rowOf(date);
  if (!inside(row)) { recenter(true); row = rowOf(date); }
  if (!inside(row)) {
    // Too far to scroll through: rebuild around the target and jump.
    build(addDays(weekOf(date), -HOME * 7));
    row = HOME;
    smooth = false;
  }
  smooth = smooth && !reducedMotion.matches;
  anchor = smooth ? date : null;
  if (smooth) weeks.scrollTo({ top: row * ROW, behavior: 'smooth' });
  else weeks.scrollTop = row * ROW;
  update();
}

function step(months) {
  const base = anchor ?? middle();
  go(at(base.getFullYear(), base.getMonth() + months, 1), true);
}
function scrollWeeks(count) {
  go(addDays(weekOf(anchor ?? addDays(start, Math.round(topRow()) * 7)), count * 7), true);
}
function showToday() {
  const today = new Date();
  go(at(today.getFullYear(), today.getMonth(), 1), true);
}

document.getElementById('previous').addEventListener('click', () => step(-1));
document.getElementById('next').addEventListener('click', () => step(1));
document.getElementById('today').addEventListener('click', showToday);
weeks.addEventListener('scroll', () => {
  const top = topRow();
  if (top < 1 || top > WEEKS - VISIBLE - 1) recenter(true); // momentum reached the end of the buffer
  update();
});
weeks.addEventListener('scrollend', () => { anchor = null; recenter(false); });
weeks.addEventListener('wheel', event => {
  if (!Number.isFinite(event.deltaY) || !event.deltaY) return;
  event.preventDefault();
  if (event.deltaMode || Math.abs(event.deltaY) >= 40) {
    scrollWeeks(Math.sign(event.deltaY));
  } else {
    anchor = null;
    weeks.scrollTop += Math.max(-ROW, Math.min(ROW, event.deltaY * .4));
  }
}, { passive: false });

function refreshAtMidnight() {
  const now = new Date();
  const midnight = new Date(now);
  midnight.setHours(24, 0, 0, 0);
  setTimeout(() => {
    const current = new Date();
    const following = focusKey === monthKey(now);
    build(start);
    if (following && monthKey(current) !== monthKey(now)) go(at(current.getFullYear(), current.getMonth(), 1), false);
    else update();
    refreshAtMidnight();
  }, midnight - now);
}

const preview = new URLSearchParams(location.search).has('preview') || !window.__TAURI_INTERNALS__;
const channel = new BroadcastChannel('pastel-bar-calendar');
let visible = preview;
let closing = false;
let generation = 0;
let nativeWindow;
const nativeReady = preview ? Promise.resolve(null) : import('./vendor/zebar.js').then(async ({ currentWidget }) => {
  nativeWindow = currentWidget().window.tauri;
  await nativeWindow.setTitle('Pastel Calendar');
  await nativeWindow.hide();
  await nativeWindow.setIgnoreCursorEvents(true);
  await nativeWindow.onCloseRequested(event => { event.preventDefault(); close(); });
  channel.postMessage({ type: 'ready' });
  return nativeWindow;
}).catch(error => { channel.postMessage({ type: 'failed' }); console.error(error); return null; });

async function show(position) {
  if (!Number.isFinite(position?.x) || !Number.isFinite(position?.y)) return;
  const ticket = ++generation;
  visible = true;
  closing = false;
  const target = await nativeReady;
  if (ticket !== generation || (!preview && !target)) return;
  try {
    if (target) {
      await target.setPosition({ type: 'Logical', x: position.x, y: position.y });
      if (ticket !== generation) return;
      await target.setIgnoreCursorEvents(false);
    }
    calendar.classList.remove('is-closing');
    calendar.inert = false;
    calendar.hidden = false;
    const today = new Date();
    go(at(today.getFullYear(), today.getMonth(), 1), false);
    if (target) {
      await target.show();
      if (ticket !== generation) return;
    }
    if (ticket === generation) channel.postMessage({ type: 'opened' });
  } catch (error) {
    if (ticket !== generation) return;
    visible = false;
    calendar.hidden = true;
    calendar.inert = true;
    if (target) {
      await target.setIgnoreCursorEvents(true).catch(() => {});
      await target.hide().catch(() => {});
    }
    channel.postMessage({ type: 'closed' });
    console.error(error);
  }
}
channel.onmessage = ({ data }) => {
  if (data?.type === 'close') close();
  if (data?.type === 'open') show(data);
  if (data?.type === 'status') {
    nativeReady.then(target => {
      channel.postMessage({ type: preview || target ? 'ready' : 'failed' });
      if (visible && !closing) channel.postMessage({ type: 'opened' });
    });
  }
};
if (preview) channel.postMessage({ type: 'opened' });
else channel.postMessage({ type: 'preparing' });
async function close() {
  if (!visible || closing) return;
  const ticket = ++generation;
  visible = false;
  closing = true;
  channel.postMessage({ type: 'closed' });
  calendar.inert = true;
  calendar.classList.add('is-closing');
  try {
    const target = await nativeReady;
    if (target) await target.setIgnoreCursorEvents(true);
    await new Promise(resolve => setTimeout(resolve, reducedMotion.matches ? 0 : 110));
    if (ticket !== generation) return;
    if (target) await target.hide();
    if (ticket !== generation) return;
    calendar.hidden = true;
    closing = false;
  } catch (error) {
    if (ticket !== generation) return;
    visible = true; closing = false;
    calendar.inert = false;
    calendar.classList.remove('is-closing');
    nativeWindow?.setIgnoreCursorEvents(false).catch(() => {});
    channel.postMessage({ type: 'opened' });
    console.error(error);
  }
}
const keys = { ArrowUp: () => scrollWeeks(-1), ArrowDown: () => scrollWeeks(1), PageUp: () => step(-1), PageDown: () => step(1), Home: showToday };
window.addEventListener('keydown', event => {
  if (event.key === 'Escape') close();
  else if (keys[event.key] && !closing) {
    event.preventDefault();
    keys[event.key]();
  }
});
// WebView focus can briefly change while showing; only the native window losing focus closes the popup.
window.addEventListener('blur', () => { if (preview) close(); });
window.addEventListener('beforeunload', () => { channel.postMessage({ type: 'gone' }); channel.close(); });

const today = new Date();
calendar.hidden = !preview;
build(addDays(weekOf(at(today.getFullYear(), today.getMonth(), 1)), -HOME * 7));
weeks.scrollTop = HOME * ROW;
update();
refreshAtMidnight();
