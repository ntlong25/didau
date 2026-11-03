param([string]$ApiBaseUrl = 'http://localhost:5000/api', [int]$Samples = 20)
$ErrorActionPreference = 'Stop'
if ($Samples -lt 1) { throw 'Samples must be positive.' }
$root = Split-Path $PSScriptRoot -Parent
$records = [Collections.Generic.List[object]]::new()
$variant = Get-Random -Minimum 10000 -Maximum 10000000
function Measure-Request([string]$kind, [string]$endpoint, [hashtable]$body) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $null = Invoke-RestMethod -Uri "$ApiBaseUrl/$endpoint" -Method Post -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 8) -TimeoutSec 30
    $watch.Stop()
    $records.Add([pscustomobject]@{Kind=$kind;Milliseconds=$watch.Elapsed.TotalMilliseconds})
}
Write-Host 'This calls real configured providers and may incur API charges. Uses public Hoan Kiem coordinates; respects rate limits.'
for ($i=0; $i -lt $Samples; $i++) {
    Measure-Request 'suggestions' 'suggestions' @{ location=@{lat=21.0288;lng=105.852};need='Coffee';radiusMeters=2000 }
    Start-Sleep -Milliseconds 2100
}
for ($i=0; $i -lt $Samples; $i++) {
    $request = @{cityId='hanoi';duration='HalfDay';interests=@('History');variant=($variant+$i)}
    Measure-Request 'tour-new' 'tours' $request
    Start-Sleep -Milliseconds 12500
    Measure-Request 'tour-cached' 'tours' $request
    Start-Sleep -Milliseconds 12500
}
$limits = @{'suggestions'=5000;'tour-new'=20000;'tour-cached'=3000}
$summary = $records | Group-Object Kind | ForEach-Object {
    $values = @($_.Group.Milliseconds | Sort-Object)
    $p90 = $values[[Math]::Ceiling($values.Count * .9)-1]
    [pscustomobject]@{Kind=$_.Name;Samples=$values.Count;P90Milliseconds=[Math]::Round($p90,1);TargetMilliseconds=$limits[$_.Name];Pass=($p90 -le $limits[$_.Name])}
}
$dir = Join-Path $root 'artifacts'
New-Item -ItemType Directory -Force $dir | Out-Null
@{ measuredAt=[DateTimeOffset]::UtcNow; summary=@($summary); measurements=@($records) } | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $dir 'performance.json') -Encoding utf8
$summary | Format-Table
