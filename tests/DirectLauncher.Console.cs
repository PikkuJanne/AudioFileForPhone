// Test-only controller for an isolated, hidden native console. Production BAT bytes
// stay unchanged; the controller observes PAUSE and supplies an actual console key.
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

internal static class DirectLauncherConsole
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct StartupInfo
    {
        public int cb; public string reserved, desktop, title;
        public uint x, y, xSize, ySize, xChars, yChars, fill, flags;
        public short show, reserved2; public IntPtr reservedPointer, input, output, error;
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct ProcessInformation { public IntPtr process, thread; public uint pid, tid; }
    [StructLayout(LayoutKind.Sequential)]
    private struct Coord { public short x, y; }
    [StructLayout(LayoutKind.Sequential)]
    private struct SmallRect { public short left, top, right, bottom; }
    [StructLayout(LayoutKind.Sequential)]
    private struct BufferInfo { public Coord size, cursor; public short attributes; public SmallRect window; public Coord maximum; }
    [StructLayout(LayoutKind.Explicit, Size = 20)]
    private struct InputRecord
    {
        [FieldOffset(0)] public short type;
        [FieldOffset(4)] public int down;
        [FieldOffset(8)] public short repeat;
        [FieldOffset(10)] public short key;
        [FieldOffset(12)] public short scan;
        [FieldOffset(14)] public char character;
        [FieldOffset(16)] public int state;
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct BasicLimits
    {
        public long processTime, jobTime; public uint flags;
        public UIntPtr minimum, maximum; public uint active;
        public UIntPtr affinity; public uint priority, scheduling;
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct IoCounters { public ulong readOps, writeOps, otherOps, readBytes, writeBytes, otherBytes; }
    [StructLayout(LayoutKind.Sequential)]
    private struct ExtendedLimits
    {
        public BasicLimits basic; public IoCounters io;
        public UIntPtr processMemory, jobMemory, peakProcessMemory, peakJobMemory;
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct Accounting
    {
        public long user, kernel, periodUser, periodKernel;
        public uint faults, total, active, terminated;
    }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CreateProcess(string app, StringBuilder arguments, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr environment, string directory, ref StartupInfo startup, out ProcessInformation process);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateJobObject(IntPtr attributes, string name);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetInformationJobObject(IntPtr job, int kind, ref ExtendedLimits information, uint length);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool QueryInformationJobObject(IntPtr job, int kind, out Accounting accounting, uint length, IntPtr returned);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern bool TerminateJobObject(IntPtr job, uint code);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern bool TerminateProcess(IntPtr process, uint code);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern bool AttachConsole(uint pid);
    [DllImport("kernel32.dll")] private static extern bool FreeConsole();
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateFileW(string path, uint access, uint sharing, IntPtr attributes, uint creation, uint flags, IntPtr template);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern bool GetConsoleScreenBufferInfo(IntPtr output, out BufferInfo info);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool ReadConsoleOutputCharacterW(IntPtr output, StringBuilder text, uint count, Coord position, out uint read);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool WriteConsoleInputW(IntPtr input, InputRecord[] records, uint count, out uint written);
    [DllImport("kernel32.dll")] private static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
    [DllImport("kernel32.dll")] private static extern bool GetExitCodeProcess(IntPtr handle, out uint code);
    [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr handle);

    private static void Require(bool condition, string message)
    {
        if (!condition) throw new Win32Exception(Marshal.GetLastWin32Error(), message);
    }
    private static string ReadConsole(IntPtr output)
    {
        BufferInfo info;
        Require(GetConsoleScreenBufferInfo(output, out info), "Cannot inspect owned console buffer.");
        int count = Math.Min((int)info.size.x * info.size.y, 120000);
        StringBuilder text = new StringBuilder(count);
        uint read;
        Require(ReadConsoleOutputCharacterW(output, text, (uint)count, new Coord(), out read), "Cannot read owned console buffer.");
        StringBuilder lines = new StringBuilder();
        string flat = text.ToString();
        for (int i = 0; i < flat.Length; i += info.size.x)
            lines.AppendLine(flat.Substring(i, Math.Min(info.size.x, flat.Length - i)).TrimEnd());
        return lines.ToString().Trim();
    }
    private static string Json(string text)
    {
        StringBuilder result = new StringBuilder("\"");
        foreach (char c in text)
        {
            if (c == '\\' || c == '"') result.Append('\\').Append(c);
            else if (c < ' ') result.Append("\\u").Append(((int)c).ToString("x4"));
            else result.Append(c);
        }
        return result.Append('"').ToString();
    }
    private static string Bool(bool value) { return value ? "true" : "false"; }

    // Arguments: exact cmd.exe, cmd argument string, unrelated working directory,
    // fresh report path, deadline milliseconds. The case environment is inherited.
    // Optional sixth argument is literal Enter (ready menu) or SetupCancel (Q + Enter).
    private static int Main(string[] args)
    {
        ProcessInformation pi = new ProcessInformation();
        IntPtr job = IntPtr.Zero, input = IntPtr.Zero, output = IntPtr.Zero;
        bool attached = false, assigned = false, paused = false, waiting = false, injected = false, released = false;
        bool initialMenuKeySent = false;
        uint exit = 999;
        string text = "", error = "";
        try
        {
            if (args.Length > 5 && (args.Length != 6 ||
                (!String.Equals(args[5], "Enter", StringComparison.Ordinal) && !String.Equals(args[5], "SetupCancel", StringComparison.Ordinal))))
                throw new ArgumentException("Optional sixth argument must be literal Enter or SetupCancel.");
            job = CreateJobObject(IntPtr.Zero, null);
            Require(job != IntPtr.Zero, "Cannot create exclusive test job.");
            ExtendedLimits limits = new ExtendedLimits(); limits.basic.flags = 0x2000;
            Require(SetInformationJobObject(job, 9, ref limits, (uint)Marshal.SizeOf(limits)), "Cannot guard owned descendants.");
            StartupInfo si = new StartupInfo(); si.cb = Marshal.SizeOf(si); si.flags = 1; si.show = 0;
            Require(CreateProcess(args[0], new StringBuilder("\"" + args[0] + "\" " + args[1]), IntPtr.Zero, IntPtr.Zero, false,
                0x10 | 0x4, IntPtr.Zero, args[2], ref si, out pi), "Cannot start hidden owned cmd console.");
            Require(AssignProcessToJobObject(job, pi.process), "Cannot own cmd process tree."); assigned = true;
            Require(ResumeThread(pi.thread) != UInt32.MaxValue, "Cannot resume owned cmd.");
            CloseHandle(pi.thread); pi.thread = IntPtr.Zero;
            FreeConsole();
            for (int i = 0; i < 100 && !attached; i++) { attached = AttachConsole(pi.pid); if (!attached) Thread.Sleep(20); }
            Require(attached, "Cannot attach disposable controller to owned console.");
            input = CreateFileW("CONIN$", 0x80000000 | 0x40000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
            output = CreateFileW("CONOUT$", 0x80000000 | 0x40000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
            Require(input != new IntPtr(-1) && output != new IntPtr(-1), "Cannot open owned console handles.");
            Stopwatch timer = Stopwatch.StartNew();
            while (timer.ElapsedMilliseconds < Int32.Parse(args[4]))
            {
                text = ReadConsole(output);
                if (text.IndexOf("Press any key", StringComparison.OrdinalIgnoreCase) >= 0) { paused = true; break; }
                if (args.Length > 5 && args[5] == "Enter" && !initialMenuKeySent && text.IndexOf("Waiting for your selection", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    InputRecord enter = new InputRecord(); enter.type = 1; enter.down = 1; enter.repeat = 1;
                    enter.key = 0x0D; enter.scan = 0x1C; enter.character = '\r';
                    InputRecord enterUp = enter; enterUp.down = 0; uint menuWritten;
                    Require(WriteConsoleInputW(input, new InputRecord[] { enter, enterUp }, 2, out menuWritten) && menuWritten == 2, "Cannot supply initial menu Enter.");
                    initialMenuKeySent = true;
                }
                if (args.Length > 5 && args[5] == "SetupCancel" && !initialMenuKeySent && text.IndexOf("S = select existing folder", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    InputRecord cancel = new InputRecord(); cancel.type = 1; cancel.down = 1; cancel.repeat = 1;
                    cancel.key = 0x51; cancel.scan = 0x10; cancel.character = 'Q';
                    InputRecord cancelUp = cancel; cancelUp.down = 0;
                    InputRecord enter = new InputRecord(); enter.type = 1; enter.down = 1; enter.repeat = 1;
                    enter.key = 0x0D; enter.scan = 0x1C; enter.character = '\r';
                    InputRecord enterUp = enter; enterUp.down = 0; uint menuWritten;
                    Require(WriteConsoleInputW(input, new InputRecord[] { cancel, cancelUp, enter, enterUp }, 4, out menuWritten) && menuWritten == 4, "Cannot supply setup menu cancellation.");
                    initialMenuKeySent = true;
                }
                if (WaitForSingleObject(pi.process, 0) == 0) break;
                Thread.Sleep(25);
            }
            Require(paused, "Production BAT did not expose its final pause.");
            Thread.Sleep(250);
            waiting = WaitForSingleObject(pi.process, 0) == 0x102;
            Require(waiting, "BAT exited before the automated console key.");
            InputRecord key = new InputRecord(); key.type = 1; key.down = 1; key.repeat = 1; key.key = 0x20; key.character = ' ';
            InputRecord up = key; up.down = 0; uint written;
            Require(WriteConsoleInputW(input, new InputRecord[] { key, up }, 2, out written) && written == 2, "Cannot supply console key.");
            injected = true;
            Require(WaitForSingleObject(pi.process, 10000) == 0, "BAT did not finish after console key.");
            text = ReadConsole(output);
            Require(GetExitCodeProcess(pi.process, out exit), "Cannot read preserved BAT exit code.");
            released = true;
        }
        catch (Exception exception) { error = exception.Message; }
        finally
        {
            if (input != IntPtr.Zero && input != new IntPtr(-1)) CloseHandle(input);
            if (output != IntPtr.Zero && output != new IntPtr(-1)) CloseHandle(output);
            if (attached) FreeConsole();
            if (job != IntPtr.Zero && assigned)
            {
                TerminateJobObject(job, 123);
                Accounting accounting = new Accounting(); bool known = false;
                Stopwatch releaseTimer = Stopwatch.StartNew();
                do
                {
                    known = QueryInformationJobObject(job, 1, out accounting, (uint)Marshal.SizeOf(accounting), IntPtr.Zero);
                    if (known && accounting.active == 0) break;
                    Thread.Sleep(20);
                } while (releaseTimer.ElapsedMilliseconds < 5000);
                released = known && accounting.active == 0 && WaitForSingleObject(pi.process, 0) == 0;
            }
            else if (pi.process != IntPtr.Zero)
            {
                TerminateProcess(pi.process, 123);
                released = WaitForSingleObject(pi.process, 5000) == 0;
            }
            if (pi.thread != IntPtr.Zero) CloseHandle(pi.thread);
            if (pi.process != IntPtr.Zero) CloseHandle(pi.process);
            if (job != IntPtr.Zero) CloseHandle(job);
            string report = "{\"exit_code\":" + exit + ",\"pause_seen\":" + Bool(paused) + ",\"still_waiting_before_key\":" + Bool(waiting) +
                ",\"key_injected\":" + Bool(injected) + (args.Length > 5 ? ",\"initial_menu_key_sent\":" + Bool(initialMenuKeySent) + ",\"initial_menu_mode\":" + Json(args[5]) : "") +
                ",\"owned_tree_released\":" + Bool(released) + ",\"text\":" + Json(text) + ",\"error\":" + Json(error) + "}";
            File.WriteAllText(args[3], report, new UTF8Encoding(false));
        }
        return error.Length == 0 ? 0 : 1;
    }
}
