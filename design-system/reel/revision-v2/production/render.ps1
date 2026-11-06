$ErrorActionPreference='Stop'
$env:HYPERFRAMES_BROWSER_PATH='C:\Users\LENOVO\.cache\puppeteer\chrome-headless-shell\win64-152.0.7977.54\chrome-headless-shell-win64\chrome-headless-shell.exe'
Set-Location -LiteralPath (Join-Path $PSScriptRoot 'project')
python ../build.py
npx --yes hyperframes@0.8.146 check
if ($LASTEXITCODE -ne 0) { throw 'HyperFrames check failed' }
npx --yes hyperframes@0.8.146 render --quality delivery --output ../exports/MAFIA_V2_RENDER.mp4
if ($LASTEXITCODE -ne 0) { throw 'Render failed' }
python ../finish.py
