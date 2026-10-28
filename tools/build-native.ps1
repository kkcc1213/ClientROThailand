<#
.SYNOPSIS
  Build ไฟล์ native ที่ client ต้องใช้ ด้วย MSVC (x86): STOVE SDK stub + binkw32 proxy (ถ้าจำเป็น)

.DESCRIPTION
  - basesdk.dll / iapsdk.dll : stub ของ STOVE PC SDK ที่ exe kRO 2025 import ไว้ (ไม่ถูกเรียกจริงเมื่อเล่นกับ server ในเครื่อง)
  - binkw32.dll              : ตัวกลางที่ส่งต่อทุก export ไป binkw32_th.dll แล้วเพิ่ม _BinkShouldSkip@4
                               สร้างเฉพาะเมื่อ binkw32.dll ที่ให้มาไม่มี export นี้
  ต้องมี Visual Studio 2022 Build Tools (workload C++)

.EXAMPLE
  .\build-native.ps1 -OutDir F:\ROClient -BinkDll "F:\Gravity\Ragnarok Online\binkw32.dll"
#>
param(
    [Parameter(Mandatory)][string]$OutDir,
    [string]$BinkDll
)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

function Get-VsTools {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { throw 'ไม่พบ vswhere — ติดตั้ง Visual Studio 2022 Build Tools (C++) ก่อน' }
    $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vs) { throw 'ไม่พบ MSVC (Microsoft.VisualStudio.Component.VC.Tools.x86.x64)' }
    $msvc = Get-ChildItem "$vs\VC\Tools\MSVC" -Directory | Sort-Object Name | Select-Object -Last 1
    [pscustomobject]@{ Vcvars = "$vs\VC\Auxiliary\Build\vcvars32.bat"; Dumpbin = "$($msvc.FullName)\bin\Hostx64\x86\dumpbin.exe" }
}

function Invoke-Cl([string]$Vcvars, [string]$WorkDir, [string]$ClArgs) {
    $out = cmd /c "`"$Vcvars`" >nul 2>nul && cd /d `"$WorkDir`" && cl /nologo $ClArgs 2>&1"
    if ($LASTEXITCODE -ne 0) { $out | Write-Host; throw "cl ล้มเหลว: $ClArgs" }
}

$tools = Get-VsTools
$build = Join-Path $env:TEMP "rothai-native-build"
Remove-Item $build -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $build, $OutDir | Out-Null

# STOVE stub: source เดียว · .def คนละไฟล์
Copy-Item "$here\stove-stub\*" $build
foreach ($dll in 'basesdk', 'iapsdk') {
    Invoke-Cl $tools.Vcvars $build "/O2 /MT /W4 /LD stove_stub.cpp /Fe:$dll.dll /link /DEF:$dll.def /NOLOGO"
    Copy-Item "$build\$dll.dll" $OutDir -Force
}
Write-Host "stub: basesdk.dll, iapsdk.dll -> $OutDir"

# binkw32 proxy
if ($BinkDll) {
    $dump = & $tools.Dumpbin /nologo /exports $BinkDll
    if ($LASTEXITCODE -ne 0) { throw "dumpbin อ่าน $BinkDll ไม่ได้" }
    $exports = @($dump | ForEach-Object {
        if ($_ -match '^\s+(\d+)\s+[0-9A-F]+\s+[0-9A-F]{8}\s+(\S+)') { [pscustomobject]@{ Ord = $Matches[1]; Name = $Matches[2] } }
    })
    if ($exports.Count -lt 10) { throw "อ่าน export ของ $BinkDll ได้แค่ $($exports.Count) ตัว — ไม่น่าใช่ binkw32" }
    if ($exports.Name -contains '_BinkShouldSkip@4') {
        Copy-Item $BinkDll "$OutDir\binkw32.dll" -Force
        Write-Host 'binkw32.dll มี _BinkShouldSkip@4 อยู่แล้ว — ใช้ตัวเดิม'
    } else {
        $def = @('LIBRARY binkw32', 'EXPORTS') + ($exports | ForEach-Object { "    $($_.Name)=binkw32_th.$($_.Name) @$($_.Ord)" }) + '    _BinkShouldSkip@4=_BinkShouldSkipStub@4'
        $def | Set-Content -Encoding ascii "$build\binkw32.def"
        Copy-Item "$here\bink-proxy\bink_proxy.cpp" $build
        Invoke-Cl $tools.Vcvars $build '/O2 /MT /LD bink_proxy.cpp /Fe:binkw32.dll /link /DEF:binkw32.def /NOLOGO /NOENTRY'
        $target = [IO.Path]::GetFullPath("$OutDir\binkw32_th.dll")
        if ([IO.Path]::GetFullPath($BinkDll) -ine $target) { Copy-Item $BinkDll $target -Force }
        Copy-Item "$build\binkw32.dll" "$OutDir\binkw32.dll" -Force
        Write-Host "binkw32 proxy: ส่งต่อ $($exports.Count) export ไป binkw32_th.dll + เพิ่ม _BinkShouldSkip@4"
    }
}
