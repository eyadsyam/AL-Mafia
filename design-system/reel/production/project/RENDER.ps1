param([string]$OutputPath = (Join-Path $PSScriptRoot '..\exports\MAFIA_ONLINE_REEL_AR_59s.mp4'))
$ErrorActionPreference = 'Stop'
$browserPath = (& npx.cmd --yes hyperframes@0.8.145 browser path | Select-Object -Last 1).Trim()
if (Test-Path -LiteralPath $browserPath) { $env:HYPERFRAMES_BROWSER_PATH = $browserPath }
& npx.cmd --yes hyperframes@0.8.145 check $PSScriptRoot
if ($LASTEXITCODE -ne 0) { throw 'Composition check failed.' }
$rawPath = $OutputPath + '.raw.mp4'
& npx.cmd --yes hyperframes@0.8.145 render $PSScriptRoot --quality delivery --fps 30 --workers 4 -o $rawPath
if ($LASTEXITCODE -ne 0) { throw 'Render failed.' }
& python (Join-Path $PSScriptRoot '..\finish_export.py') --input $rawPath --output $OutputPath
if ($LASTEXITCODE -ne 0) { throw 'Export verification failed.' }
