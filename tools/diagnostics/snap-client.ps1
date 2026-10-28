# ถ่ายภาพหน้าต่างหลักของ client (เฉพาะหน้าต่างนั้น ไม่ใช่ทั้งจอ) ลงไฟล์ PNG
param([string]$Out)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class SN {
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
public struct RECT { public int L, T, R, B; } }
"@
$p = Get-Process | Where-Object { $_.ProcessName -like '2025-06-04_Ragexe*' -and $_.MainWindowTitle -eq 'Ragnarok Online M-Script' } | Select-Object -First 1
if (-not $p) { 'no main window'; exit }
$r = New-Object SN+RECT; [void][SN]::GetWindowRect($p.MainWindowHandle, [ref]$r)
$w = $r.R - $r.L; $h = $r.B - $r.T; "rect $($r.L),$($r.T) ${w}x$h"
$bmp = New-Object System.Drawing.Bitmap $w, $h; $g = [System.Drawing.Graphics]::FromImage($bmp); $dc = $g.GetHdc()
[void][SN]::PrintWindow($p.MainWindowHandle, $dc, 2); $g.ReleaseHdc($dc); $g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose(); "saved $Out"
