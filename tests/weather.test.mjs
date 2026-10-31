import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { dirname, join, resolve, sep } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { calendarPlacement, formatDate, formatWeather } from '../dot_glzr/zebar/pastel-bar/executable_weather.js';

test('formats English dates and 24-hour times across midnight and year boundaries', () => {
  assert.deepEqual(formatDate(new Date(2026, 11, 31, 23, 59)), { date: 'Thu, Dec 31', time: '23:59' });
  assert.deepEqual(formatDate(new Date(2027, 0, 1, 0, 0)), { date: 'Fri, Jan 1', time: '00:00' });
  assert.deepEqual(formatDate(new Date(2026, 9, 31, 10, 4)), { date: 'Sat, Oct 31', time: '10:04' });
});

test('maps every Zebar weather status and handles missing or invalid readings', () => {
  for (const [status, condition, icon] of [
    ['clear_day', 'Clear', 'sun'], ['clear_night', 'Clear', 'moon'],
    ['cloudy_day', 'Cloudy', 'cloud-sun'], ['cloudy_night', 'Cloudy', 'cloud-moon'],
    ['light_rain_day', 'Light rain', 'rain'], ['light_rain_night', 'Light rain', 'rain'],
    ['heavy_rain_day', 'Heavy rain', 'rain'], ['heavy_rain_night', 'Heavy rain', 'rain'],
    ['snow_day', 'Snow', 'snow'], ['snow_night', 'Snow', 'snow'],
    ['thunder_day', 'Thunder', 'thunder'], ['thunder_night', 'Thunder', 'thunder'],
  ]) {
    assert.deepEqual(formatWeather({ status, celsiusTemp: 19.6 }), { temperature: '20°C', condition, icon });
  }
  assert.deepEqual(formatWeather(null), { temperature: '--°C', condition: 'Unavailable', icon: 'cloud' });
  assert.deepEqual(formatWeather({ status: 'clear_day', celsiusTemp: NaN }), { temperature: '--°C', condition: 'Clear', icon: 'sun' });
  assert.deepEqual(formatWeather({ status: '__proto__', celsiusTemp: -0.1 }), { temperature: '0°C', condition: 'Unknown', icon: 'cloud' });
  assert.equal(formatWeather({ status: 'snow_day', celsiusTemp: -4.8 }).temperature, '-5°C');
});

test('places the calendar at the current right edge using logical pixels', () => {
  assert.deepEqual(calendarPlacement({ x: 2000, y: 16 }, { width: 400, height: 68 }, 2), {
    anchor: 'top_left', offsetX: '945px', offsetY: '50px', width: '255px', height: '275px',
    monitorSelection: { type: 'primary' }, dockToEdge: { enabled: false, edge: 'top', windowMargin: '0px' },
  });
  assert.equal(calendarPlacement({ x: 1600, y: 16 }, { width: 400, height: 68 }, 2).offsetX, '745px');
  assert.throws(() => calendarPlacement({ x: NaN, y: 0 }, { width: 200, height: 34 }, 1));
  assert.throws(() => calendarPlacement({ x: 0, y: 0 }, { width: 200, height: 34 }, 0));
});

