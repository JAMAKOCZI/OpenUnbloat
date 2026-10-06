using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Security.Principal;
using System.Threading;
using System.Windows.Forms;

namespace UnbloatLauncher
{
    public class SplashScreenForm : Form
    {
        private System.Windows.Forms.Timer animTimer;
        private int pulsePos = 0;
        private int pulseDir = 7;
        private int statusStep = 0;
        private int stepCounter = 0;
        private Label lblStatus;
        private Label lblTitle;
        private Label lblSubTitle;
        private Label lblFooter;
        private Label lblVersion;

        private readonly string[] statusMessages = new string[]
        {
            "Inicjalizacja silnika PowerShell i modułów...",
            "Weryfikacja telemetrii, usług i rejestru...",
            "Skanowanie aplikacji bloatware (UWP)...",
            "Sprawdzanie bazy programów i rejestru...",
            "Przygotowywanie bezpiecznego interfejsu WPF..."
        };

        public SplashScreenForm()
        {
            this.FormBorderStyle = FormBorderStyle.None;
            this.StartPosition = FormStartPosition.CenterScreen;
            this.Size = new Size(500, 250);
            this.BackColor = Color.FromArgb(13, 16, 23); // #0D1017 Obsidian Slate
            this.ForeColor = Color.White;
            this.TopMost = true;
            this.ShowInTaskbar = true;
            this.DoubleBuffered = true;
            try
            {
                this.Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            }
            catch {}

            // Shield Icon / Header
            Label iconLabel = new Label
            {
                Text = "🛡️",
                Font = new Font("Segoe UI Emoji", 26, FontStyle.Regular),
                Location = new Point(28, 24),
                Size = new Size(52, 50),
                BackColor = Color.Transparent
            };
            this.Controls.Add(iconLabel);

            lblTitle = new Label
            {
                Text = "OPENUNBLOAT",
                Font = new Font("Segoe UI", 15, FontStyle.Bold),
                ForeColor = Color.FromArgb(248, 250, 252), // #F8FAFC
                Location = new Point(88, 26),
                Size = new Size(390, 28),
                BackColor = Color.Transparent
            };
            this.Controls.Add(lblTitle);

            lblSubTitle = new Label
            {
                Text = "Centrum Zaawansowanej Optymalizacji i Prywatności",
                Font = new Font("Segoe UI", 9.2f, FontStyle.Regular),
                ForeColor = Color.FromArgb(148, 163, 184), // #94A3B8
                Location = new Point(90, 54),
                Size = new Size(390, 20),
                BackColor = Color.Transparent
            };
            this.Controls.Add(lblSubTitle);

            // Dynamic Status label
            lblStatus = new Label
            {
                Text = statusMessages[0],
                Font = new Font("Segoe UI", 9.5f, FontStyle.Bold),
                ForeColor = Color.FromArgb(56, 189, 248), // #38BDF8 Sky Blue
                Location = new Point(32, 124),
                Size = new Size(436, 22),
                BackColor = Color.Transparent
            };
            this.Controls.Add(lblStatus);

            // Footer info
            lblFooter = new Label
            {
                Text = "⚡ Uprawnienia administratora • Windows 10 & 11 Ready",
                Font = new Font("Segoe UI", 8.5f, FontStyle.Regular),
                ForeColor = Color.FromArgb(100, 116, 139), // #64748B
                Location = new Point(32, 212),
                Size = new Size(330, 20),
                BackColor = Color.Transparent
            };
            this.Controls.Add(lblFooter);

            lblVersion = new Label
            {
                Text = "v1.0",
                Font = new Font("Segoe UI", 8.5f, FontStyle.Bold),
                ForeColor = Color.FromArgb(100, 116, 139), // #64748B
                Location = new Point(410, 212),
                Size = new Size(60, 20),
                TextAlign = ContentAlignment.TopRight,
                BackColor = Color.Transparent
            };
            this.Controls.Add(lblVersion);

            // Timer do animacji paska i rotacji komunikatów
            animTimer = new System.Windows.Forms.Timer();
            animTimer.Interval = 25; // ~40 FPS
            animTimer.Tick += (s, e) =>
            {
                pulsePos += pulseDir;
                if (pulsePos > 310 || pulsePos < 0)
                {
                    pulseDir = -pulseDir;
                }

                stepCounter++;
                if (stepCounter >= 30) // zmiana co ~750ms
                {
                    stepCounter = 0;
                    statusStep = (statusStep + 1) % statusMessages.Length;
                    lblStatus.Text = statusMessages[statusStep];
                }

                this.Invalidate(new Rectangle(32, 154, 436, 14));
            };
            animTimer.Start();
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            // 1. Obrys okna i górny akcent
            using (Pen borderPen = new Pen(Color.FromArgb(34, 41, 58), 1)) // #22293A
            {
                g.DrawRectangle(borderPen, 0, 0, this.Width - 1, this.Height - 1);
            }
            using (Pen topAccentPen = new Pen(Color.FromArgb(37, 99, 235), 2)) // #2563EB
            {
                g.DrawLine(topAccentPen, 0, 0, this.Width, 0);
            }

            // 2. Tło i animowany pasek ładowania
            int barX = 32;
            int barY = 156;
            int barWidth = 436;
            int barHeight = 6;

            // Track paska
            using (SolidBrush trackBrush = new SolidBrush(Color.FromArgb(21, 25, 36))) // #151924
            {
                g.FillRectangle(trackBrush, barX, barY, barWidth, barHeight);
            }
            using (Pen trackPen = new Pen(Color.FromArgb(34, 41, 58), 1))
            {
                g.DrawRectangle(trackPen, barX, barY, barWidth, barHeight);
            }

            // Animowany świecący wskaźnik gradientowy (pulse)
            int pulseWidth = 110;
            int currentPulseX = barX + (int)((pulsePos / 310.0f) * (barWidth - pulseWidth));
            Rectangle pulseRect = new Rectangle(currentPulseX, barY, pulseWidth, barHeight);

            using (LinearGradientBrush pulseBrush = new LinearGradientBrush(
                pulseRect,
                Color.FromArgb(37, 99, 235),  // #2563EB
                Color.FromArgb(56, 189, 248), // #38BDF8
                LinearGradientMode.Horizontal))
            {
                g.FillRectangle(pulseBrush, pulseRect);
            }
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                if (animTimer != null)
                {
                    animTimer.Stop();
                    animTimer.Dispose();
                }
            }
            base.Dispose(disposing);
        }
    }

    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string scriptPath = Path.Combine(baseDir, "OpenUnbloat.ps1");

            if (!File.Exists(scriptPath))
            {
                MessageBox.Show(
                    "Nie odnaleziono głównego skryptu 'OpenUnbloat.ps1' w folderze:\n" + baseDir,
                    "OpenUnbloat - Błąd",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
                return;
            }

            string extraArgs = "-GUI";
            if (args != null && args.Length > 0)
            {
                extraArgs = string.Join(" ", args);
            }

            bool isAdmin = false;
            try
            {
                using (WindowsIdentity identity = WindowsIdentity.GetCurrent())
                {
                    WindowsPrincipal principal = new WindowsPrincipal(identity);
                    isAdmin = principal.IsInRole(WindowsBuiltInRole.Administrator);
                }
            }
            catch { }

            if (!isAdmin)
            {
                ProcessStartInfo elevatePsi = new ProcessStartInfo();
                elevatePsi.FileName = Application.ExecutablePath;
                elevatePsi.Arguments = extraArgs;
                elevatePsi.Verb = "runas";
                elevatePsi.UseShellExecute = true;
                try
                {
                    Process.Start(elevatePsi);
                }
                catch { }
                return;
            }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            bool isGuiMode = extraArgs.IndexOf("-GUI", StringComparison.OrdinalIgnoreCase) >= 0;

            if (!isGuiMode)
            {
                // Tryb konsolowy (CLI)
                ProcessStartInfo cliPsi = new ProcessStartInfo();
                cliPsi.FileName = "powershell.exe";
                cliPsi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + scriptPath + "\" " + extraArgs;
                cliPsi.WorkingDirectory = baseDir;
                cliPsi.UseShellExecute = false;
                try
                {
                    Process p = Process.Start(cliPsi);
                    p.WaitForExit();
                }
                catch (Exception ex)
                {
                    MessageBox.Show("Błąd uruchomienia w trybie CLI: " + ex.Message, "Błąd", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
                return;
            }

            // Tryb GUI: Błyskawiczny natywny ekran powitalny (Splash Screen <30ms)
            using (EventWaitHandle readyEvent = new EventWaitHandle(false, EventResetMode.ManualReset, "OpenUnbloat_ReadySignal"))
            using (SplashScreenForm splash = new SplashScreenForm())
            {
                splash.Show();
                Application.DoEvents();

                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "powershell.exe";
                psi.Arguments = "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + scriptPath + "\" " + extraArgs;
                psi.WorkingDirectory = baseDir;
                psi.UseShellExecute = false;
                psi.CreateNoWindow = true;
                psi.WindowStyle = ProcessWindowStyle.Hidden;

                Process proc = null;
                try
                {
                    proc = Process.Start(psi);
                }
                catch (Exception ex)
                {
                    splash.Close();
                    MessageBox.Show(
                        "Wystąpił błąd podczas uruchamiania skryptu PowerShell:\n" + ex.Message,
                        "Błąd uruchamiania",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error
                    );
                    return;
                }

                // Oczekiwanie na sygnał wyrenderowania głównego okna WPF z płynną animacją splash screena
                DateTime startTime = DateTime.Now;
                while (!readyEvent.WaitOne(20))
                {
                    Application.DoEvents();

                    if (proc.HasExited)
                    {
                        break;
                    }

                    // Zabezpieczenie przed zawieszeniem (maks. 35 sekund)
                    if ((DateTime.Now - startTime).TotalSeconds > 35)
                    {
                        break;
                    }
                }

                splash.Close();

                if (proc.HasExited && !readyEvent.WaitOne(0))
                {
                    if (proc.ExitCode != 0)
                    {
                        MessageBox.Show(
                            "Proces PowerShell zakończył działanie przed uruchomieniem okna graficznego (Kod: " + proc.ExitCode + ").\nSprawdź dziennik błędów.",
                            "Błąd uruchamiania",
                            MessageBoxButtons.OK,
                            MessageBoxIcon.Warning
                        );
                    }
                }
            }
        }
    }
}
