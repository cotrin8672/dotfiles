const params = new URLSearchParams(location.search);
const preview = params.has('preview');
const pill = document.getElementById('spotify');
const track = document.getElementById('track');
const trackTitle = document.getElementById('track-title');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const buttons = Object.fromEntries(['previous', 'togglePlayPause', 'next'].map(id => [id, document.getElementById(id)]));
let open = false;
let media = null;
let nativeWindow = null;
let titleUpdates = Promise.resolve();
let cursorUpdates = Promise.resolve();
let provider;
let channel;
let missedSnapshots = 0;
let titleAnimation = null;
let titleOverflow = 0;
let disposed = false;

function stopTitleScroll() {
  titleAnimation?.cancel();
  titleAnimation = null;
  track.classList.toggle('is-scrolling', false);
}

function updateTitleScroll() {
  if (disposed || !open || document.hidden || reducedMotion.matches) {
    stopTitleScroll();
    return;
  }
  const overflow = Math.max(0, trackTitle.scrollWidth - track.clientWidth);
  if (titleAnimation && titleOverflow === overflow) return;
  stopTitleScroll();
  if (!overflow) return;
  titleOverflow = overflow;
  track.classList.toggle('is-scrolling', true);
  const travel = overflow / 22 * 1000;
  const duration = 2400 + travel;
  titleAnimation = trackTitle.animate([
    { transform: 'translateX(0)', offset: 0 },
    { transform: 'translateX(0)', offset: 1200 / duration },
    { transform: `translateX(-${overflow}px)`, offset: (1200 + travel) / duration },
    { transform: `translateX(-${overflow}px)`, offset: 1 },
  ], { duration, iterations: Infinity, easing: 'linear' });
}

const titleResize = new ResizeObserver(updateTitleScroll);
titleResize.observe(track);
titleResize.observe(trackTitle);
reducedMotion.addEventListener('change', updateTitleScroll);
document.addEventListener('visibilitychange', updateTitleScroll);
addEventListener('beforeunload', () => {
  disposed = true;
  stopTitleScroll();
  titleResize.disconnect();
  reducedMotion.removeEventListener('change', updateTitleScroll);
  document.removeEventListener('visibilitychange', updateTitleScroll);
});

function session() {
  return Array.isArray(media?.allSessions) && media.allSessions.find(item =>
    typeof item?.sessionId === 'string' && /^(?:spotify\.exe|spotifyab\.spotifymusic_zpdnekdrzrea0!spotify)$/i.test(item.sessionId)
  );
}

function render() {
  const current = session();
  const playing = open && current?.isPlaying === true;
  pill.classList.toggle('is-visible', open);
  pill.classList.toggle('is-playing', playing);
  pill.inert = !open;
  pill.setAttribute('aria-hidden', String(!open));
  const title = typeof current?.title === 'string' && current.title.trim() || 'Spotify';
  if (trackTitle.textContent !== title) {
    stopTitleScroll();
    trackTitle.textContent = title;
  }
  track.title = title;
  updateTitleScroll();
  for (const [action, button] of Object.entries(buttons)) {
    button.disabled = !open || !current || typeof media?.[action] !== 'function' ||
      (action === 'previous' && current.isPreviousEnabled === false) ||
      (action === 'next' && current.isNextEnabled === false);
  }
  buttons.togglePlayPause.setAttribute('aria-label', playing ? 'Pause' : 'Play');
  buttons.togglePlayPause.title = playing ? 'Pause' : 'Play';
}

function syncWindow() {
  if (!nativeWindow) return;
  const visible = open;
  const safely = fn => Promise.resolve().then(fn).catch(error => console.warn('Spotify window update failed:', error));
  const update = (pending, fn) => pending.then(() => visible === open && safely(fn));
  titleUpdates = update(titleUpdates, () => nativeWindow.setTitle('Pastel Bar - Spotify' + (visible ? '' : ' Hidden')));
  cursorUpdates = update(cursorUpdates, () => nativeWindow.setIgnoreCursorEvents(!visible));
  if (!visible) {
    safely(() => nativeWindow.setIgnoreCursorEvents(true)).then(() => { if (open) syncWindow(); });
  }
}

function setOpen(value) {
  if (open === value) return;
  open = value;
  render();
  if (preview) document.title = 'Pastel Bar - Spotify' + (open ? '' : ' Hidden');
  syncWindow();
}

function setMedia(output) {
  media = output;
  render();
}

for (const [action, button] of Object.entries(buttons)) {
  button.addEventListener('click', () => {
    const current = session();
    if (!open || !current || button.disabled || typeof media?.[action] !== 'function') return;
    try {
      Promise.resolve(media[action]({ sessionId: current.sessionId }))
        .catch(error => console.warn('Spotify control failed:', error));
    } catch (error) {
      console.warn('Spotify control failed:', error);
    }
  });
}

if (preview) {
  const state = params.get('preview');
  const titles = ['Midnight Drive', 'Quiet Morning'];
  let index = 0;
  const fake = { sessionId: 'Spotify.exe', title: titles[index], isPlaying: state !== 'paused' };
  const output = {
    allSessions: state === 'no-session' ? [] : [fake],
    previous: () => { index = (index + titles.length - 1) % titles.length; fake.title = titles[index]; render(); },
    next: () => { index = (index + 1) % titles.length; fake.title = titles[index]; render(); },
    togglePlayPause: () => { fake.isPlaying = !fake.isPlaying; render(); },
  };
  setMedia(output);
  setOpen(state !== 'closed');
} else {
  channel = new BroadcastChannel('pastel-bar-snapshots');
  channel.onmessage = ({ data }) => {
    if (data?.type === 'snapshot' && typeof data.state?.spotifyOpen === 'boolean') {
      missedSnapshots = 0;
      setOpen(data.state.spotifyOpen);
    }
  };
  channel.postMessage({ type: 'request' });
  // The collector reports every 400ms; without it nobody can tell that Spotify closed, so hide and disable.
  const watchdog = setInterval(() => {
    if (++missedSnapshots < 5) return;
    setOpen(false);
    channel.postMessage({ type: 'request' });
  }, 1000);
  addEventListener('beforeunload', () => {
    clearInterval(watchdog);
    channel.close();
    provider?.stop().catch(error => console.warn('Spotify provider cleanup failed:', error));
  });

  try {
    const zebar = await import('./vendor/zebar.js');
    nativeWindow = zebar.currentWidget().window.tauri;
    syncWindow();
    Promise.resolve().then(() => nativeWindow.clearEffects()).catch(error => console.warn('Spotify window initialization failed:', error));
    provider = zebar.createProvider({ type: 'media' });
    provider.onOutput(setMedia);
    provider.onError(() => setMedia(null));
    setMedia(provider.output);
  } catch (error) {
    console.warn('Spotify initialization failed:', error);
  }
}
