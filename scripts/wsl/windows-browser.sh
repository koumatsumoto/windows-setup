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

# Encode the whole command after quoting URL data as a PowerShell literal.
# Never interpolate a URL into cmd.exe or an unquoted PowerShell expression.
quoted_url="${url//\'/\'\'}"
encoded_command="$(printf "\$ProgressPreference = 'SilentlyContinue'; Start-Process -FilePath '%s'" "$quoted_url" |
  iconv -f UTF-8 -t UTF-16LE | base64 -w 0)"
# Windows console applications must not consume a caller's script input.
powershell.exe -NoLogo -NoProfile -NonInteractive -EncodedCommand "$encoded_command" </dev/null >/dev/null
