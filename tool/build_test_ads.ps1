$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$temp = Join-Path $root 'build/phase80-test-ads-defines.json'
try {
  $config = Get-Content -LiteralPath 'dart_defines.json' -Raw | ConvertFrom-Json
  $config.ADS_ENABLED = 'true'
  $config.ADMOB_APP_ID = 'ca-app-pub-3940256099942544~3347511713'
  $config.ADMOB_REWARDED_ANDROID_ID = 'ca-app-pub-3940256099942544/5224354917'
  $config.ADMOB_TEST_MODE = 'true'
  $config.PLAY_BILLING_ENABLED = 'false'
  $config | ConvertTo-Json | Set-Content -LiteralPath $temp -Encoding utf8
  $env:ORG_GRADLE_PROJECT_ADMOB_APP_ID = $config.ADMOB_APP_ID
  $env:ORG_GRADLE_PROJECT_TEST_ADS_SUFFIX = 'true'
  $env:ORG_GRADLE_PROJECT_ADS_PERMISSIONS = 'keep'
  & flutter build apk --release "--dart-define-from-file=$temp" `
    '--split-debug-info=build/symbols-test-ads'
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & python tool/check_android_r8.py
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  # Moved, not copied: app-release.apk must never be the test-ad build, or the
  # next person to pick it up ships Google's sample ad unit.
  $version = ((Get-Content pubspec.yaml | Select-String '^version:').Line -split '[ +]')[1]
  New-Item -ItemType Directory -Force 'build/test-ads' | Out-Null
  Move-Item -LiteralPath 'build/app/outputs/flutter-apk/app-release.apk' `
    -Destination "build/test-ads/Mafia-Master-$version-test-ads.apk" -Force
  Remove-Item -LiteralPath 'build/app/outputs/flutter-apk/app-release.apk.sha1' `
    -Force -ErrorAction SilentlyContinue
} finally {
  Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
}
