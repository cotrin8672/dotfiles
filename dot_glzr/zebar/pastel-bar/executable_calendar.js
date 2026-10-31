const monthLabel = document.getElementById('month');
const days = document.getElementById('days');
const calendar = document.querySelector('.calendar');
const view = new Date();
view.setHours(12, 0, 0, 0);
view.setDate(1);

function render() {
  const today = new Date();
  const last = new Date(view);
  last.setMonth(last.getMonth() + 1, 0);
  monthLabel.textContent = view.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });

  const rows = [];
  for (let week = 0; week < 6; week++) {
    const row = document.createElement('tr');
    for (let weekday = 0; weekday < 7; weekday++) {
      const cell = document.createElement('td');
      const day = week * 7 + weekday - view.getDay() + 1;
      if (day > 0 && day <= last.getDate()) {
        const label = document.createElement('span');
        label.textContent = String(day);
        if (view.getFullYear() === today.getFullYear() && view.getMonth() === today.getMonth() && day === today.getDate()) {
          label.className = 'today';
          label.setAttribute('aria-current', 'date');
        }
        cell.append(label);
      }
      row.append(cell);
    }
    rows.push(row);
  }
  days.replaceChildren(...rows);
}

document.getElementById('previous').addEventListener('click', () => { view.setMonth(view.getMonth() - 1); render(); });
document.getElementById('next').addEventListener('click', () => { view.setMonth(view.getMonth() + 1); render(); });

function refreshAtMidnight() {
  const now = new Date();
  const midnight = new Date(now);
  midnight.setHours(24, 0, 0, 0);
  setTimeout(() => {
    const current = new Date();
    if (view.getFullYear() === now.getFullYear() && view.getMonth() === now.getMonth()) {
      view.setFullYear(current.getFullYear(), current.getMonth(), 1);
    }
    render();
    refreshAtMidnight();
  }, midnight - now);
}

const preview = new URLSearchParams(location.search).has('preview') || !window.__TAURI_INTERNALS__;
const channel = new BroadcastChannel('pastel-bar-calendar');
channel.onmessage = ({ data }) => {
  if (data?.type === 'close') close();
  if (data?.type === 'status' && !closing) channel.postMessage({ type: 'opened' });
};
channel.postMessage({ type: 'opened' });
let closing = false;
function close() {
  if (closing) return;
  closing = true;
  channel.postMessage({ type: 'closed' });
  if (preview) {
    calendar.hidden = true;
  } else {
    import('./vendor/zebar.js')
      .then(({ currentWidget }) => currentWidget().window.tauri.close())
      .catch(error => { closing = false; channel.postMessage({ type: 'opened' }); console.error(error); });
  }
}
window.addEventListener('keydown', event => { if (event.key === 'Escape') close(); });
window.addEventListener('blur', close);

render();
refreshAtMidnight();
