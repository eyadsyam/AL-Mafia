$ErrorActionPreference='Stop'
$env:HYPERFRAMES_BROWSER_PATH='C:\Users\LENOVO\.cache\puppeteer\chrome-headless-shell\win64-152.0.7977.54\chrome-headless-shell-win64\chrome-headless-shell.exe'
Push-Location -LiteralPath (Join-Path $PSScriptRoot 'project')
try {
  npx --yes hyperframes@0.8.147 render --quality delivery --crf 0 --video-frame-format png --output ../exports/MAFIA_V3_LOSSLESS_RENDER.mp4
  if ($LASTEXITCODE -ne 0) { throw 'Lossless picture render failed' }
  python ../export_hq.py
  if ($LASTEXITCODE -ne 0) { throw 'HQ mastering or validation failed' }
} finally { Pop-Location }
