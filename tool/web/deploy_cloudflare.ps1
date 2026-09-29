# Publishes build/web to Cloudflare (Worker "saidalmafia", static assets) on
# the owner's Cloudflare account, served on saidalmafia.com and
# www.saidalmafia.com. Config: wrangler.jsonc at the repo root.
#
# First time only, the owner runs:   npx wrangler login
#
#   powershell -ExecutionPolicy Bypass -File tool\web\deploy_cloudflare.ps1
#
# Build first (see memory/hosted-verification-routes): flutter build web
# --release with dart_defines.json, then stamp build/web/sw.js.
$ErrorActionPreference = 'Stop'
if (-not (Test-Path 'build/web/index.html')) { throw 'No build/web. Build the web release first.' }
# Keeps build/web/.vercel (the Vercel link) out of the upload.
Copy-Item 'web/.assetsignore' 'build/web/.assetsignore' -Force
npx -y wrangler@latest deploy
if ($LASTEXITCODE -ne 0) { throw 'wrangler deploy failed' }
Write-Host 'Deployed to https://saidalmafia.com' -ForegroundColor Green
