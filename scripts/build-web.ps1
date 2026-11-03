param([string]$ApiBaseUrl = 'http://localhost:5000/api')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location (Join-Path $root 'app')
try {
    flutter build web --release --no-web-resources-cdn "--dart-define=API_BASE_URL=$ApiBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw 'Flutter web build failed.' }
    $web = (Resolve-Path 'build/web').Path
    $files = @(Get-ChildItem -LiteralPath $web -File -Recurse | Where-Object { $_.Name -notin @('sw.js', 'flutter_service_worker.js') } | Sort-Object FullName)
    $paths = @('./') + @($files | ForEach-Object { './' + [IO.Path]::GetRelativePath($web, $_.FullName).Replace('\', '/') })
    $hashes = ($files | ForEach-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }) -join ''
    $sha = [Security.Cryptography.SHA256]::Create()
    $version = [Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($hashes))).Substring(0,16)
    $template = Get-Content (Join-Path $PSScriptRoot 'service-worker.js') -Raw
    $script = $template.Replace('__VERSION__', $version).Replace('__FILES__', (ConvertTo-Json -InputObject $paths -Compress))
    Set-Content -LiteralPath (Join-Path $web 'sw.js') -Value $script -Encoding utf8
    Write-Host "Offline app shell generated: $($files.Count) assets, version $version"
} finally { Pop-Location }
