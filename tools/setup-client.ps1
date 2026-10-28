<#
.SYNOPSIS
  ประกอบ client ROThailand ที่เล่นกับ rAthena-Thailand ได้ จาก client ฐานของ Gravity + overlay ใน repo นี้

.DESCRIPTION
  ทดสอบแล้วกับ client ฐาน iRO (Gravity Interactive, patch ก.ย. 2025) บน Windows ภาษาไทย
  ไฟล์ลิขสิทธิ์ของ Gravity (data.grf, ฟอนต์, Setup.exe, DLL) คัดจากเครื่องตอนติดตั้ง ไม่ได้อยู่ใน repo

  ขั้นตอน:
   1. คัด DLL / BGM / AI / System / skin / Setup.exe จาก client ฐาน (ไม่เอา exe และ grf อื่น)
   2. วาง overlay (Client-2025-06-04\<Variant>) ทับ + exe ที่ patch แล้ว
   3. build STOVE stub + binkw32 proxy (tools\build-native.ps1)
   4. ใช้ VC++ runtime ของ Windows แทนรุ่นเก่าที่ติดมากับ client ฐาน
   5. คัด data.grf (ตั้ง read-only เพราะ exe 2025 เขียนทับ header ของ grf บางรุ่น)
   6. สร้าง rothai.grf: ไฟล์ overlay ในโฟลเดอร์ชื่อเกาหลี (ชื่อแปลงกลับเป็น cp949) + หน้าล็อกอินแบบใหม่ที่วาดเอง
      + login.rsw (prontera จาก client ฐาน)
   7. DATA.ini, licence.txt, start-client.cmd

.EXAMPLE
  .\setup-client.ps1 -BaseClient "F:\Gravity\Ragnarok Online" -OutDir "F:\ROThailand\client"
