// All three pills share sanitized snapshots from one collector.
if (!new URLSearchParams(location.search).has('preview')) {
  const { currentWidget, shellSpawn } = await import('./vendor/zebar.js');
  const widget = currentWidget();
  const group = widget.name;
  document.documentElement.dataset.group = group;
  const labels = { bar: 'Spacer', hardware: 'Hardware', active: 'Window', ai: 'AI' };
  await widget.window.tauri.setTitle('Pastel Bar - ' + labels[group]);
  await widget.window.tauri.clearEffects();

  if (group === 'bar') {
    await widget.window.tauri.setIgnoreCursorEvents(true);
  } else {
    const channel = new BroadcastChannel('pastel-bar-snapshots');
    const directory = widget.htmlPath.replace(/[\\/][^\\/]+$/, '');
    let child, retry, heartbeat, latest;
    let stopped = false;
    let lastData = 0;
    const disconnected = () => window.pastelBar.update({ connected: false });
    const update = state => {
      latest = state;
      lastData = Date.now();
      window.pastelBar.diagnostics = state.appearance;
      window.pastelBar.update(state);
    };
    channel.onmessage = ({ data }) => {
      if (data.type === 'snapshot') update(data.state);
      if (data.type === 'request' && group === 'hardware' && latest) channel.postMessage({ type: 'snapshot', state: latest });
    };
    channel.postMessage({ type: 'request' });
    async function start() {
      if (stopped) return;
      try {
        child = await shellSpawn('powershell.exe', [
          '-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
          '-File', directory + '\\collect.ps1',
        ]);
        const helper = child;
        helper.onStdout(line => {
          try {
            const state = JSON.parse(line);
            update(state);
            channel.postMessage({ type: 'snapshot', state });
          } catch { /* The next snapshot is self-contained. */ }
        });
        helper.onStderr(line => {
          window.pastelBar.helperError = String(line).slice(0, 600);
          disconnected();
        });
        helper.onExit(() => {
          clearInterval(heartbeat);
          disconnected();
          if (!stopped) retry = setTimeout(start, 15000);
        });
        clearInterval(heartbeat);
        const ping = () => helper.write('{"heartbeat":true}\n').catch(disconnected);
        heartbeat = setInterval(ping, 5000);
        ping();
      } catch (error) {
        window.pastelBar.helperError = String(error);
        disconnected();
        if (!stopped) retry = setTimeout(start, 15000);
      }
    }
    const watchdog = setInterval(() => {
      if (Date.now() - lastData > 10000) disconnected();
    }, 5000);
    addEventListener('beforeunload', () => {
      stopped = true;
      clearTimeout(retry);
      clearInterval(heartbeat);
      clearInterval(watchdog);
      channel.close();
      child?.write('{"stop":true}\n').catch(() => {});
    });
    if (group === 'hardware') await start();
  }
}
