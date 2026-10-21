#!/usr/bin/env bash
# Runs test/voice/voice_web_runtime_test.dart in a real headless Chrome with a
# fake microphone, and repairs the Windows Flutter test host when it stalls.
# Usage: bash tool/run_web_voice_test.sh   (Windows, Git Bash; local only)
set -u
cd "$(dirname "$0")/.." || exit 1
sdk="$(dirname "$(dirname "$(command -v flutter)")")"
wrapper="$(mktemp -d)/chrome_fake_media.cmd"
printf '@echo off\r\n"C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe" --use-fake-device-for-media-stream --use-fake-ui-for-media-stream %%*\r\n' > "$wrapper"
log="$(mktemp)"
CHROME_EXECUTABLE="$wrapper" flutter test --no-pub --platform chrome test/voice/voice_web_runtime_test.dart > "$log" 2>&1 &
runner=$!
repaired=0
while kill -0 "$runner" 2>/dev/null; do
  sleep 5
  if [ "$repaired" = 0 ]; then
    port=$(powershell -NoProfile -c "(Get-CimInstance Win32_Process -Filter \"name='chrome.exe'\" | Where-Object { \$_.CommandLine -match 'flutter_tools_chrome_device' -and \$_.CommandLine -match 'remote-debugging-port=(\d+)' } | Select-Object -First 1 | ForEach-Object { [regex]::Match(\$_.CommandLine,'remote-debugging-port=(\d+)').Groups[1].Value })" | tr -d '\r')
    if [ -n "$port" ] && ! grep -q "+1\|-1" "$log"; then
      sleep 10
      node tool/repair_flutter_web_test_host.mjs "$port" "$sdk" && repaired=1
    fi
  fi
done
wait "$runner"; code=$?
tr '\r' '\n' < "$log" | grep -E "\+[0-9]+|\[E\]|Expected|Actual|reason|All tests|Some tests" | tail -15
exit $code