#>
param(
    [Parameter(Mandatory)][string]$BaseClient,
    [Parameter(Mandatory)][string]$OutDir,
    [ValidateSet('Renewal', 'Pre-Renewal')][string]$Variant = 'Renewal',
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$clientSrc = Join-Path $repo 'Client-2025-06-04'
$exeName = '2025-06-04_Ragexe_1748494356_clientinfo.xml_patched.exe'

function Step([string]$Text) { Write-Host "==> $Text" -ForegroundColor Cyan }

# robocopy: exit code 8 ขึ้นไป = ล้มเหลว · /R:1 /W:1 กันค้างนานเมื่อไฟล์ถูกล็อก (เช่น client ยังเปิดอยู่)
function Copy-Tree([string]$From, [string]$To, [string[]]$Extra) {
    robocopy $From $To @Extra /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy $From -> $To ล้มเหลว ($LASTEXITCODE)" }
}

function Invoke-Py([string[]]$PyArgs) {
    & $Python -I @PyArgs
    if ($LASTEXITCODE -ne 0) { throw "python $($PyArgs -join ' ') ล้มเหลว ($LASTEXITCODE)" }
}

$BaseClient = (Resolve-Path $BaseClient).Path.TrimEnd('\')
$OutDir = [IO.Path]::GetFullPath($OutDir).TrimEnd('\')
if ($OutDir -ieq $BaseClient) { throw '-OutDir ต้องไม่ใช่โฟลเดอร์เดียวกับ -BaseClient' }
foreach ($need in "$BaseClient\data.grf", "$clientSrc\$Variant", "$clientSrc\$exeName") {
    if (-not (Test-Path $need)) { throw "ไม่พบ $need" }
}
& $Python -I -c 'import PIL' 2>$null
if ($LASTEXITCODE -ne 0) { throw "ต้องมี Pillow ใน site-packages หลักของ $Python (pip install pillow — ไม่ใช่ --user เพราะรันด้วย -I)" }
New-Item -ItemType Directory -Force $OutDir | Out-Null

Step '1. คัดไฟล์ประกอบจาก client ฐาน'
Copy-Tree $BaseClient $OutDir @('*.dll', '*.asi', '*.m3d', '*.manifest', 'Setup.exe')
foreach ($dir in 'BGM', 'AI', 'System', 'skin') {
    if (Test-Path "$BaseClient\$dir") { Copy-Tree "$BaseClient\$dir" "$OutDir\$dir" @('/E', '/MT:16') }
}

Step "2. overlay $Variant + exe"
Copy-Tree "$clientSrc\$Variant" $OutDir @('/E', '/MT:32')
Copy-Item "$clientSrc\$exeName" $OutDir -Force

Step '3. build STOVE stub + binkw32 proxy'
# ใช้ binkw32 ของ client ฐานเสมอ (ขั้น 1 เพิ่งคัด binkw32.dll ตัวเดิมทับ proxy ของรอบก่อน)
& "$PSScriptRoot\build-native.ps1" -OutDir $OutDir -BinkDll "$BaseClient\binkw32.dll"

Step '4. VC++ runtime ของ Windows'
$oldVcrt = Join-Path $OutDir '_old-vcrt'
foreach ($f in 'msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll', 'vcruntime140.dll', 'concrt140.dll', 'vccorlib140.dll') {
    if ((Test-Path "$OutDir\$f") -and (Test-Path "$env:windir\SysWOW64\$f")) {
        New-Item -ItemType Directory -Force $oldVcrt | Out-Null
        Move-Item "$OutDir\$f" $oldVcrt -Force
    }
}

Step '5. data.grf (read-only)'
$grf = Join-Path $OutDir 'data.grf'
if (Test-Path $grf) { Set-ItemProperty $grf -Name IsReadOnly -Value $false; Remove-Item $grf -Force }
# คัดลอกเสมอ ไม่ใช้ hardlink: hardlink จะทำให้ read-only และการเขียนทับ header ไปติดกับ client ฐานด้วย
Copy-Item "$BaseClient\data.grf" $grf
Set-ItemProperty $grf -Name IsReadOnly -Value $true

Step '6. rothai.grf (หน้าล็อกอิน)'
$work = Join-Path $env:TEMP 'rothai-grf'
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force "$work\login" | Out-Null
$grfTools = Join-Path $PSScriptRoot 'grf'
Invoke-Py @("$grfTools\make_login_assets.py", "$work\login") | Out-Null
Invoke-Py @("$grfTools\extract_grf_file.py", "$BaseClient\data.grf", 'data/prontera.rsw', "$work\login.rsw")
Invoke-Py @("$grfTools\login_manifest.py", "$work\login", "$work\login.rsw", "$work\manifest.txt")
# ไฟล์ overlay ในโฟลเดอร์ชื่อเกาหลี (ภาพ UI แปลไทย, sprite ฯลฯ) — เป็นไฟล์หลวมแล้ว client บน Windows ภาษาไทยหาไม่เจอ
Invoke-Py @("$grfTools\overlay_manifest.py", "$clientSrc\$Variant\data", "$work\overlay.txt")
Invoke-Py @("$grfTools\build_grf.py", "$OutDir\rothai.grf", "$work\overlay.txt", "$work\manifest.txt")

Step '7. DATA.ini · licence.txt · start-client.cmd'
[IO.File]::WriteAllText("$OutDir\DATA.ini", "[Data]`r`n0=rothai.grf`r`n1=data.grf`r`n", [Text.Encoding]::ASCII)
[IO.File]::WriteAllText("$OutDir\licence.txt", "ROThailand Local - test server only.`r`n", [Text.Encoding]::ASCII)
$cmd = '@echo off', 'rem Start the RO client without requesting admin rights (exe asks for requireAdministrator but does not need it)',
    'set __COMPAT_LAYER=RunAsInvoker', 'cd /d "%~dp0"', "start `"`" `"$exeName`" 1rag1"
[IO.File]::WriteAllText("$OutDir\start-client.cmd", ($cmd -join "`r`n") + "`r`n", [Text.Encoding]::ASCII)

if (-not (Test-Path 'HKLM:\SOFTWARE\WOW6432Node\Gravity Soft\RenewSetup')) {
    Write-Warning "ยังไม่มีค่าตั้งค่ากราฟิก (HKLM\SOFTWARE\WOW6432Node\Gravity Soft\RenewSetup) — เปิด $OutDir\Setup.exe หนึ่งครั้งแล้วกด OK ก่อนเล่น ไม่งั้น client จะค้าง"
}
Write-Host "เสร็จ: เปิดเกมด้วย $OutDir\start-client.cmd" -ForegroundColor Green
