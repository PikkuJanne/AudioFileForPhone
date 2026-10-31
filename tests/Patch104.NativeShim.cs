// Test-only native process seam. Not included in the runtime package.
// Compile twice as ffmpeg.exe and ffprobe.exe in one isolated tools directory.
// Selected real tools keep their original binaries and receive the same argv.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;

internal static class Patch104NativeShim
{
    private static string Quote(string value)
    {
        StringBuilder b = new StringBuilder("\"");
        int slashes = 0;
        foreach (char c in value)
        {
            if (c == '\\') { slashes++; continue; }
            if (c == '"') b.Append('\\', slashes * 2 + 1);
            else b.Append('\\', slashes);
            b.Append(c); slashes = 0;
        }
        b.Append('\\', slashes * 2); b.Append('"'); return b.ToString();
    }

    public static int Main(string[] args)
    {
        string role = Path.GetFileNameWithoutExtension(Process.GetCurrentProcess().MainModule.FileName);
        string real = Environment.GetEnvironmentVariable(role.Equals("ffprobe", StringComparison.OrdinalIgnoreCase)
            ? "AFP_PATCH104_REAL_FFPROBE" : "AFP_PATCH104_REAL_FFMPEG");
        string source = Environment.GetEnvironmentVariable("AFP_PATCH104_CRASH_SOURCE");
        string log = Environment.GetEnvironmentVariable("AFP_PATCH104_SHIM_LOG");
        string mode = Environment.GetEnvironmentVariable("AFP_PATCH104_MODE");
        bool original = false, sourceQuery = false, remux = false;
        for (int i = 0; i < args.Length; i++)
        {
            if (!String.IsNullOrEmpty(source) && String.Equals(args[i], source, StringComparison.OrdinalIgnoreCase)) original = true;
            if (args[i] == "-show_entries") sourceQuery = true;
            if (args[i] == "-c:a" && i + 1 < args.Length && args[i + 1] == "copy") remux = true;
        }
        bool probeCrash = original && sourceQuery && role.Equals("ffprobe", StringComparison.OrdinalIgnoreCase)
            && !String.IsNullOrEmpty(mode) && mode != "normal";
        string stage = probeCrash ? "probe-crash" : (remux && original ? "recovery-remux" : "delegate");
        if (!String.IsNullOrEmpty(log)) File.AppendAllText(log, role + "\t" + stage + "\t" + String.Join("|", args) + Environment.NewLine);
        if (probeCrash)
        {
            Console.Error.WriteLine("*** stack smashing detected ***: terminated");
            return unchecked((int)0xC0000409);
        }
        if (remux && original && mode == "remux-fail")
        {
            Console.Error.WriteLine("Controlled test remux failure."); return 1;
        }
        List<string> forwarded = new List<string>(args);
        if (remux && original && mode == "short-remux")
        {
            forwarded.Insert(forwarded.Count - 1, "-t");
            forwarded.Insert(forwarded.Count - 1, "0.25");
        }
        if (String.IsNullOrEmpty(real) || !Path.IsPathRooted(real) || !File.Exists(real)) return 125;
        List<string> quoted = forwarded.ConvertAll<string>(Quote);
        ProcessStartInfo info = new ProcessStartInfo(real, String.Join(" ", quoted.ToArray()));
        info.UseShellExecute = false; info.CreateNoWindow = true;
        info.RedirectStandardOutput = true; info.RedirectStandardError = true;
        using (Process child = Process.Start(info))
        {
            System.Threading.Tasks.Task<string> stdout = child.StandardOutput.ReadToEndAsync();
            System.Threading.Tasks.Task<string> stderr = child.StandardError.ReadToEndAsync();
            child.WaitForExit();
            Console.Out.Write(stdout.Result); Console.Error.Write(stderr.Result);
            return child.ExitCode;
        }
    }
}
