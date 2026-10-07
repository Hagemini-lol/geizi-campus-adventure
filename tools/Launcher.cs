using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

static class Launcher {
    [STAThread]
    static int Main(string[] args) {
        string root = AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar);
        string engine = Path.Combine(root, "runtime", "engine.exe");
        string pack = Path.Combine(root, "runtime", "campus.pck");
        if (!File.Exists(engine) || !File.Exists(pack)) {
            MessageBox.Show("游戏运行文件缺失，请保留完整的游戏文件夹。", "gei子的冒险");
            return 1;
        }
        try {
            bool test = Array.IndexOf(args, "--smoke-test") >= 0;
            ProcessStartInfo start = new ProcessStartInfo(engine);
            start.WorkingDirectory = root;
            start.UseShellExecute = false;
            start.CreateNoWindow = true;
            start.Arguments = "--main-pack \"" + pack + "\" --rendering-method gl_compatibility --log-file \"" + Path.Combine(root, "runtime", test ? "smoke.log" : "game.log") + "\"";
            if (test) start.Arguments += " --headless --quit-after 90";
            start.Arguments += " -- --game-root=\"" + root + "\"";
            using (Process process = Process.Start(start)) {
                if (test) { process.WaitForExit(); return process.ExitCode; }
            }
            return 0;
        } catch (Exception error) {
            MessageBox.Show(error.Message, "gei子的冒险启动失败");
            return 1;
        }
    }
}
