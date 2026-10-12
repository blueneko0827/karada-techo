# Karada Techo - one-time setup on Windows (PowerShell). Needs Flutter 3.32 or newer.
# Run from the project folder:  powershell -ExecutionPolicy Bypass -File .\setup.ps1
$ErrorActionPreference = 'Stop'

Write-Host '1/6  Generating android/ and ios/ folders...'
flutter create --org jp.kaitosoft --project-name karada_techo --platforms android,ios .

$gradle = 'android\app\build.gradle.kts'
if (!(Test-Path $gradle)) { throw 'android\app\build.gradle.kts not found. Update Flutter to 3.32 or newer (flutter upgrade) and run this again.' }

Write-Host '2/6  Installing the Android manifest (permissions, Health Connect, reminders)...'
Copy-Item platform_setup\android\AndroidManifest.xml android\app\src\main\AndroidManifest.xml -Force

Write-Host '3/6  Adding the notification icon...'
New-Item -ItemType Directory -Force android\app\src\main\res\drawable | Out-Null
New-Item -ItemType Directory -Force android\app\src\main\res\raw | Out-Null
Copy-Item platform_setup\android\res\drawable\ic_stat_notify.xml android\app\src\main\res\drawable\ -Force
Copy-Item platform_setup\android\res\raw\keep.xml android\app\src\main\res\raw\ -Force

Write-Host '4/6  Switching MainActivity to FlutterFragmentActivity (needed by Health Connect)...'
$kt = 'android\app\src\main\kotlin\jp\kaitosoft\karada_techo\MainActivity.kt'
if (Test-Path $kt) { Copy-Item platform_setup\android\MainActivity.kt $kt -Force }
else { Write-Warning "Could not find $kt - copy platform_setup\android\MainActivity.kt there by hand." }

Write-Host '5/6  Patching build.gradle.kts (minSdk 26, core library desugaring)...'
$g = Get-Content $gradle -Raw
if ($g -match 'minSdk = flutter\.minSdkVersion') { $g = $g -replace 'minSdk = flutter\.minSdkVersion', 'minSdk = 26' }
elseif ($g -notmatch 'minSdk = 26') { Write-Warning 'minSdk line not found - set minSdk = 26 by hand.' }
if ($g -notmatch 'isCoreLibraryDesugaringEnabled') {
  $g = $g -replace 'compileOptions \{', "compileOptions {`n        isCoreLibraryDesugaringEnabled = true"
}
if ($g -notmatch 'desugar_jdk_libs') {
  $g = $g + "`ndependencies {`n    coreLibraryDesugaring(`"com.android.tools:desugar_jdk_libs:2.1.4`")`n}`n"
}
[System.IO.File]::WriteAllText((Resolve-Path $gradle), $g)

# Force plugins (health) to compile against API 36; goes at the top of the root build file.
Copy-Item platform_setup\android\force_compile_sdk.gradle android\force_compile_sdk.gradle -Force
$root = 'android\build.gradle.kts'
$r = Get-Content $root -Raw
if ($r -notmatch 'force_compile_sdk') {
  [System.IO.File]::WriteAllText((Resolve-Path $root), "apply(from = `"force_compile_sdk.gradle`")`n`n" + $r)
}

Write-Host '6/6  Fetching packages and generating launcher icons...'
flutter pub get
dart run flutter_launcher_icons

Write-Host ''
Write-Host 'Done. Next:'
Write-Host '  - Put NotoSansJP-Regular.ttf in assets\fonts\ (see assets\fonts\README.txt) for PDF reports'
Write-Host '  - Start an Android emulator or plug in a phone, then:  flutter run'
