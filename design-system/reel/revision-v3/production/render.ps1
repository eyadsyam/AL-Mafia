$ErrorActionPreference='Stop'
$env:HYPERFRAMES_BROWSER_PATH='C:\Users\LENOVO\.cache\puppeteer\chrome-headless-shell\win64-152.0.7977.54\chrome-headless-shell-win64\chrome-headless-shell.exe'
Set-Location -LiteralPath (Join-Path $PSScriptRoot 'project')
python ../build.py
python ../verify_media.py
if ($LASTEXITCODE -ne 0) { throw 'Source media window validation failed' }
npx --yes hyperframes@0.8.147 check
if ($LASTEXITCODE -ne 0) { throw 'HyperFrames check failed' }
npx --yes hyperframes@0.8.147 render --quality delivery --output ../exports/MAFIA_V3_RENDER.mp4
if ($LASTEXITCODE -ne 0) { throw 'Render failed' }
python ../finish.py
if ($LASTEXITCODE -ne 0) { throw 'Export mastering or validation failed' }
python ../audit_frames.py
if ($LASTEXITCODE -ne 0) { throw 'Decoded frame validation failed' }
python ../shot_breakdown.py
