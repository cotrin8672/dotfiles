const dateFormatter = new Intl.DateTimeFormat('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
const timeFormatter = new Intl.DateTimeFormat('en-US', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });

export function formatDate(date) {
  return { date: dateFormatter.format(date), time: timeFormatter.format(date) };
}

const weatherStates = {
  clear_day: ['Clear', 'sun'], clear_night: ['Clear', 'moon'],
  cloudy_day: ['Cloudy', 'cloud-sun'], cloudy_night: ['Cloudy', 'cloud-moon'],
  light_rain_day: ['Light rain', 'rain'], light_rain_night: ['Light rain', 'rain'],
  heavy_rain_day: ['Heavy rain', 'rain'], heavy_rain_night: ['Heavy rain', 'rain'],
  snow_day: ['Snow', 'snow'], snow_night: ['Snow', 'snow'],
  thunder_day: ['Thunder', 'thunder'], thunder_night: ['Thunder', 'thunder'],
};

export function formatWeather(weather) {
  if (!weather) return { temperature: '--°C', condition: 'Unavailable', icon: 'cloud' };
  const [condition, icon] = Object.hasOwn(weatherStates, weather.status)
    ? weatherStates[weather.status] : ['Unknown', 'cloud'];
  const temperature = Number.isFinite(weather.celsiusTemp) ? `${Math.round(weather.celsiusTemp) || 0}°C` : '--°C';
  return { temperature, condition, icon };
}

export function calendarPlacement(position, size, scale) {
  if (![position.x, position.y, size.width, size.height, scale].every(Number.isFinite) || scale <= 0 || size.width <= 0 || size.height <= 0) {
    throw new Error('Invalid weather window bounds');
  }
  return {
    anchor: 'top_left',
    offsetX: `${Math.round((position.x + size.width) / scale - 255)}px`,
    offsetY: `${Math.round((position.y + size.height) / scale + 8)}px`,
    width: '255px', height: '275px',
    monitorSelection: { type: 'primary' },
    dockToEdge: { enabled: false, edge: 'top', windowMargin: '0px' },
  };
}

if (typeof document !== 'undefined') {
  const date = document.getElementById('date');
  const time = document.getElementById('time');
  const temperature = document.getElementById('temperature');
  const condition = document.getElementById('condition');
  const weatherBox = document.getElementById('weather');
  const icon = document.getElementById('weather-icon');

  function updateClock() {
    const now = new Date();
    const formatted = formatDate(now);
    date.textContent = formatted.date;
    time.textContent = formatted.time;
    setTimeout(updateClock, 60000 - now.getSeconds() * 1000 - now.getMilliseconds());
  }
  function updateWeather(weather) {
    const formatted = formatWeather(weather);
    temperature.textContent = formatted.temperature;
    condition.textContent = formatted.condition;
    weatherBox.title = `${formatted.condition}, ${formatted.temperature}`;
    icon.setAttribute('href', '#weather-' + formatted.icon);
  }
  updateClock();

  if (new URLSearchParams(location.search).has('preview')) {
    document.documentElement.dataset.preview = '';
    updateWeather({ celsiusTemp: 19, status: 'cloudy_day' });
  } else {
    try {
      const { currentWidget, createProviderGroup, startWidget, startWidgetPreset } = await import('./vendor/zebar.js');
      const window = currentWidget().window.tauri;
      try {
        await window.setTitle('Pastel Bar - Weather');
        await window.clearEffects();
      } catch (error) {
        console.warn('Unable to set weather window appearance', error);
      }
      // Pill windows never take focus, so clicking here does not blur an open calendar: toggle it explicitly.
      const calendarChannel = new BroadcastChannel('pastel-bar-calendar');
      let calendarOpen = false, opening = false, closedAt = 0;
      calendarChannel.onmessage = ({ data }) => {
        if (data?.type === 'opened') { calendarOpen = true; opening = false; }
        if (data?.type === 'closed') { calendarOpen = false; closedAt = Date.now(); }
      };
      calendarChannel.postMessage({ type: 'status' });
      document.getElementById('open-calendar').addEventListener('click', async () => {
        if (calendarOpen) { calendarOpen = false; calendarChannel.postMessage({ type: 'close' }); return; }
        if (opening || Date.now() - closedAt < 400) return;
        opening = true;
        setTimeout(() => { opening = false; }, 1500);
        try {
          const [position, size] = await Promise.all([window.outerPosition(), window.outerSize()]);
          await startWidget('calendar', calendarPlacement(position, size, globalThis.devicePixelRatio), {});
        } catch (error) {
          try {
            await startWidgetPreset('calendar', 'default');
          } catch (fallbackError) {
            console.warn('Unable to open calendar', fallbackError);
          }
        }
      });
      const providers = createProviderGroup({ weather: { type: 'weather', refreshInterval: 3600000 } });
      providers.onOutput(({ weather }) => updateWeather(weather));
      providers.onError(() => updateWeather(null));
      updateWeather(providers.outputMap.weather);
      globalThis.addEventListener('beforeunload', () => providers.stopAll().catch(() => {}));
    } catch (error) {
      console.warn('Weather provider unavailable', error);
      updateWeather(null);
    }
  }
}
