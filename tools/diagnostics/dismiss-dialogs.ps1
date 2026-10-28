# จดและกด OK กล่องข้อความ (#32770) ของ client ที่รันอยู่ ไปเรื่อย ๆ จนครบเวลา
param([int]$Seconds = 60)
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class DD { public delegate bool EP(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EP f, IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EP f, IntPtr l);
[DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr h, out int p);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, int m, IntPtr w, IntPtr l);
static string T(IntPtr h){var t=new StringBuilder(4096); GetWindowText(h,t,4096); return t.ToString();}
static string C(IntPtr h){var c=new StringBuilder(256); GetClassName(h,c,256); return c.ToString();}
public static List<string> Sweep(int pid){ var r=new List<string>(); EnumWindows((h,l)=>{int p; GetWindowThreadProcessId(h,out p);
  if(p==pid && IsWindowVisible(h)){ string s="["+C(h)+"] "+T(h); IntPtr ok=IntPtr.Zero;
    EnumChildWindows(h,(c,l2)=>{ string cc=C(c), x=T(c); if(cc=="Static" && x.Length>0) s+=" | "+x.Replace("\n"," / "); if(cc=="Button" && (x=="OK"||x=="&OK"||x=="확인")) ok=c; return true;},IntPtr.Zero);
    if(C(h)=="#32770" && ok!=IntPtr.Zero){ PostMessage(ok,0xF5,IntPtr.Zero,IntPtr.Zero); s+="  -> OK"; }
    r.Add(s);} return true;},IntPtr.Zero); return r; } }
"@
$p = Get-Process | Where-Object { $_.ProcessName -like '2025-06-04_Ragexe*' } | Select-Object -First 1
if (-not $p) { 'no client'; exit }
$last = ''
for ($i = 0; $i -lt $Seconds; $i++) {
    if ($p.HasExited) { "t=$i exited 0x{0:X8}" -f $p.ExitCode; break }
    foreach ($w in [DD]::Sweep($p.Id)) { if ($w -ne $last) { "t=$i $w"; $last = $w } }
    Start-Sleep -Milliseconds 700
}
$p.Refresh(); "end MB=$([int]($p.WorkingSet64/1MB)) threads=$($p.Threads.Count)"
