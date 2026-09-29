# Sets the FCM service-account secret on the hosted Supabase project.
#
# The owner runs this once, after downloading the key from
# Firebase console → Project settings → Service accounts → Generate new private key
# into D:\keys\ (any *.json whose name starts with "mafia-master-e0cf5").
#
#   powershell -ExecutionPolicy Bypass -File tool\push\set_fcm_secret.ps1
#
# The key never enters the repository and is never printed.
$ErrorActionPreference = 'Stop'
$key = Get-ChildItem 'D:\keys' -Filter 'mafia-master-e0cf5*.json' |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $key) { throw 'No D:\keys\mafia-master-e0cf5*.json found. Download the private key first.' }
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($key.FullName))
npx -y supabase secrets set --project-ref hezjbrnveajypfqmjfnh "FCM_SERVICE_ACCOUNT_B64=$b64" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'supabase secrets set failed' }
Write-Host "FCM secret set from $($key.Name)." -ForegroundColor Green
