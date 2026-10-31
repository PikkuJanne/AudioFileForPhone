// Test-only controller for an isolated, hidden native console. Production BAT bytes
// stay unchanged; the controller observes PAUSE and supplies an actual console key.
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Collections.Generic;

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
    [StructLayout(LayoutKind.Explicit, Size = 20, CharSet = CharSet.Unicode)]
    private struct InputRecord
    {
        [FieldOffset(0)] public short type;
        [FieldOffset(4)] public int down;
        [FieldOffset(8)] public short repeat;
        [FieldOffset(10)] public short key;
        [FieldOffset(12)] public short scan;
        [FieldOffset(14), MarshalAs(UnmanagedType.U2)] public char character;
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
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct ShellInfo
    {
        public int size; public uint mask; public IntPtr window; public string verb, file, parameters, directory;
        public int show; public IntPtr instance, idList; public string className; public IntPtr classKey;
        public uint hotKey; public IntPtr icon, process;
    }
    [DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern bool ShellExecuteEx(ref ShellInfo information);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CreateProcess(string app, StringBuilder arguments, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr environment, string directory, ref StartupInfo startup, out ProcessInformation process);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateJobObject(IntPtr attributes, string name);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern IntPtr OpenJobObject(uint access, bool inherit, string name);
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
    private static extern bool ReadConsoleOutputCharacterW(IntPtr output, [Out, MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.U2)] char[] text, uint count, Coord position, out uint read);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool WriteConsoleInputW(IntPtr input, InputRecord[] records, uint count, out uint written);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern bool ReadConsoleOutputAttribute(IntPtr output, ushort[] values, uint count, Coord position, out uint read);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern bool SetConsoleScreenBufferSize(IntPtr output, Coord size);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern bool SetConsoleWindowInfo(IntPtr output, bool absolute, ref SmallRect rectangle);
    private delegate bool EnumWindowProc(IntPtr window, IntPtr state);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowProc callback, IntPtr state);
    [DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr parent, EnumWindowProc callback, IntPtr state);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowText(IntPtr window, StringBuilder text, int capacity);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetClassName(IntPtr window, StringBuilder text, int capacity);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern IntPtr OpenProcess(uint access, bool inherit, uint process);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern bool IsProcessInJob(IntPtr process, IntPtr job, out bool result);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern bool SetWindowText(IntPtr window, string text);
    [DllImport("user32.dll")] private static extern IntPtr GetDlgItem(IntPtr window, int id);
    [DllImport("user32.dll")] private static extern int GetDlgCtrlID(IntPtr window);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool PostMessage(IntPtr window, uint message, IntPtr first, IntPtr second);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr SendMessage(IntPtr window, uint message, IntPtr first, IntPtr second);
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
        StringBuilder lines = new StringBuilder();
        // Read by screen row: wide Unicode glyphs occupy two cells but may be
        // returned as one character. Slicing a flat character string by cell
        // width can split later prompts (including PAUSE) at invented boundaries.
        int first = Math.Max(0, (int)info.cursor.y - 999);
        int last = Math.Min((int)info.size.y - 1, (int)info.cursor.y + 1);
        for (int y = first; y <= last; y++)
        {
            char[] row = new char[info.size.x]; uint read;
            Coord position = new Coord(); position.y = (short)y;
            Require(ReadConsoleOutputCharacterW(output, row, (uint)info.size.x, position, out read), "Cannot read owned console row.");
            lines.AppendLine(new String(row, 0, (int)read).TrimEnd());
        }
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

    private static void SupplyLine(IntPtr input, string answer)
    {
        List<InputRecord> keys = new List<InputRecord>();
        string value = answer == "~EOF~" ? "\u001a\r" : answer + "\r";
        foreach (char character in value)
        {
            InputRecord key = new InputRecord(); key.type = 1; key.down = 1; key.repeat = 1;
            key.character = character; key.key = character == '\r' ? (short)0x0D : (short)0;
            if (character == '\u001a') { key.key = 0x5A; key.state = 8; }
            keys.Add(key); key.down = 0; keys.Add(key);
        }
        uint written;
        Require(WriteConsoleInputW(input, keys.ToArray(), (uint)keys.Count, out written) && written == keys.Count, "Cannot supply scripted literal console line.");
    }
    private static string ReadColors(IntPtr output)
    {
        BufferInfo info; Require(GetConsoleScreenBufferInfo(output, out info), "Cannot read console color geometry.");
        int count = Math.Min((int)info.size.x * info.size.y, 120000); uint read;
        ushort[] colors = new ushort[count];
        Require(ReadConsoleOutputAttribute(output, colors, (uint)count, new Coord(), out read), "Cannot capture native color attributes.");
        char[] chars = new char[count];
        Require(ReadConsoleOutputCharacterW(output, chars, (uint)count, new Coord(), out read), "Cannot bind native colors to text.");
        Dictionary<ushort, int> counts = new Dictionary<ushort, int>();
        string flat = new String(chars, 0, (int)read);
        for (int i = 0; i < flat.Length; i++) if (!Char.IsWhiteSpace(flat[i]))
        { if (!counts.ContainsKey(colors[i])) counts[colors[i]] = 0; counts[colors[i]]++; }
        StringBuilder json = new StringBuilder("{"); bool comma = false;
        foreach (KeyValuePair<ushort, int> color in counts)
        { if (comma) json.Append(','); json.Append(Json(color.Key.ToString())).Append(':').Append(color.Value); comma = true; }
        return json.Append('}').ToString();
    }
    private static bool SupplyCover(IntPtr job, string path)
    {
        bool supplied = false;
        EnumWindows(delegate(IntPtr window, IntPtr state)
        {
            StringBuilder title = new StringBuilder(512); GetWindowText(window, title, title.Capacity);
            if (!IsWindowVisible(window) || title.ToString() != "Select album cover image") return true;
            uint pid; GetWindowThreadProcessId(window, out pid); IntPtr process = OpenProcess(0x1000, false, pid);
            if (process == IntPtr.Zero) return true;
            bool owned; bool known = IsProcessInJob(process, job, out owned); CloseHandle(process);
            if (!known || !owned) return true;
            if (path == "~CANCEL~") { SendMessage(window, 0x10, IntPtr.Zero, IntPtr.Zero); supplied = true; return false; }
            IntPtr edit = IntPtr.Zero;
            EnumChildWindows(window, delegate(IntPtr child, IntPtr ignored)
            {
                StringBuilder name = new StringBuilder(64); GetClassName(child, name, name.Capacity);
                if (name.ToString() == "Edit" && GetDlgCtrlID(child) == 1148 && IsWindowVisible(child)) edit = child;
                return true;
            }, IntPtr.Zero);
            if (edit != IntPtr.Zero && SetWindowText(edit, path))
            {
                // Commit an edit notification after literal text assignment; the
                // common dialog may retain a separate filename binding otherwise.
                SendMessage(edit, 0xB1, new IntPtr(-1), new IntPtr(-1));
                SendMessage(edit, 0x102, new IntPtr(32), IntPtr.Zero);
                SendMessage(edit, 0x102, new IntPtr(8), IntPtr.Zero);
                supplied = PostMessage(GetDlgItem(window, 1), 0xF5, IntPtr.Zero, IntPtr.Zero);
                return !supplied;
            }
            return true;
        }, IntPtr.Zero);
        return supplied;
    }

    // Arguments: exact cmd.exe, cmd argument string, unrelated working directory,
    // fresh report path, deadline milliseconds. The case environment is inherited.
    // Optional sixth argument is literal Enter (ready menu) or SetupCancel (Q + Enter).
    private static int Main(string[] args)
    {
        if (args.Length == 4 && args[0] == "--shell-worker")
        {
            IntPtr inheritedJob = OpenJobObject(4, false, args[3]);
            Require(inheritedJob != IntPtr.Zero, "Cannot verify inherited shell-delivery job.");
            ShellInfo launch = new ShellInfo(); launch.size = Marshal.SizeOf(launch); launch.mask = 0x40 | 0x8000 | 0x100;
            launch.verb = "open"; launch.file = args[1]; launch.parameters = args[2]; launch.directory = Environment.CurrentDirectory; launch.show = 0;
            Require(ShellExecuteEx(ref launch) && launch.process != IntPtr.Zero, "Windows shell did not return shortcut target process.");
            bool contained; Require(IsProcessInJob(launch.process, inheritedJob, out contained) && contained, "Shell target did not inherit guarded job; refusing console input.");
            Require(WaitForSingleObject(launch.process, 200000) == 0, "Shell target deadline.");
            uint shellExit; Require(GetExitCodeProcess(launch.process, out shellExit), "Cannot read shell target exit.");
            CloseHandle(launch.process); CloseHandle(inheritedJob); return (int)shellExit;
        }
        ProcessInformation pi = new ProcessInformation();
        IntPtr job = IntPtr.Zero, input = IntPtr.Zero, output = IntPtr.Zero;
        bool attached = false, assigned = false, paused = false, waiting = false, injected = false, released = false;
        bool initialMenuKeySent = false;
        bool coverSupplied = false;
        int scriptStep = 0;
        string colors = "{}";
        List<string[]> steps = new List<string[]>();
        bool scripted = args.Length > 5 && (args[5] == "Script" || args[5] == "DirectScript");
        bool direct = args.Length > 5 && args[5] == "DirectScript";
        bool shell = args[0].StartsWith("shell:", StringComparison.Ordinal);
        uint exit = 999;
        string text = "", error = "";
        try
        {
            if (args.Length > 5 && (args.Length != 6 ||
                (!String.Equals(args[5], "Enter", StringComparison.Ordinal) && !String.Equals(args[5], "SetupCancel", StringComparison.Ordinal) && !scripted)))
                throw new ArgumentException("Unsupported native-console mode.");
            if (scripted) foreach (string line in File.ReadAllLines(Environment.GetEnvironmentVariable("AFP_CONSOLE_STEPS"), Encoding.UTF8))
            { string[] fields = line.Split('\t'); if (fields.Length != 3) throw new ArgumentException("Script steps need trigger, occurrence and literal answer."); steps.Add(fields); }
            string jobName = "Local\\AFP-Console-" + Guid.NewGuid().ToString("N");
            job = CreateJobObject(IntPtr.Zero, jobName);
            Require(job != IntPtr.Zero, "Cannot create exclusive test job.");
            ExtendedLimits limits = new ExtendedLimits(); limits.basic.flags = 0x2000;
            Require(SetInformationJobObject(job, 9, ref limits, (uint)Marshal.SizeOf(limits)), "Cannot guard owned descendants.");
            if (shell)
            {
                string self = Environment.GetCommandLineArgs()[0];
                StartupInfo si = new StartupInfo(); si.cb = Marshal.SizeOf(si); si.flags = 1; si.show = 0;
                string arguments = "\"" + self + "\" --shell-worker \"" + args[0].Substring(6) + "\" \"" + args[1].Replace("\"", "\\\"") + "\" \"" + jobName + "\"";
                Require(CreateProcess(self, new StringBuilder(arguments), IntPtr.Zero, IntPtr.Zero, false,
                    0x10 | 0x4, IntPtr.Zero, args[2], ref si, out pi), "Cannot start suspended shell worker console.");
            }
            else
            {
                StartupInfo si = new StartupInfo(); si.cb = Marshal.SizeOf(si); si.flags = 1; si.show = 0;
                Require(CreateProcess(args[0], new StringBuilder("\"" + args[0] + "\" " + args[1]), IntPtr.Zero, IntPtr.Zero, false,
                    0x10 | 0x4, IntPtr.Zero, args[2], ref si, out pi), "Cannot start hidden owned cmd console.");
            }
            Require(AssignProcessToJobObject(job, pi.process), "Cannot own cmd process tree."); assigned = true;
                Require(ResumeThread(pi.thread) != UInt32.MaxValue, "Cannot resume owned cmd.");
                CloseHandle(pi.thread); pi.thread = IntPtr.Zero;
                FreeConsole();
                for (int i = 0; i < 100 && !attached; i++) { attached = AttachConsole(pi.pid); if (!attached) Thread.Sleep(20); }
            Require(attached, "Cannot attach disposable controller to owned console.");
            input = CreateFileW("CONIN$", 0x80000000 | 0x40000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
            output = CreateFileW("CONOUT$", 0x80000000 | 0x40000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
            Require(input != new IntPtr(-1) && output != new IntPtr(-1), "Cannot open owned console handles.");
            string widthValue = Environment.GetEnvironmentVariable("AFP_CONSOLE_WIDTH");
            if (!String.IsNullOrEmpty(widthValue))
            {
                short width = Int16.Parse(widthValue); Require(width >= 30 && width <= 200, "Unsafe console width.");
                SmallRect rectangle = new SmallRect(); rectangle.right = (short)(width - 1); rectangle.bottom = 24;
                Require(SetConsoleWindowInfo(output, true, ref rectangle), "Cannot set owned console window width.");
                Coord size = new Coord(); size.x = width; size.y = 1000;
                Require(SetConsoleScreenBufferSize(output, size), "Cannot set owned console buffer width.");
            }
            Stopwatch timer = Stopwatch.StartNew();
            while (timer.ElapsedMilliseconds < Int32.Parse(args[4]))
            {
                text = ReadConsole(output);
                colors = ReadColors(output);
                if (scripted && scriptStep < steps.Count)
                {
                    string trigger = steps[scriptStep][0]; int count = 0, start = 0, found;
                    while ((found = text.IndexOf(trigger, start, StringComparison.OrdinalIgnoreCase)) >= 0) { count++; start = found + trigger.Length; }
                    if (count >= Int32.Parse(steps[scriptStep][1]))
                    { SupplyLine(input, steps[scriptStep][2]); scriptStep++; initialMenuKeySent = true; }
                }
                string cover = Environment.GetEnvironmentVariable("AFP_CONSOLE_COVER");
                if (!coverSupplied && !String.IsNullOrEmpty(cover)) coverSupplied = SupplyCover(job, cover);
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
            if (scripted) Require(scriptStep == steps.Count, "Not all scripted prompts were reached.");
            if (direct)
            {
                Require(WaitForSingleObject(pi.process, 10000) == 0, "Direct host did not finish.");
                text = ReadConsole(output); colors = ReadColors(output);
                Require(GetExitCodeProcess(pi.process, out exit), "Cannot read direct host exit code.");
                released = true;
            }
            else {
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
            report = report.Substring(0, report.Length - 1) + ",\"script_steps_sent\":" + scriptStep + ",\"cover_picker_supplied\":" + Bool(coverSupplied) + ",\"shell_shortcut_invoked\":" + Bool(shell) + ",\"color_attributes\":" + colors + "}";
            File.WriteAllText(args[3], report, new UTF8Encoding(false));
        }
        return error.Length == 0 ? 0 : 1;
    }
}
