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
  & flutter build apk --release "--dart-define-from-file=$temp" `
    '--split-debug-info=build/symbols-test-ads'
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-release.apk' `
    -Destination 'build/deliverables/Mafia-Master-1.0.0-test-ads.apk' -Force
} finally {
  Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
}
