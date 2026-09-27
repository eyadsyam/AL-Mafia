# Wires Google Play purchase verification and the refund sync (1.0.1).
#
# Before running (owner only, needs the Google account that owns Play Console):
#   1. Google Cloud Console → create/choose a project → enable
#      "Google Play Android Developer API".
#   2. IAM → Service accounts → Create (e.g. play-verify) → Keys → Add key → JSON.
#      Save the file somewhere outside the repo.
#   3. Play Console → Users and permissions → Invite new user → the service
#      account's email → app "Mafia Master" → permissions:
#      "View financial data, orders and cancellation survey responses" and
#      "Manage orders and subscriptions". Send the invite.
#
# This script: reads the key file (never prints it), sets
# GOOGLE_PLAY_SERVICE_ACCOUNT_JSON, generates PLAY_SYNC_SECRET locally, stores
# it in Supabase Vault, deploys play_voided_sync and schedules it every 6 hours.
$ErrorActionPreference = 'Stop'
$ref = 'hezjbrnveajypfqmjfnh'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$path = Read-Host 'Path to the service-account JSON key file'
$path = $path.Trim('"')
if (-not (Test-Path $path)) { throw "File not found: $path" }
$json = Get-Content -Raw -Path $path
$key = $json | ConvertFrom-Json
if ($key.type -ne 'service_account' -or -not $key.client_email -or -not $key.private_key) {
  throw 'That file is not a service-account JSON key.'
}
Write-Host "Key OK for $($key.client_email)"

$bytes = New-Object byte[] 32
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$sync = ([BitConverter]::ToString($bytes) -replace '-', '').ToLower()

$compact = ($json | ConvertFrom-Json | ConvertTo-Json -Depth 10 -Compress)
npx -y supabase secrets set --project-ref $ref "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=$compact" "PLAY_SYNC_SECRET=$sync" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'supabase secrets set failed (is the CLI logged in?).' }
Write-Host 'Secrets set.'

npx -y supabase functions deploy play_voided_sync --no-verify-jwt --project-ref $ref --use-api | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Deploying play_voided_sync failed.' }

$sql = @"
create extension if not exists pg_net;
do `$`$ begin
  if exists (select 1 from vault.secrets where name='play_sync_secret') then
    perform vault.update_secret((select id from vault.secrets where name='play_sync_secret'), '$sync');
  else
    perform vault.create_secret('$sync', 'play_sync_secret');
  end if;
end `$`$;
select cron.unschedule('play-voided-sync') where exists (select 1 from cron.job where jobname='play-voided-sync');
select cron.schedule('play-voided-sync', '23 */6 * * *', `$`$
  select net.http_post(
    url := 'https://$ref.supabase.co/functions/v1/play_voided_sync',
    headers := jsonb_build_object('x-sync-secret',
      (select decrypted_secret from vault.decrypted_secrets where name='play_sync_secret'))
  );
`$`$);
"@
$tmp = New-TemporaryFile
Set-Content -Path $tmp -Value $sql -Encoding utf8
npx -y supabase db query --linked --project-ref $ref -f $tmp | Out-Null
$rc = $LASTEXITCODE
Remove-Item $tmp
if ($rc -ne 0) { throw 'Scheduling the refund sync failed.' }
Write-Host 'Done: Play verification secrets set, refund sync deployed and scheduled every 6 hours.'
