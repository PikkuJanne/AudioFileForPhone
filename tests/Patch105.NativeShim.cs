// Test-only native seam. Never shipped in the user package.
// Each operation delegates unchanged argv to the explicitly supplied real tools,
// except for the selected, recorded injection. No production injection switch.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Text;

internal static class Patch105NativeShim
{
    private static string Env(string name) { return Environment.GetEnvironmentVariable("AFP_PATCH105_" + name); }
    private static string Quote(string value)
    {
        StringBuilder b = new StringBuilder("\""); int slashes = 0;
        foreach (char c in value)
        {
            if (c == '\\') { slashes++; continue; }
            b.Append('\\', c == '"' ? slashes * 2 + 1 : slashes);
            b.Append(c); slashes = 0;
        }
        b.Append('\\', slashes * 2); b.Append('"'); return b.ToString();
    }
    private static string Json(string value)
    {
        StringBuilder b = new StringBuilder("\"");
        foreach (char c in value ?? "")
        {
            if (c == '"' || c == '\\') { b.Append('\\'); b.Append(c); }
            else if (c < 32) b.Append("\\u" + ((int)c).ToString("x4"));
            else b.Append(c);
        }
        b.Append('"'); return b.ToString();
    }
    private static string After(string[] args, string option)
    {
        for (int i = 0; i + 1 < args.Length; i++) if (args[i] == option) return args[i + 1];
        return "";
    }
    private static bool Has(string[] args, string value) { return Array.IndexOf(args, value) >= 0; }
    private static string Hash(string path)
    {
        if (String.IsNullOrEmpty(path) || !File.Exists(path)) return "";
        using (FileStream stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
        using (SHA256 sha = SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "").ToLowerInvariant();
    }
    private static void Log(string role, string stage, string action, bool selected, string path, string[] args)
    {
        string log = Env("LOG"); if (String.IsNullOrEmpty(log)) return;
        List<string> values = new List<string>(); foreach (string arg in args) values.Add(Json(arg));
        string json;
        using (Process current = Process.GetCurrentProcess())
        {
            json = "{\"pid\":" + current.Id + ",\"started_utc_ticks\":" +
                Json(current.StartTime.ToUniversalTime().Ticks.ToString(System.Globalization.CultureInfo.InvariantCulture)) + ",\"role\":" + Json(role) +
                ",\"stage\":" + Json(stage) + ",\"action\":" + Json(action) + ",\"selected\":" +
                (selected ? "true" : "false") + ",\"path\":" + Json(path) + ",\"sha256\":" + Json(Hash(path)) +
                ",\"argv\":[" + String.Join(",", values.ToArray()) + "]}";
        }
        File.AppendAllText(log, json + Environment.NewLine, new UTF8Encoding(false));
    }

    public static int Main(string[] args)
    {
        string role = Path.GetFileNameWithoutExtension(Process.GetCurrentProcess().MainModule.FileName).ToLowerInvariant();
        string real = Env(role == "ffprobe" ? "REAL_FFPROBE" : "REAL_FFMPEG");
        string source = Env("SOURCE"), state = Env("STATE"), targetStage = Env("STAGE"), mode = Env("MODE");
        string input = After(args, "-i"), stage = "other", path = input;
        if (role == "ffprobe" && Has(args, "-select_streams")) stage = "source-probe";
        else if (role == "ffprobe" && Has(args, "-show_entries") && input.EndsWith(".partial", StringComparison.OrdinalIgnoreCase)) stage = "output-probe";
        else if (role == "ffmpeg" && After(args, "-c:a") == "libmp3lame") { stage = "encode"; path = args[args.Length - 1]; }
        else if (role == "ffmpeg" && After(args, "-f") == "null" && input.EndsWith(".partial", StringComparison.OrdinalIgnoreCase)) stage = "validate";
        else if (role == "ffmpeg" && After(args, "-c:a") == "copy") stage = "recovery-remux";
        bool selected = !String.IsNullOrEmpty(source) && String.Equals(source, input, StringComparison.OrdinalIgnoreCase);
        string selectedOutput = String.IsNullOrEmpty(state) ? "" : Path.Combine(state, "selected-output.txt");
        if (selected && stage == "encode" && !String.IsNullOrEmpty(state)) File.WriteAllText(selectedOutput, path);
        if ((stage == "output-probe" || stage == "validate") && File.Exists(selectedOutput)) selected = String.Equals(input, File.ReadAllText(selectedOutput), StringComparison.OrdinalIgnoreCase);
        bool inject = selected && stage == targetStage && mode != "normal";
        if (inject && mode == "once")
        {
            string marker = Path.Combine(state, "injected-" + stage);
            try { using (FileStream reservation = new FileStream(marker, FileMode.CreateNew, FileAccess.Write, FileShare.None)) { } }
            catch (IOException) { inject = false; }
        }
        string action = inject ? mode : "delegate";
        Log(role, stage, action, selected, path, args);
        if (inject && (mode == "once" || mode == "persistent"))
        {
            // An encoder can die after opening/truncating its owned output.
            if (stage == "encode")
            {
                using (FileStream output = new FileStream(path, FileMode.Truncate, FileAccess.Write, FileShare.ReadWrite))
                {
                    byte[] payload = Encoding.UTF8.GetBytes("test-only incomplete encoder payload");
                    output.Write(payload, 0, payload.Length);
                }
            }
            Console.Error.WriteLine("*** stack smashing detected ***: terminated");
            long exit = String.IsNullOrEmpty(Env("EXIT")) ? 3221226505L : Int64.Parse(Env("EXIT"));
            return unchecked((int)exit);
        }
        if (inject && mode == "ordinary") { Console.Error.WriteLine(Env("ERROR") ?? "test-only ordinary media error"); return 1; }
        if (inject && mode == "timeout") { System.Threading.Thread.Sleep(30000); return 1; }
        if (String.IsNullOrEmpty(real) || !Path.IsPathRooted(real) || !File.Exists(real)) return 125;
        List<string> forwarded = new List<string>(args);
        if (inject && mode == "duration-mismatch")
        {
            forwarded.Insert(forwarded.Count - 1, "-t"); forwarded.Insert(forwarded.Count - 1, "0.20");
        }
        ProcessStartInfo info = new ProcessStartInfo(real, String.Join(" ", forwarded.ConvertAll<string>(Quote).ToArray()));
        info.UseShellExecute = false; info.CreateNoWindow = true;
        info.RedirectStandardOutput = true; info.RedirectStandardError = true;
        using (Process child = Process.Start(info))
        {
            System.Threading.Tasks.Task<string> stdout = child.StandardOutput.ReadToEndAsync();
            System.Threading.Tasks.Task<string> stderr = child.StandardError.ReadToEndAsync();
            child.WaitForExit(); Console.Out.Write(stdout.Result); Console.Error.Write(stderr.Result);
            return child.ExitCode;
        }
    }
}
