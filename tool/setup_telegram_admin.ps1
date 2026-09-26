# Wires the owner's Telegram order notifications (Payments v2).
#
# Before running: in Telegram, open @BotFather → /revoke → pick
# @mafia_master_orders_bot → copy the NEW token. Then open the bot and press
# Start (or send any message) so it is allowed to message you.
#
# The token is read without echo, never printed, and only handed to
# `supabase secrets set`. Requires the Supabase CLI login used for deploys.
$ErrorActionPreference = 'Stop'
$projectRef = 'hezjbrnveajypfqmjfnh'

$secure = Read-Host 'Paste the NEW bot token' -AsSecureString
$token = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
  [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
if ($token -notmatch '^\d+:[A-Za-z0-9_-]{30,}$') { throw 'That does not look like a bot token.' }

$me = Invoke-RestMethod "https://api.telegram.org/bot$token/getMe"
Write-Host "Token OK for @$($me.result.username)"
# A webhook blocks getUpdates; this bot has none, but clear it to be sure.
Invoke-RestMethod "https://api.telegram.org/bot$token/deleteWebhook" | Out-Null

$chat = $null
for ($try = 1; $try -le 12 -and -not $chat; $try++) {
  $updates = Invoke-RestMethod "https://api.telegram.org/bot$token/getUpdates"
  $chat = @($updates.result) | ForEach-Object {
    if ($_.message) { $_.message.chat } elseif ($_.my_chat_member) { $_.my_chat_member.chat }
  } | Where-Object { $_.type -eq 'private' } | Select-Object -Last 1
  if (-not $chat) {
    Write-Host "Waiting for your message to @$($me.result.username)... ($try/12) - send it 'hi' now"
    Start-Sleep -Seconds 5
  }
}
if (-not $chat) { throw 'Still no message. Send the bot any text, then run this again.' }
Write-Host "Chat found: $($chat.first_name) (id $($chat.id))"

npx -y supabase secrets set --project-ref $projectRef `
  "TELEGRAM_BOT_TOKEN=$token" "TELEGRAM_ADMIN_CHAT_ID=$($chat.id)" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'supabase secrets set failed (is the CLI logged in?).' }

$body = @{ chat_id = $chat.id; text = 'Mafia Master: order notifications are connected.' }
Invoke-RestMethod -Method Post "https://api.telegram.org/bot$token/sendMessage" -Body $body | Out-Null
Write-Host 'Done: secrets set and a test message was sent to your Telegram.'
