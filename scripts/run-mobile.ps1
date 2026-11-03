# Requires PowerShell 7, dotnet, flutter, node, cloudflared and configured backend user-secrets.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
foreach ($tool in @('dotnet','flutter','node','cloudflared')) { Get-Command $tool -ErrorAction Stop | Out-Null }
$logDir = Join-Path $root ('artifacts/mobile-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$children = [Collections.Generic.List[Diagnostics.Process]]::new()
$originalOrigin = $env:Cors__AllowedOrigins__0
$originalEnvironment = $env:ASPNETCORE_ENVIRONMENT
function Start-Helper([string]$exe, [string[]]$arguments, [string]$name) {
    $process = Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logDir "$name.out.log") -RedirectStandardError (Join-Path $logDir "$name.err.log")
    $children.Add($process)
    return $process
}
function Read-TunnelUrl([string]$name, [Diagnostics.Process]$process) {
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($process.HasExited) { throw "Tunnel $name exited; inspect $logDir." }
        $content = Get-Content (Join-Path $logDir "$name.err.log") -Raw -ErrorAction SilentlyContinue
        $match = [regex]::Match([string]$content, 'https://[a-z0-9-]+\.trycloudflare\.com')
        if ($match.Success) { return $match.Value }
        Start-Sleep -Milliseconds 500
    }
    throw "Timed out waiting for tunnel $name."
}
try {
    $apiTunnel = Start-Helper 'cloudflared' @('tunnel','--url','http://127.0.0.1:5000','--no-autoupdate') 'api-tunnel'
    $appTunnel = Start-Helper 'cloudflared' @('tunnel','--url','http://127.0.0.1:8088','--no-autoupdate') 'app-tunnel'
    $apiUrl = Read-TunnelUrl 'api-tunnel' $apiTunnel
    $appUrl = Read-TunnelUrl 'app-tunnel' $appTunnel
    $env:Cors__AllowedOrigins__0 = $appUrl
    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    & (Join-Path $PSScriptRoot 'build-web.ps1') -ApiBaseUrl "$apiUrl/api"
    $null = Start-Helper 'dotnet' @('run','--project','backend/src/DiDau.Api','--no-launch-profile','--urls','http://127.0.0.1:5000') 'api'
    $null = Start-Helper 'node' @('scripts/serve-web.cjs') 'web'
    Write-Host "Mở trên điện thoại: $appUrl"
    Write-Host "API: $apiUrl/api"
    Write-Host "Origin $appUrl đã được thêm cho tiến trình API này. Nếu chạy API riêng, thêm vào Cors:AllowedOrigins."
    Write-Host 'Kiểm tra iOS Safari / Android Chrome: GPS, gợi ý, tour, thêm màn hình chính, mở offline. Nhấn Enter để dừng.'
    Read-Host | Out-Null
} finally {
    foreach ($process in $children) { if (!$process.HasExited) { $process.Kill($true); $process.WaitForExit() } }
    $env:Cors__AllowedOrigins__0 = $originalOrigin
    $env:ASPNETCORE_ENVIRONMENT = $originalEnvironment
}
