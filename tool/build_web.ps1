# Builds the web release and publishes it to the `gh-pages` branch.
#
# Saved with a UTF-8 BOM on purpose. Windows PowerShell 5.1 reads a BOM-less
# file in the machine's ANSI code page, where the em dashes in the comments
# below decode into a smart quote, the parser takes that as the start of a
# string, and it reports a missing terminator ninety lines further down.
#
# Same reason as `build_apk.ps1`: `SupabaseConfig` resolves at compile time, so
# a build that was not handed `dart_defines.json` ships with online compiled
# out. The site would still work — the offline game needs nothing — and the
# "play online" card would sit there explaining itself forever.
#
#   pwsh tool/build_web.ps1              # build only
#   pwsh tool/build_web.ps1 -Publish     # build, then force-push to gh-pages
#
# `--base-href` matters, and it is `/` because the site now lives at the root
# of its own domain (the Vercel project `almafia`) rather than under a GitHub
# Pages repository subpath. A build carrying the old `/AL-Mafia/` asks for
# `/AL-Mafia/main.dart.js` on a host that has no such directory and paints
# nothing. The root is also what made App Links possible: the host rewrites
# unknown paths to index.html, so `/join/CODE` is a real path and the router
# no longer needs the hash.
#
# MSYS2 rewrites any argument that looks like a Unix path, so a bare `/`
# becomes `C:/Program Files/Git/` inside a Git Bash shell. The two
# environment variables below switch that off. Harmless in PowerShell, and the
# reason this is a script rather than a line in a README somebody retypes.

param(
    [switch]$Publish,
    # Compiles in the web-only coin-pack tab (manual transfer review). Sales
    # still stay off until the server's COIN_SALES_ENABLED secret is "true".
    [switch]$CoinSales,
    [string]$BaseHref = '/',
    [string]$Branch = 'gh-pages'
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

$extra = @()
if ($CoinSales) { $extra += '--dart-define=WEB_COIN_SALES=true' }
Write-Host "flutter build web --release --base-href $BaseHref $extra" -ForegroundColor DarkGray
& flutter build web --release --base-href $BaseHref "--dart-define-from-file=$defines" @extra
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$out = Join-Path $root 'build/web'

# The offline cache.
#
# `web/flutter_bootstrap.js` registers `sw.js`; this is where that file comes
# from. It is stamped with a build time because a service worker is only
# reinstalled when its bytes differ, and a cache-first worker that is never
# reinstalled pins the site to the build that installed it.
#
# Flutter's own `flutter_service_worker.js` is left where it is: it is a stub
# that unregisters itself, which is exactly what an old visitor's browser needs
# to run once before it picks this one up.
$worker = Join-Path $root 'web/offline_service_worker.js'
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
# `-Encoding UTF8` because 5.1 otherwise reads a BOM-less file in the machine's
# ANSI code page and every em dash in the comments comes out as a replacement
# character in the deployed script.
$script = (Get-Content -Path $worker -Raw -Encoding UTF8) -replace '__BUILD_VERSION__', $stamp
# No BOM: this is served as text/javascript and read by the browser, not by
# PowerShell, and `Set-Content -Encoding utf8` on 5.1 writes one.
[System.IO.File]::WriteAllText(
    (Join-Path $out 'sw.js'),
    $script,
    (New-Object System.Text.UTF8Encoding($false)))
# `web/` is copied verbatim into the build, so the source would otherwise ship
# alongside the stamped copy.
Remove-Item -Path (Join-Path $out 'offline_service_worker.js') -Force -ErrorAction SilentlyContinue
Write-Host "Service worker: sw.js, offline cache, build $stamp" -ForegroundColor DarkGray

# The site carries the web build and nothing else. It used to also carry a
# `beta/` page with an APK next to it; that page went unused, and a 90 MB binary
# in a Pages commit is a slow push and a large repository for something nobody
# opened. The APK is a direct build artifact now.

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
    # Large pushes over HTTP/2 have failed here with `curl 55 Send failure`, and
    # the script then cheerfully reported success because nothing looked at the
    # exit code. Both halves of that are fixed: a bigger buffer and HTTP/1.1 for
    # the transfer, and a hard stop if it still fails.
    & git -c http.postBuffer=524288000 -c http.version=HTTP/1.1 `
          push --force origin $Branch
    $pushed = $LASTEXITCODE
    Pop-Location
    if ($pushed -ne 0) {
        Write-Host "Push failed ($pushed) — nothing was published." -ForegroundColor Red
        exit $pushed
    }

    Write-Host "Published $Branch from $sha" -ForegroundColor Green
} finally {
    Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue
}
