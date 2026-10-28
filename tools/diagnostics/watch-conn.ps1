# จด TCP connection ไป/จากพอร์ตของ server (6900/6121/5121/8888) ทุก 20 ms ลงไฟล์ (รันแยกเป็น process เบื้องหลัง)
param([string]$Out, [int]$Seconds = 90)
$ports = 6900, 6121, 5121, 8888
$props = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
$seen = @{}; $t0 = Get-Date
Set-Content $Out "start $(Get-Date -Format HH:mm:ss.fff)"
while (((Get-Date) - $t0).TotalSeconds -lt $Seconds) {
    foreach ($cn in $props.GetActiveTcpConnections()) {
        if ($ports -notcontains $cn.RemoteEndPoint.Port) { continue }
        $k = "$($cn.LocalEndPoint) -> $($cn.RemoteEndPoint) $($cn.State)"
        if (-not $seen[$k]) { $seen[$k] = 1; Add-Content $Out ("{0:HH:mm:ss.fff} {1}" -f (Get-Date), $k) }
    }
    Start-Sleep -Milliseconds 20
}
