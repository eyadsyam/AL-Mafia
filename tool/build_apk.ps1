# Builds the Android release APK with online play switched on.
#
# Saved with a UTF-8 BOM on purpose. Windows PowerShell 5.1 reads a BOM-less
# file in the machine's ANSI code page, where the em dashes in the comments
# below decode into a smart quote, the parser takes that as the start of a
# string, and it reports a missing terminator ninety lines further down.
#
# ## The bug this script exists to prevent
#
# `SupabaseConfig` reads its URL and key from `String.fromEnvironment`, which is
# resolved at **compile time**. A build that was not given them has
# `isConfigured == false`, and the mode screen then offers "play online" as an
# explained, dead card — correctly, because there is no server in that binary to
# talk to.
#
# So `flutter build apk --release` on its own produces an APK whose online mode
# can never work, and it does it silently: the build succeeds, the app runs, the
# offline game is perfect, and online is simply not there. That is not a bug in
# the app. It is a build invoked without its arguments.
#
# `dart_defines.json` is git-ignored on purpose — the publishable key is not a
# secret the way a service key is, but it is still per-deployment, and a
# checked-in one is a checked-in one. Copy `dart_defines.example.json` to
# `dart_defines.json` and fill it in once; after that this script is the whole
# of the build.
#
#   pwsh tool/build_apk.ps1              # release APK, one fat binary
#   pwsh tool/build_apk.ps1 -Split       # one APK per ABI, ~40% smaller each
#   pwsh tool/build_apk.ps1 -Bundle      # an .aab for Play
#
# Signing: `android/key.properties` if it exists, the debug key otherwise. See
# the note at the top of `android/app/build.gradle.kts`.

param(
    [switch]$Split,
    [switch]$Bundle
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$defines = Join-Path $root 'dart_defines.json'
if (-not (Test-Path $defines)) {
    Write-Host ''
    Write-Host 'No dart_defines.json.' -ForegroundColor Red
    Write-Host 'Online mode would compile out of this build and the card would'
    Write-Host 'be dead in the app. Copy the example and fill it in:'
    Write-Host ''
    Write-Host '    Copy-Item dart_defines.example.json dart_defines.json'
    Write-Host ''
    exit 1
}

# Read it back rather than trusting that it was filled in: a file still holding
# `https://<project-ref>.supabase.co` builds and fails at the first call.
$config = Get-Content $defines -Raw | ConvertFrom-Json
if (-not $config.SUPABASE_URL -or $config.SUPABASE_URL -match '<' -or
    -not $config.SUPABASE_KEY -or $config.SUPABASE_KEY -match '\.\.\.') {
    Write-Host ''
    Write-Host 'dart_defines.json still holds the placeholders.' -ForegroundColor Red
    Write-Host 'Fill in SUPABASE_URL and SUPABASE_KEY from the project dashboard.'
    Write-Host ''
    exit 1
}

$adsEnabled = "$($config.ADS_ENABLED)".ToLowerInvariant() -eq 'true'
$adTestMode = "$($config.ADMOB_TEST_MODE)".ToLowerInvariant() -eq 'true'
$sampleAdMobAppId = 'ca-app-pub-3940256099942544~3347511713'
if ($adsEnabled -and -not $adTestMode) {
    if (-not $config.ADMOB_APP_ID -or
        $config.ADMOB_APP_ID -notmatch '^ca-app-pub-\d{16}~\d{10}$' -or
        -not $config.ADMOB_REWARDED_ANDROID_ID -or
        $config.ADMOB_REWARDED_ANDROID_ID -notmatch '^ca-app-pub-\d{16}/\d{10}$') {
        Write-Host 'ADS_ENABLED requires production ADMOB_APP_ID and ADMOB_REWARDED_ANDROID_ID.'
        exit 1
    }
}
$env:ORG_GRADLE_PROJECT_ADMOB_APP_ID = if ($adsEnabled -and -not $adTestMode) {
    $config.ADMOB_APP_ID
} else {
    $sampleAdMobAppId
}

# Phase 100: with ads off, the release manifest drops the ad SDK's
# advertising-ID / AdServices permissions (android/app/src/noAds), so the Play
# Advertising ID and Data safety answers match the binary.
$env:ORG_GRADLE_PROJECT_ADS_PERMISSIONS = if ($adsEnabled) { 'keep' } else { 'strip' }

$billingEnabled = "$($config.PLAY_BILLING_ENABLED)".ToLowerInvariant() -eq 'true'
if ($billingEnabled -and -not $config.PLAY_SCENARIO_PRODUCT_ID) {
    Write-Host 'PLAY_BILLING_ENABLED requires PLAY_SCENARIO_PRODUCT_ID.'
    exit 1
}

if ($Bundle) {
    $target  = 'appbundle'
    $outDir  = 'build/app/outputs/bundle/release'
    $pattern = '*.aab'
} else {
    $target  = 'apk'
    $outDir  = 'build/app/outputs/flutter-apk'
    $pattern = '*.apk'
}

# `$args` is an automatic variable in PowerShell; this one is ours.
# `--split-debug-info` strips the Dart symbol table out of `libapp.so` and
# leaves it in `build/symbols`, where a crash from a released build can still be
# symbolised against it. Worth 1.2 MB of the download and nothing at runtime.
# Not paired with `--obfuscate`: renaming saves almost nothing more here and can
# only be trusted after a full pass on a real device.
$flutterArgs = @('build', $target, '--release', "--dart-define-from-file=$defines",
                 '--split-debug-info=build/symbols')
if ($Split -and -not $Bundle) { $flutterArgs += '--split-per-abi' }

Write-Host "flutter $($flutterArgs -join ' ')" -ForegroundColor DarkGray
& flutter @flutterArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# R8 full mode once stripped constructors that Android reaches by reflection
# before Dart starts, and every release build crashed on launch. The build
# itself succeeded, so check R8's own removal report. See proguard-rules.pro.
& python tool/check_android_r8.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host "Built: $outDir" -ForegroundColor Green
Get-ChildItem -Path $outDir -Filter $pattern | ForEach-Object {
    Write-Host ("  {0}  {1:N1} MB" -f $_.Name, ($_.Length / 1MB))
}
