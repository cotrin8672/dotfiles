$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition (Get-Content -Raw (Join-Path $PSScriptRoot '../dot_glzr/zebar/pastel-bar/AcrylicLayer.cs.tmpl'))
[PastelAcrylic]::Initialize()
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class MotionFixture {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr CreateWindowEx(uint ex, string cls, string title, uint style, int x, int y, int w, int h, IntPtr parent, IntPtr menu, IntPtr instance, IntPtr parameter);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll")] public static extern bool DestroyWindow(IntPtr window);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool SetWindowText(IntPtr window, string title);
    delegate void EventProc(IntPtr hook, uint type, IntPtr window, int objectId, int childId, uint thread, uint time);
    [DllImport("user32.dll")] static extern IntPtr SetWinEventHook(uint min, uint max, IntPtr module, EventProc callback, uint process, uint thread, uint flags);
    [DllImport("user32.dll")] static extern bool UnhookWinEvent(IntPtr hook);
    static EventProc callback;
    static IntPtr hook;
    public static readonly List<int> Frames = new List<int>();
    public static Rect Bounds(IntPtr window) { Rect rect; if (!GetWindowRect(window, out rect)) throw new Exception("Owned test window disappeared"); return rect; }
    public static void Record(IntPtr hardware, IntPtr active, IntPtr spotify, uint owner) {
        callback = (h, type, window, obj, child, thread, time) => {
            if (window != hardware || obj != 0) return;
            var a = Bounds(active); var s = Bounds(spotify);
            if (a.Left + a.Right != 1920) throw new Exception("ActiveWindow moved off center");
            if (s.Right-s.Left != 132 || s.Bottom-s.Top != 34) throw new Exception("Spotify must never resize during the hardware slide");
            Frames.Add(Bounds(hardware).Left);
        };
        hook = SetWinEventHook(0x800B, 0x800B, IntPtr.Zero, callback, owner, 0, 0);
        if (hook == IntPtr.Zero) throw new Exception("Could not observe owned windows");
    }
    public static void Stop() { if (hook != IntPtr.Zero) UnhookWinEvent(hook); }
}
'@
function Assert([bool]$value, [string]$message) { if (!$value) { throw $message } }
$windows = @{}
try {
    $sizes = @{ Hardware=400; Window=320; AI=351; Spotify=132; Weather=166; Spacer=1920 }
    foreach ($name in $sizes.Keys) {
        $title = if ($name -eq 'Spotify') { 'Pastel Bar - Spotify Hidden' } else { 'Pastel Bar - ' + $name }
        $height = if ($name -eq 'Spacer') { 52 } else { 34 }
        $windows[$name] = [MotionFixture]::CreateWindowEx(0x08000080, 'STATIC', $title, 2415919104, 0, -10000, $sizes[$name], $height, [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero)
        Assert ($windows[$name] -ne [IntPtr]::Zero) 'Could not create isolated test window'
    }
    [PastelAcrylic]::Arrange($PID, $false)
    Assert (([MotionFixture]::Bounds($windows.Hardware)).Left -eq 344) 'Unexpected closed position'
    [MotionFixture]::Record($windows.Hardware, $windows.Window, $windows.Spotify, $PID)
    foreach ($open in @($true, $false, $true, $false)) {
        [void][MotionFixture]::SetWindowText($windows.Spotify, ('Pastel Bar - Spotify' + $(if ($open) { '' } else { ' Hidden' })))
        $before = ([MotionFixture]::Bounds($windows.Hardware)).Left
        [PastelAcrylic]::Arrange($PID, $open)
        Assert (([MotionFixture]::Bounds($windows.Hardware)).Left -eq $before) 'Hardware jumped before the UI snapshot'
        [PastelAcrylic]::AnimateHardware()
        [PastelAcrylic]::Pump()
        $expected = if ($open) { 156 } else { 344 }
        Assert (([MotionFixture]::Bounds($windows.Hardware)).Left -eq $expected) 'Hardware failed to settle'
    }
    Assert (@([MotionFixture]::Frames | Sort-Object -Unique).Count -gt 6) 'Hardware did not animate through intermediate positions'
    Write-Output 'Native hardware slide passed: insertion/removal, fixed Spotify size, centered ActiveWindow'
} finally {
    [MotionFixture]::Stop()
    foreach ($handle in $windows.Values) { [void][MotionFixture]::DestroyWindow($handle) }
}
