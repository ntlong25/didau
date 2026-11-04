param([string]$Device = 'emulator-5554')
$ErrorActionPreference = 'Stop'
if ($Device -notmatch '^emulator-\d+$') { throw 'This destructive test runner only supports an emulator; it resets this app data.' }
$root = Split-Path $PSScriptRoot -Parent
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android/sdk' }
$adb = Join-Path $sdk 'platform-tools/adb.exe'
Push-Location (Join-Path $root 'app')
try {
    flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
    if ($LASTEXITCODE -ne 0) { throw 'Android build failed.' }
    # Split release APKs have ABI-specific version codes. Reset only the test
    # application so a later debug APK can be installed without a downgrade.
    $installed = & $adb -s $Device shell pm path vn.didau.di_dau
    if ($installed -match '^package:') { & $adb -s $Device uninstall vn.didau.di_dau }
    & $adb -s $Device install -r build/app/outputs/flutter-apk/app-debug.apk
    if ($LASTEXITCODE -ne 0) { throw 'APK install failed.' }
    & $adb -s $Device shell pm grant vn.didau.di_dau android.permission.ACCESS_COARSE_LOCATION
    & $adb -s $Device shell pm grant vn.didau.di_dau android.permission.ACCESS_FINE_LOCATION
    & $adb -s $Device shell settings put secure location_mode 3
    & $adb -s $Device emu geo fix 105.852 21.0288
    # Flutter may reinstall the test APK. Keep granting foreground permission and
    # feed fresh fixes while the native location listener is active.
    $gpsJob = Start-Job -ArgumentList $adb,$Device -ScriptBlock {
        param($adbPath,$deviceId)
        for ($i=0; $i -lt 180; $i++) {
            & $adbPath -s $deviceId shell pm grant vn.didau.di_dau android.permission.ACCESS_COARSE_LOCATION 2>$null
            & $adbPath -s $deviceId shell pm grant vn.didau.di_dau android.permission.ACCESS_FINE_LOCATION 2>$null
            & $adbPath -s $deviceId emu geo fix 105.852 21.0288 2>$null
            Start-Sleep -Seconds 2
        }
    }
    try {
        flutter test integration_test/android_smoke_test.dart -d $Device --dart-define=API_BASE_URL=http://127.0.0.1:5000/api
        if ($LASTEXITCODE -ne 0) { throw 'Android integration test failed.' }
    } finally { Stop-Job $gpsJob; Remove-Job $gpsJob }
} finally { Pop-Location }
