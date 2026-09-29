# Publishes build/web to Cloudflare Pages (project "saidalamafia") on the
# owner's Cloudflare account, and serves it on saidalamafia.com.
#
# First time only, the owner runs:   npx wrangler login
# (a browser page opens; click "Allow"). After that:
#
#   powershell -ExecutionPolicy Bypass -File tool\web\deploy_cloudflare.ps1
#
# Build first (see memory/hosted-verification-routes): flutter build web
# --release with dart_defines.json, then stamp build/web/sw.js.
$ErrorActionPreference = 'Stop'
$project = 'saidalamafia'
if (-not (Test-Path 'build/web/index.html')) { throw 'No build/web. Build the web release first.' }
# Create the Pages project once; an existing project is not an error.
npx -y wrangler@latest pages project create $project --production-branch main 2>$null | Out-Null
npx -y wrangler@latest pages deploy build/web --project-name $project --branch main --commit-dirty=true
if ($LASTEXITCODE -ne 0) { throw 'wrangler pages deploy failed' }
Write-Host "Deployed to https://$project.pages.dev (and saidalamafia.com once attached)." -ForegroundColor Green
