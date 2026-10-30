# Pastel Bar

Zebar 3.3.1 on Windows. The 34px hardware, active-window and AI pills each have a transparent web view over a Windows Composition host-backdrop surface. The background and its charcoal tint (#35383D at 179/255, approximately 70%, producing roughly #25272B over black) share a rounded geometry clip with a 17px radius. A fourth Zebar window reserves 52px at the top edge and ignores mouse input. It gets the same host-backdrop surface without corner rounding and a lighter tint (#35383D at 115/255), so the wallpaper shows through behind the pills. The Windows system acrylic is not used: it becomes a flat fallback color while a window is inactive, and this spacer never activates. The pill windows do not take keyboard focus.

CPU, GPU and RAM show utilization and a 60-sample history. Hardware is sampled every second; the foreground window updates every 400ms. Percentages use regular-weight text: 14px for hardware and 12px for AI, with fixed-width columns and tabular digits. The Codex icon is white for dark-background contrast.

Each AI window uses one 108×14px rounded rectangular bar: its pastel fill shows **remaining quota**, and its outline, in the provider accent at 60% opacity, shows the **time remaining** until reset and shrinks from the right. Fill reaching past the outline means quota is outlasting the cycle. The top and bottom edges extend equally: at 50%, both end at the horizontal midpoint. Reset date/time is inside on the left (local HH:mm for 5h, M/d for weekly), with the remaining percentage on the right, both in regular-weight text. The AI pill is 421px wide; the three groups stay centered with 56px gaps. Time uses the reported reset and cycle duration (five hours or seven days for older cache entries), updates locally every second, and stays full after expiry until fresh reset data arrives. Missing reset dates show `--`; unknown cycle lengths leave the frame empty. Window labels remain in tooltips and accessibility text. Each window comes from observed quota data. Codex Pro plans omit the 5h gauge. Hover for full reset times and the last observation time.

One PowerShell helper reads OpenCodex caches every two seconds, checking modification times before parsing. When observations are older than five minutes, it makes a read-only quota GET using the existing Codex / Claude login. Failed requests back off and respect Retry-After. OAuth tokens stay inside the helper and are never sent to the UI or written to the display cache. Claude's usage endpoint is undocumented; it can change. Usage outside the local proxy is visible at the five-minute refresh interval.

The helper exits when Zebar exits, when the widget requests a stop, or after 20 seconds without a widget heartbeat. A named mutex prevents duplicate quota requests during a reload.

## Install on Windows

Install Zebar with Scoop, then apply the configuration and start all four windows:

```powershell
rtk proxy chezmoi apply "$env:USERPROFILE/.glzr/zebar"
rtk proxy zebar startup
```

The source state is `dot_glzr/zebar` in the dotfiles repository; files are installed under `%USERPROFILE%\.glzr\zebar`. This pack is ignored by chezmoi on non-Windows systems. Runtime `data/`, logs and local settings backups are excluded from source control. Existing Codex and Claude Code logins remain outside the repository; the helper reads them at runtime without refreshing OAuth.

To recreate the current login startup shortcut after installing Zebar through Scoop:

```powershell
$zebarExe = Join-Path $env:USERPROFILE 'scoop/apps/zebar/current/zebar.exe'
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'Zebar.lnk'
$shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcutPath)
$shortcut.TargetPath = $zebarExe
$shortcut.Arguments = 'startup'
$shortcut.WorkingDirectory = Split-Path $zebarExe
$shortcut.Save()
```

Official icon sources and the local API compatibility adjustment are documented in `assets/SOURCES.md` and `vendor/SOURCE.md`.
