#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: windows-browser <http(s) URL>" >&2
  exit 2
fi

url="$1"
case "$url" in
  http://?*|https://?*) ;;
  *)
    echo 'windows-browser: http または https の URL を指定してください。' >&2
    exit 2
    ;;
esac
if [[ "$url" == *[[:cntrl:]]* ]]; then
  echo 'windows-browser: URL に制御文字は使えません。' >&2
  exit 2
fi

if ! command -v powershell.exe >/dev/null 2>&1; then
  echo 'windows-browser: powershell.exe がありません。Windows interop と PATH を確認してください。' >&2
  exit 1
fi

# Keep code fixed and URL data separate, including PowerShell smart quotes.
# shellcheck disable=SC2016
powershell_command='$ProgressPreference = "SilentlyContinue"; $url = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([Console]::In.ReadToEnd())); Start-Process -FilePath $url'
encoded_command="$(printf '%s' "$powershell_command" |
  iconv -f UTF-8 -t UTF-16LE | base64 -w 0)"
# Only the URL's base64 reaches PowerShell stdin, never a caller's script input.
printf '%s' "$url" | base64 -w 0 |
  powershell.exe -NoLogo -NoProfile -NonInteractive -EncodedCommand "$encoded_command" >/dev/null
