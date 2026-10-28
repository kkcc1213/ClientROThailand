# เปิด client (RunAsInvoker) แล้วจดหน้าต่าง/กล่องข้อความที่ขึ้นมา ทุก 1 วินาที
param([int]$Seconds = 40)
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class WC { public delegate bool EP(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EP f, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EP f, IntPtr l);
[DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr h, out int p);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
static string T(IntPtr h){var t=new StringBuilder(2048); GetWindowText(h,t,2048); return t.ToString();}
static string C(IntPtr h){var c=new StringBuilder(256); GetClassName(h,c,256); return c.ToString();}
public static List<string> Get(int pid){ var r=new List<string>(); EnumWindows((h,l)=>{int p; GetWindowThreadProcessId(h,out p); if(p==pid && IsWindowVisible(h)){ var s="["+C(h)+"] "+T(h); EnumChildWindows(h,(c,l2)=>{ var x=T(c); if(C(c)=="Static" && x.Length>0) s+=" | "+x; return true;},IntPtr.Zero); r.Add(s);} return true;},IntPtr.Zero); return r; } }
"@
$c = "F:\CreateGame\ROThailand\client"; $env:__COMPAT_LAYER = 'RunAsInvoker'
$p = Start-Process -FilePath "$c\2025-06-04_Ragexe_1748494356_clientinfo.xml_patched.exe" -ArgumentList '1rag1' -WorkingDirectory $c -PassThru
$seen = @{}
for ($i = 0; $i -lt $Seconds; $i++) {
    Start-Sleep 1
    if ($p.HasExited) { "t=$i exited 0x{0:X8}" -f $p.ExitCode; break }
    foreach ($w in [WC]::Get($p.Id)) { if (-not $seen[$w]) { $seen[$w] = 1; "t=$i $w" } }
    if ($i % 10 -eq 9) { $p.Refresh(); "t=$i MB=$([int]($p.WorkingSet64/1MB)) cpu=$([int]$p.CPU) threads=$($p.Threads.Count)" }
}
"pid=$($p.Id)"
