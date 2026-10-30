using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

public static class PastelNative
{
    [DllImport("kernel32.dll")] static extern bool GetSystemTimes(out ulong idle, out ulong kernel, out ulong user);
    [DllImport("kernel32.dll", CharSet = CharSet.Auto)] static extern bool GlobalMemoryStatusEx(ref MemoryStatus status);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int length);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint message, IntPtr wparam, IntPtr lparam, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", EntryPoint = "GetClassLongPtrW")] static extern IntPtr GetClassLongPtr64(IntPtr hwnd, int index);
    [DllImport("user32.dll", EntryPoint = "GetClassLongW")] static extern uint GetClassLong32(IntPtr hwnd, int index);
    [DllImport("ntdll.dll")] static extern int NtQueryInformationProcess(IntPtr handle, int information, ref ProcessInfo value, int size, out int returned);
    delegate bool EnumWindowCallback(IntPtr hwnd, IntPtr param);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowCallback callback, IntPtr param);
    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] static extern IntPtr GetWindowStyle(IntPtr hwnd, int index);
    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")] static extern IntPtr SetWindowStyle(IntPtr hwnd, int index, IntPtr value);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateJobObject(IntPtr security, string name);
    [DllImport("kernel32.dll")] static extern bool SetInformationJobObject(IntPtr job, int information, ref JobLimits limits, int size);
    [DllImport("kernel32.dll")] static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    [StructLayout(LayoutKind.Sequential)] struct BasicJobLimits
    {
        public long ProcessTime, JobTime;
        public uint Flags;
        public UIntPtr MinimumWorkingSet, MaximumWorkingSet;
        public uint ActiveProcesses;
        public UIntPtr Affinity;
        public uint Priority, Scheduling;
    }
    [StructLayout(LayoutKind.Sequential)] struct IoCounters { public ulong ReadOperations, WriteOperations, OtherOperations, ReadBytes, WriteBytes, OtherBytes; }
    [StructLayout(LayoutKind.Sequential)] struct JobLimits
    {
        public BasicJobLimits Basic;
        public IoCounters Io;
        public UIntPtr ProcessMemory, JobMemory, PeakProcessMemory, PeakJobMemory;
    }

    [StructLayout(LayoutKind.Sequential)] struct ProcessInfo { public IntPtr Reserved1, Peb, Reserved2, Reserved3, Id, ParentId; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)] struct MemoryStatus
    {
        public uint Length, Load;
        public ulong TotalPhysical, AvailablePhysical, TotalPageFile, AvailablePageFile, TotalVirtual, AvailableVirtual, AvailableExtendedVirtual;
    }
    static ulong lastIdle, lastTotal;
    static IntPtr lastWindow;
    static string lastIcon;
    static uint lastPid;
    static string lastApp;
    static IntPtr gpuJob;

    public static bool TrackGpu(Process process)
    {
        if (gpuJob == IntPtr.Zero)
        {
            gpuJob = CreateJobObject(IntPtr.Zero, null);
            JobLimits limits = new JobLimits();
            limits.Basic.Flags = 0x2000; // Kill the GPU sampler when the collector process exits.
            if (!SetInformationJobObject(gpuJob, 9, ref limits, Marshal.SizeOf(limits)))
            {
                CloseHandle(gpuJob); gpuJob = IntPtr.Zero; return false;
            }
        }
        return AssignProcessToJobObject(gpuJob, process.Handle);
    }

    public static void StylePillWindows(int parentId)
    {
        EnumWindows((window, parameter) => {
            uint pid; GetWindowThreadProcessId(window, out pid);
            if (pid != parentId) return true;
            StringBuilder text = new StringBuilder(256); GetWindowText(window, text, text.Capacity);
            if (!text.ToString().StartsWith("Pastel Bar - ")) return true;
            SetWindowStyle(window, -20, new IntPtr(GetWindowStyle(window, -20).ToInt64() | 0x08000000));
            return true;
        }, IntPtr.Zero);
    }

    public static int ParentId()
    {
        ProcessInfo info = new ProcessInfo(); int returned;
        using (Process p = Process.GetCurrentProcess())
            return NtQueryInformationProcess(p.Handle, 0, ref info, Marshal.SizeOf(info), out returned) == 0 ? info.ParentId.ToInt32() : 0;
    }
    public static double[] Hardware()
    {
        ulong idle, kernel, user;
        double cpu = double.NaN;
        if (GetSystemTimes(out idle, out kernel, out user))
        {
            ulong total = kernel + user;
            if (lastTotal != 0 && total > lastTotal)
                cpu = Math.Max(0, Math.Min(100, 100.0 * (1 - (double)(idle - lastIdle) / (total - lastTotal))));
            lastIdle = idle; lastTotal = total;
        }
        MemoryStatus memory = new MemoryStatus(); memory.Length = (uint)Marshal.SizeOf(memory);
        if (!GlobalMemoryStatusEx(ref memory)) return new double[] { cpu, double.NaN, 0, 0 };
        return new double[] { cpu, 100.0 * (memory.TotalPhysical - memory.AvailablePhysical) / memory.TotalPhysical,
            (double)(memory.TotalPhysical - memory.AvailablePhysical), (double)memory.TotalPhysical };
    }
    public static string[] ActiveWindow()
    {
        IntPtr hwnd = GetForegroundWindow();
        if (hwnd == IntPtr.Zero) return null;
        uint pid; GetWindowThreadProcessId(hwnd, out pid);
        StringBuilder title = new StringBuilder(1024); GetWindowText(hwnd, title, title.Capacity);
        if (pid == 0 || title.Length == 0) return null;
        if (hwnd != lastWindow || pid != lastPid)
        {
            try
            {
                using (Process process = Process.GetProcessById((int)pid))
                {
                    if (process.ProcessName.Equals("zebar", StringComparison.OrdinalIgnoreCase)) return null;
                    lastApp = process.ProcessName;
                    lastIcon = IconData(hwnd, process);
                }
            }
            catch { lastApp = "Window"; lastIcon = null; }
            lastWindow = hwnd; lastPid = pid;
        }
        return new string[] { title.ToString(), lastApp, lastIcon };
    }
    static string IconData(IntPtr hwnd, Process process)
    {
        try
        {
            IntPtr handle;
            SendMessageTimeout(hwnd, 0x007F, new IntPtr(2), IntPtr.Zero, 0x0002, 75, out handle);
            if (handle == IntPtr.Zero) SendMessageTimeout(hwnd, 0x007F, IntPtr.Zero, IntPtr.Zero, 0x0002, 75, out handle);
            if (handle == IntPtr.Zero) handle = IntPtr.Size == 8 ? GetClassLongPtr64(hwnd, -34) : new IntPtr(GetClassLong32(hwnd, -34));
            using (Icon icon = handle == IntPtr.Zero ? Icon.ExtractAssociatedIcon(process.MainModule.FileName) : (Icon)Icon.FromHandle(handle).Clone())
            {
                if (icon == null) return null;
                using (Bitmap bitmap = new Bitmap(24, 24))
                using (Graphics graphics = Graphics.FromImage(bitmap))
                using (MemoryStream stream = new MemoryStream())
                {
                    graphics.DrawIcon(icon, new Rectangle(0, 0, 24, 24));
                    bitmap.Save(stream, ImageFormat.Png);
                    return "data:image/png;base64," + Convert.ToBase64String(stream.ToArray());
                }
            }
        }
        catch { return null; }
    }
}
