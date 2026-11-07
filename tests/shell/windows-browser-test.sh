#!/usr/bin/env bash
# Environment changes in the source checks are intentionally subshell-local.
# shellcheck disable=SC2030,SC2031
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
export HOME="$test_dir/home with spaces"
export ARG_CAPTURE="$test_dir/arguments"
export STDIN_CAPTURE="$test_dir/stdin"
mkdir -p "$HOME/.local/bin" "$test_dir/bin" "$test_dir/empty"
install -m 0755 "$repo/scripts/wsl/windows-browser.sh" "$HOME/.local/bin/windows-browser"
browser="$HOME/.local/bin/windows-browser"

cat > "$test_dir/bin/powershell.exe" <<'STUB'
#!/usr/bin/env bash
printf '%s\0' "$@" > "$ARG_CAPTURE"
cat > "$STDIN_CAPTURE"
exit "${TEST_PS_EXIT:-0}"
STUB
chmod +x "$test_dir/bin/powershell.exe"
export PATH="$test_dir/bin:$PATH"

url="https://example.com/?q=O'Reilly&x="
# shellcheck disable=SC2016
url+='$HOME;$(touch injected)`echo risky`#日本語'
"$browser" "$url"
mapfile -d '' -t arguments < "$ARG_CAPTURE"
[[ "${#arguments[@]}" == 5 ]]
[[ "${arguments[0]}" == -NoLogo && "${arguments[1]}" == -NoProfile ]]
[[ "${arguments[2]}" == -NonInteractive && "${arguments[3]}" == -EncodedCommand ]]
decoded="$(printf '%s' "${arguments[4]}" | base64 -d | iconv -f UTF-16LE -t UTF-8)"
# shellcheck disable=SC2016
expected='$ProgressPreference = "SilentlyContinue"; $url = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([Console]::In.ReadToEnd())); Start-Process -FilePath $url'
[[ "$decoded" == "$expected" ]]
[[ "$(base64 -d < "$STDIN_CAPTURE")" == "$url" ]]
for url in 'https://example.com/‘;Write-Output INJECTED;#' 'https://example.com/’;Write-Output INJECTED;#' 'https://example.com/“”;Write-Output INJECTED;#'; do
  "$browser" "$url"
  mapfile -d '' -t arguments < "$ARG_CAPTURE"
  [[ "$(printf '%s' "${arguments[4]}" | base64 -d | iconv -f UTF-16LE -t UTF-8)" == "$expected" ]]
  [[ "$(base64 -d < "$STDIN_CAPTURE")" == "$url" ]]
done
printf 'caller input\n' | "$browser" https://example.com
[[ "$(base64 -d < "$STDIN_CAPTURE")" == https://example.com ]]

for url in 'file:///tmp/test' 'javascript:alert(1)' 'https://' $'https://example.com/\nnext' $'https://example.com/\rnext' $'https://example.com/\tnext'; do
  rm -f "$ARG_CAPTURE"
  if "$browser" "$url" >/dev/null 2>&1; then
    echo 'unsafe URL accepted' >&2
    exit 1
  fi
  [[ ! -e "$ARG_CAPTURE" ]]
done
if "$browser" >/dev/null 2>&1 || "$browser" https://example.com extra >/dev/null 2>&1; then
  echo 'invalid argument count accepted' >&2
  exit 1
fi
if PATH="$test_dir/empty" /bin/bash "$browser" https://example.com >/dev/null 2>&1; then
  echo 'missing PowerShell accepted' >&2
  exit 1
fi
status=0
TEST_PS_EXIT=17 "$browser" https://example.com || status=$?
[[ "$status" == 17 ]]

# Never invoke a real runtime while sourcing the managed environment.
fnm() { :; }
(
  unset BROWSER GH_BROWSER
  export WSL_DISTRO_NAME=Ubuntu-26.04
  # shellcheck source=../../scripts/wsl/env.sh
  source "$repo/scripts/wsl/env.sh"
  [[ "$GH_BROWSER" == windows-browser && -z "${BROWSER:-}" ]]
)
(
  unset GH_BROWSER
  export BROWSER=custom-browser WSL_DISTRO_NAME=Ubuntu-26.04
  # shellcheck source=../../scripts/wsl/env.sh
  source "$repo/scripts/wsl/env.sh"
  [[ "$BROWSER" == custom-browser && -z "${GH_BROWSER:-}" ]]
)
(
  unset BROWSER
  export GH_BROWSER=custom-gh-browser WSL_DISTRO_NAME=Ubuntu-26.04
  # shellcheck source=../../scripts/wsl/env.sh
  source "$repo/scripts/wsl/env.sh"
  [[ "$GH_BROWSER" == custom-gh-browser && -z "${BROWSER:-}" ]]
)
(
  unset BROWSER GH_BROWSER WSL_DISTRO_NAME
  # shellcheck source=../../scripts/wsl/env.sh
  source "$repo/scripts/wsl/env.sh"
  [[ -z "${BROWSER:-}${GH_BROWSER:-}" ]]
)
(
  unset BROWSER GH_BROWSER
  export WSL_DISTRO_NAME=Ubuntu-26.04 PATH="$test_dir/empty"
  # shellcheck source=../../scripts/wsl/env.sh
  source "$repo/scripts/wsl/env.sh"
  [[ -z "${BROWSER:-}${GH_BROWSER:-}" ]]
)
echo 'Windows browser helper tests PASS'
