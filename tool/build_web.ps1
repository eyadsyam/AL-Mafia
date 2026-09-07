# Builds the web release and publishes it to the `gh-pages` branch.
#
# Same reason as `build_apk.ps1`: `SupabaseConfig` resolves at compile time, so
# a build that was not handed `dart_defines.json` ships with online compiled
# out. The site would still work — the offline game needs nothing — and the
# "play online" card would sit there explaining itself forever.
#
#   pwsh tool/build_web.ps1              # build only
#   pwsh tool/build_web.ps1 -Publish     # build, then force-push to gh-pages
#
# `--base-href` matters: the site is served from a repository subpath
# (`/AL-Mafia/`), not from a domain root, and a build without it asks for
# `/main.dart.js` and gets the GitHub Pages 404 page.
#
# MSYS2 rewrites any argument that looks like a Unix path, so `/AL-Mafia/`
# becomes `C:/Program Files/Git/AL-Mafia/` inside a Git Bash shell. The two
# environment variables below switch that off. Harmless in PowerShell, and the
# reason this is a script rather than a line in a README somebody retypes.

param(
    [switch]$Publish,
    [string]$BaseHref = '/AL-Mafia/',
    [string]$Branch = 'gh-pages',
    # The installable build, carried onto the site next to the web one so a
    # phone can go straight from the link to an installed app. `web/beta/`
    # holds the page; this is the file it points at.
    #
    # The arm64 split, not the universal one. The universal APK carries three
    # native ABIs and the 51 MB introduction video and lands around 147 MB —
    # over GitHub's hard 100 MB limit for a file in a repository, so a Pages
    # commit holding it is a push that is refused. arm64-v8a is every Android
    # phone shipped since about 2017, and it is the one a download link on a
    # phone is actually for. The universal build stays a direct artifact.
    [string]$ApkName = 'Mafia-Master-Beta-1.0.0-arm64.apk'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$defines = Join-Path $root 'dart_defines.json'
if (-not (Test-Path $defines)) {
    Write-Host 'No dart_defines.json — online would compile out of this build.' -ForegroundColor Red
    Write-Host '    Copy-Item dart_defines.example.json dart_defines.json'
    exit 1
}

$env:MSYS2_ARG_CONV_EXCL = '*'
$env:MSYS_NO_PATHCONV = '1'

Write-Host "flutter build web --release --base-href $BaseHref" -ForegroundColor DarkGray
& flutter build web --release --base-href $BaseHref "--dart-define-from-file=$defines"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$out = Join-Path $root 'build/web'

# `web/beta/` ships with the site; the APK it links to does not live in git, so
# it is copied in here from the last release build. Missing is not fatal — the
# site is still correct without it — but it is worth saying out loud, because a
# beta page whose download link 404s is worse than no beta page.
$apkSource = Join-Path $root 'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk'
$betaDir = Join-Path $out 'beta'
if ((Test-Path $apkSource) -and (Get-Item $apkSource).Length -lt 95MB) {
    if (-not (Test-Path $betaDir)) { New-Item -ItemType Directory -Path $betaDir | Out-Null }
    Copy-Item $apkSource (Join-Path $betaDir $ApkName) -Force
    $mb = (Get-Item $apkSource).Length / 1MB
    Write-Host ("Beta APK: {0}  ({1:N1} MB)" -f $ApkName, $mb) -ForegroundColor Green
} else {
    Write-Host 'The arm64 APK is absent or too large for GitHub Pages; publishing the site without embedding it.' -ForegroundColor Yellow
    Write-Host 'Run  pwsh tool/build_apk.ps1 -Split  first, or the download link on the beta page will 404.' -ForegroundColor Yellow
}

$files = (Get-ChildItem -Path $out -Recurse -File).Count
Write-Host ''
Write-Host "Built: build/web  ($files files)" -ForegroundColor Green

if (-not $Publish) {
    Write-Host 'Not published. Re-run with -Publish to force-push to gh-pages.'
    exit 0
}

# The branch holds build output and nothing else, so its history is not worth
# keeping: every publish is one commit with no parent. `git subtree` would be
# the tidy way and cannot be used here — `build/` is git-ignored, which is
# correct, and subtree only publishes tracked directories.
$sha = (& git rev-parse --short HEAD).Trim()
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("alm-pages-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    Copy-Item -Path (Join-Path $out '*') -Destination $temp -Recurse
    # Jekyll would otherwise eat every directory beginning with an underscore,
    # and Flutter's canvaskit build has several.
    New-Item -ItemType File -Path (Join-Path $temp '.nojekyll') | Out-Null

    Push-Location $temp
    & git init -q
    & git checkout -q -b $Branch
    & git add -A
    & git -c user.name="$(& git -C $root config user.name)" `
          -c user.email="$(& git -C $root config user.email)" `
          commit -q -m "Web release from $sha"
    & git remote add origin (& git -C $root remote get-url origin)
    & git push -q --force origin $Branch
    Pop-Location

    Write-Host "Published $Branch from $sha" -ForegroundColor Green
} finally {
    Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue
}