test('renders preview without Zebar and handles provider updates and calendar clicks', async t => {
  const browser = [
    process.env.WEATHER_TEST_BROWSER,
    join(process.env['ProgramFiles(x86)'] || 'C:/Program Files (x86)', 'Microsoft/Edge/Application/msedge.exe'),
    join(process.env.ProgramFiles || 'C:/Program Files', 'Google/Chrome/Application/chrome.exe'),
    '/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/google-chrome',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  ].find(path => path && existsSync(path));
  if (!browser) return t.skip('Chromium or Edge is required for the browser preview test');

  const widget = resolve(dirname(fileURLToPath(import.meta.url)), '../dot_glzr/zebar/pastel-bar');
  const requests = [];
  const server = createServer((request, response) => {
    const url = new URL(request.url, 'http://localhost');
    requests.push(url.pathname);
    const files = { '/weather.html': ['weather.html.tmpl', 'text/html'], '/weather.css': ['weather.css.tmpl', 'text/css'], '/weather.js': ['executable_weather.js', 'text/javascript'] };
    if (url.pathname === '/vendor/zebar.js') {
      response.writeHead(200, { 'Content-Type': 'text/javascript' });
      response.end(`
        let positionCalls = 0;
        export function currentWidget() { return { window: { tauri: {
          setTitle: async title => { document.documentElement.dataset.title = title; },
          clearEffects: async () => {},
          outerPosition: async () => {
            if (location.search.includes('fallback')) throw Error('position unavailable');
            return { x: positionCalls++ ? 1600 : 2000, y: 16 };
          },
          outerSize: async () => ({ width: 400, height: 68 }),
        } } }; }
        export function createProviderGroup(config) {
          document.documentElement.dataset.provider = JSON.stringify(config);
          return {
            outputMap: { weather: null },
            onOutput: callback => setTimeout(() => callback({ weather: { celsiusTemp: 12.6, status: 'light_rain_day' } }), 1),
            onError: callback => { if (location.search.includes('failure')) setTimeout(() => callback({ weather: 'offline' }), 2); },
            stopAll: async () => {},
          };
        }
        export async function startWidget(name, placement, args) {
          if (location.search.includes('launchfailure')) throw Error('launch unavailable');
          const root = document.documentElement;
          root.dataset.calls = (root.dataset.calls || '') + [name, placement.offsetX, placement.offsetY, placement.width, placement.height, placement.monitorSelection.type, placement.dockToEdge.enabled, Object.keys(args).length].join(',') + ';';
        }
        export async function startWidgetPreset(name, preset) { document.documentElement.dataset.fallback = name + ',' + preset; }
      `);
    } else if (files[url.pathname]) {
      const [file, contentType] = files[url.pathname];
      let content = readFileSync(join(widget, file), 'utf8');
      if (url.pathname === '/weather.html' && url.searchParams.has('midnight')) {
        content = content.replace('<head>', `<head><script>
          const NativeDate = Date;
          let now = new NativeDate(2026, 11, 31, 23, 59, 59, 990).getTime();
          Date = class extends NativeDate {
            constructor(...args) { super(...(args.length ? args : [now])); }
            static now() { return now; }
          };
          const nativeTimeout = window.setTimeout;
          let advanced = false;
          window.setTimeout = (callback, delay, ...args) => {
            if (callback.name === 'updateClock' && !advanced) {
              advanced = true;
              document.documentElement.dataset.delay = delay;
              now += delay;
              return nativeTimeout(callback, 1, ...args);
            }
            return nativeTimeout(callback, delay, ...args);
          };
        </script>`);
      }
      if (url.pathname === '/weather.html' && !url.searchParams.has('preview')) {
        content = content.replace('</body>', `<script>addEventListener('load', () => setTimeout(() => { const button = document.getElementById('open-calendar'); button.click(); setTimeout(() => button.click(), 20); }, 30));</script></body>`);
      }
      response.writeHead(200, { 'Content-Type': contentType });
      response.end(content);
    } else {
      response.writeHead(404).end();
    }
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));

  const run = promisify(execFile);
  const profile = mkdtempSync(join(tmpdir(), 'pastel-weather-test-'));
  t.after(() => {
    const path = resolve(profile);
    assert.ok(path.startsWith(resolve(tmpdir()) + sep) && path.slice(path.lastIndexOf(sep) + 1).startsWith('pastel-weather-test-'));
    rmSync(path, { recursive: true, force: true });
  });
  const render = async query => (await run(browser, [
    '--headless', '--disable-gpu', '--disable-extensions', '--disable-background-networking', '--no-first-run', '--no-sandbox',
    '--force-device-scale-factor=2', `--user-data-dir=${profile}`, '--virtual-time-budget=1000', '--dump-dom',
    `http://127.0.0.1:${server.address().port}/weather.html${query}`,
  ], { timeout: 30000, maxBuffer: 1024 * 1024 })).stdout;

  const preview = await render('?preview');
  assert.match(preview, /data-preview=""/);
  assert.match(preview, /id="temperature">19°C</);
  assert.match(preview, /id="condition">Cloudy</);
  assert.match(preview, /id="weather"[^>]*title="Cloudy, 19°C"/);
  assert.match(preview, /id="date">\w{3}, \w{3} \d{1,2}</);
  assert.match(preview, /id="time">\d{2}:\d{2}</);
  assert.ok(!requests.includes('/vendor/zebar.js'));

  const midnight = await render('?preview&midnight');
  assert.match(midnight, /data-delay="10"/);
  assert.match(midnight, /id="date">Fri, Jan 1</);
  assert.match(midnight, /id="time">00:00</);

  const live = await render('');
  assert.match(live, /data-title="Pastel Bar - Weather"/);
  assert.match(live, /data-provider="\{&quot;weather&quot;:\{&quot;type&quot;:&quot;weather&quot;,&quot;refreshInterval&quot;:3600000\}\}"/);
  assert.match(live, /id="temperature">13°C</);
  assert.match(live, /id="condition">Light rain</);
  // The second, quick click must not open a duplicate calendar while the first is starting.
  assert.match(live, /data-calls="calendar,945px,50px,255px,275px,primary,false,0;"/);

  const failure = await render('?failure&fallback');
  assert.match(failure, /id="temperature">--°C</);
  assert.match(failure, /id="condition">Unavailable</);
  assert.match(failure, /data-fallback="calendar,default"/);

  const launchFailure = await render('?launchfailure');
  assert.match(launchFailure, /data-fallback="calendar,default"/);
});
