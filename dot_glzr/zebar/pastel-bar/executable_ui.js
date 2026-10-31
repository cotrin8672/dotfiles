(() => {
  'use strict';
  const state = { hardware: {}, activeWindow: {}, ai: {}, connected: false };
  const percent = value => typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= 100;
  const display = value => percent(value) ? Math.round(value) + '%' : '--';
  const date = value => {
    const parsed = new Date(value);
    return value && Number.isFinite(parsed.getTime()) ? parsed.toLocaleString('ja-JP', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : '不明';
  };

  const windowTitle = document.getElementById('window-title');
  const windowTitleText = document.getElementById('window-title-text');
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
  let titleAnimation = null, titleOverflow = 0, disposed = false;
  function stopWindowTitleScroll() {
    titleAnimation?.cancel();
    titleAnimation = null;
    windowTitle.classList.toggle('is-scrolling', false);
  }
  function updateWindowTitleScroll() {
    if (disposed || document.hidden || reducedMotion.matches || !windowTitle.clientWidth) {
      stopWindowTitleScroll();
      return;
    }
    const overflow = Math.max(0, windowTitleText.scrollWidth - windowTitle.clientWidth);
    if (titleAnimation && titleOverflow === overflow) return;
    stopWindowTitleScroll();
    if (!overflow) return;
    titleOverflow = overflow;
    windowTitle.classList.toggle('is-scrolling', true);
    const travel = overflow / 22 * 1000;
    const duration = 2400 + travel;
    titleAnimation = windowTitleText.animate([
      { transform: 'translateX(0)', offset: 0 },
      { transform: 'translateX(0)', offset: 1200 / duration },
      { transform: `translateX(-${overflow}px)`, offset: (1200 + travel) / duration },
      { transform: `translateX(-${overflow}px)`, offset: 1 },
    ], { duration, iterations: Infinity, easing: 'linear' });
  }
  const titleResize = new ResizeObserver(updateWindowTitleScroll);
  titleResize.observe(windowTitle);
  titleResize.observe(windowTitleText);
  reducedMotion.addEventListener('change', updateWindowTitleScroll);
  document.addEventListener('visibilitychange', updateWindowTitleScroll);
  addEventListener('beforeunload', () => {
    disposed = true;
    stopWindowTitleScroll();
    titleResize.disconnect();
    reducedMotion.removeEventListener('change', updateWindowTitleScroll);
    document.removeEventListener('visibilitychange', updateWindowTitleScroll);
  });

  function plot(history) {
    let line = '', area = '', segment = [];
    const close = () => {
      if (!segment.length) return;
      const points = segment.map(([x, y], index) => (index ? 'L' : 'M') + x + ',' + y).join(' ');
      line += points + ' ';
      area += points + ' L' + segment.at(-1)[0] + ',22 L' + segment[0][0] + ',22 Z ';
      segment = [];
    };
    const values = Array.isArray(history) ? history.slice(-60) : [];
    values.forEach((value, index) => {
      if (!percent(value)) { close(); return; }
      segment.push([((60 - values.length + index) / 59 * 64).toFixed(2), (21 - value / 100 * 20).toFixed(2)]);
    });
    close();
    return { line, area };
  }

  function renderHardware(key, sample) {
    const element = document.getElementById(key);
    element.querySelector('.value').textContent = display(sample.usage);
    const paths = plot(sample.history);
    element.querySelector('.line').setAttribute('d', paths.line);
    element.querySelector('.area').setAttribute('d', paths.area);
    element.title = key.toUpperCase() + ': ' + display(sample.usage) + '\n' + (sample.detail || '') + (state.connected ? '' : '\n接続待ち：最後の観測値');
    element.setAttribute('aria-label', element.title);
  }

  function updateResetProgress() {
    const now = Date.now();
    document.querySelectorAll('.reset-frame').forEach(element => {
      const end = Number(element.dataset.endsAt);
      const duration = Number(element.dataset.duration);
      if (!Number.isFinite(end) || !Number.isFinite(duration) || duration <= 0) {
        element.style.setProperty('--remaining', '0%');
        element.removeAttribute('aria-valuenow');
        return;
      }
      const remaining = Math.max(0, Math.min(100, (end - now) / duration * 100));
      element.style.setProperty('--remaining', remaining + '%');
      element.setAttribute('aria-valuenow', remaining.toFixed(1));
    });
  }

  function renderProvider(key, usage) {
    const element = document.getElementById(key);
    const name = key === 'codex' ? 'Codex' : 'Claude Code';
    const stale = !state.connected || usage.status === 'stale' || usage.status === 'error';
    const windows = (Array.isArray(usage.windows) ? usage.windows : []).filter(window => percent(window.usedPercent));
    const toolTip = [
      name + (usage.plan ? ' · ' + usage.plan : ''),
      ...windows.map(window => String(window.label) + ': 残り ' + display(100 - window.usedPercent) + ' / リセット ' + date(window.resetsAt)),
      '最終取得: ' + date(usage.updatedAt),
      stale ? '更新待ち：最後の観測値を表示中' : '',
      usage.message || ''
    ].filter(Boolean).join('\n');
    element.title = toolTip;
    element.classList.toggle('stale', stale);
    const container = element.querySelector('.quotas');
    // Preserve the DOM between snapshots, including native tooltip targets.
    const signature = JSON.stringify(windows);
    if (container.dataset.signature === signature) return;
    container.dataset.signature = signature;
    container.replaceChildren();
    if (!windows.length) {
      const empty = document.createElement('span');
      empty.className = 'empty';
      empty.textContent = '--';
      empty.setAttribute('aria-label', name + ' 使用状況を取得できません');
      container.append(empty);
    }
    windows.forEach(window => {
      const row = document.createElement('div');
      row.className = 'quota';
      const track = document.createElement('span');
      track.className = 'track';
      track.setAttribute('role', 'progressbar');
      track.setAttribute('aria-label', name + ' ' + window.label + ' 残り');
      track.setAttribute('aria-valuemin', '0');
      track.setAttribute('aria-valuemax', '100');
      track.setAttribute('aria-valuenow', 100 - window.usedPercent);
      const fill = document.createElement('span');
      fill.className = 'fill';
      fill.style.width = (100 - window.usedPercent) + '%';
      track.append(fill);
      const value = document.createElement('span');
      value.className = 'quota-value';
      value.textContent = display(100 - window.usedPercent);
      const end = new Date(window.resetsAt || NaN);
      const validReset = Number.isFinite(end.getTime());
      const seconds = Number.isFinite(window.durationSeconds) && window.durationSeconds > 0
        ? window.durationSeconds : { '5h': 18000, '1w': 604800 }[window.label];
      const reset = document.createElement('time');
      reset.className = 'reset-time';
      reset.title = window.label + ' リセット: ' + date(window.resetsAt);
      if (validReset) {
        reset.dateTime = end.toISOString();
        reset.textContent = end.toLocaleString('ja-JP', window.id === '5h' || seconds < 86400
          ? { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }
          : { month: 'numeric', day: 'numeric' });
      } else {
        reset.textContent = '--';
      }
      const frame = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      frame.classList.add('reset-frame');
      frame.setAttribute('viewBox', '0 0 108 11');
      frame.dataset.endsAt = String(end.getTime());
      frame.dataset.duration = String((seconds || 0) * 1000);
      frame.setAttribute('role', 'progressbar');
      frame.setAttribute('aria-label', name + ' ' + window.label + ' リセットまでの残り時間 / 次のリセット: ' + date(window.resetsAt));
      frame.setAttribute('aria-valuemin', '0');
      frame.setAttribute('aria-valuemax', '100');
      for (const className of ['frame-base', 'frame-progress']) {
        const outline = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
        const inset = .75;
        outline.setAttribute('class', className);
        outline.setAttribute('x', inset);
        outline.setAttribute('y', inset);
        outline.setAttribute('width', 108 - inset * 2);
        outline.setAttribute('height', 11 - inset * 2);
        outline.setAttribute('rx', 3 - inset);
        frame.append(outline);
      }
      row.append(track, reset, value, frame);
      container.append(row);
    });
    updateResetProgress();
  }

  function update(partial) {
    if (typeof partial.connected === 'boolean') state.connected = partial.connected;
    for (const group of ['hardware', 'activeWindow', 'ai']) {
      if (partial[group]) Object.assign(state[group], partial[group]);
    }
    document.body.classList.toggle('disconnected', !state.connected);
    for (const key of ['cpu', 'gpu', 'ram']) renderHardware(key, state.hardware[key] || {});
    const active = state.activeWindow;
    const pill = document.getElementById('active-window');
    const title = active.title || 'Desktop';
    if (windowTitleText.textContent !== title) {
      stopWindowTitleScroll();
      windowTitleText.textContent = title;
    }
    pill.title = [active.app, active.title].filter(Boolean).join('\n');
    const icon = document.getElementById('app-icon');
    const validIcon = typeof active.icon === 'string' && /^data:image\/png;base64,[A-Za-z0-9+/=]+$/.test(active.icon);
    if (validIcon && icon.getAttribute('src') !== active.icon) icon.src = active.icon;
    icon.hidden = !validIcon;
    updateWindowTitleScroll();
    for (const key of ['codex', 'claude']) renderProvider(key, state.ai[key] || {});
  }
  document.getElementById('app-icon').addEventListener('error', event => {
    event.target.hidden = true;
  });
  window.pastelBar = { update };
  update({});
  setInterval(updateResetProgress, 1000);

  if (new URLSearchParams(location.search).has('preview')) {
    const wave = (base, amplitude, phase) => Array.from({ length: 60 }, (_, index) =>
      Math.max(0, Math.min(100, base + Math.sin(index * .44 + phase) * amplitude + Math.sin(index * 1.03) * amplitude * .5)));
    const now = new Date().toISOString();
    const resetAfter = hours => new Date(Date.now() + hours * 60 * 60 * 1000).toISOString();
    update({
      connected: true,
      hardware: {
        cpu: { usage: 28, history: wave(28, 15, 0), detail: 'CPU usage | Last 60 seconds' },
        gpu: { usage: 34, history: wave(34, 18, 2), detail: 'NVIDIA GPU | VRAM 2.1 / 4 GiB' },
        ram: { usage: 62, history: wave(62, 5, 4), detail: 'RAM 19.8 / 32 GiB' }
      },
      activeWindow: { title: 'A Calm Internet', app: 'Firefox', icon: null },
      ai: {
        codex: { status: 'ok', plan: 'pro', windows: [{ id: '1w', label: '1w', usedPercent: 28, resetsAt: resetAfter(96) }], updatedAt: now },
        claude: { status: 'ok', plan: 'max', windows: [{ id: '5h', label: '5h', usedPercent: 36, resetsAt: resetAfter(2) }, { id: '1w', label: '1w', usedPercent: 57, resetsAt: resetAfter(120) }], updatedAt: now }
      }
    });
  }
})();
