$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$findings = @()
$files = Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {
    $_.FullName -notmatch '[\\/](\.git|\.dart_tool|bin|obj|\.claude|\.agents|node_modules)[\\/]' -and
    $_.Name -ne 'appsettings.Development.json' -and $_.Name -notlike '.env*' -and
    $_.Extension -in @('.cs','.json','.dart','.js','.html','.yaml','.yml','.md','.ps1')
}
foreach ($file in $files) {
    if (Select-String -LiteralPath $file.FullName -Pattern 'AIza[0-9A-Za-z_-]{30,}|sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{20,}' -Quiet) {
        $findings += [IO.Path]::GetRelativePath($root, $file.FullName)
    }
}
if ($findings.Count -gt 0) { $findings | ForEach-Object { Write-Host "Potential secret in: $_" }; throw 'Secret scan failed (values intentionally not printed).' }
Write-Host "Secret scan passed ($($files.Count) files, including built web assets when present)."
