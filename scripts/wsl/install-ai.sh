#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.sh
source "$script_dir/config.sh"

dry_run=false
if [[ "${1:-}" == "--dry-run" ]]; then
  dry_run=true
elif [[ $# -gt 0 ]]; then
  echo "usage: $0 [--dry-run]" >&2
  exit 2
fi

if [[ ${EUID} -eq 0 ]]; then
  echo "root ではなく、通常の WSL ユーザーで実行してください。" >&2
  exit 1
fi

# shellcheck source=/etc/os-release
source /etc/os-release
if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "$EXPECTED_UBUNTU_VERSION" ]]; then
  echo "Ubuntu $EXPECTED_UBUNTU_VERSION が必要です。現在: ${ID:-unknown} ${VERSION_ID:-unknown}" >&2
  exit 1
fi

if [[ "$dry_run" == true ]]; then
  printf '[dry-run] Codex standalone installer: %s\n' "$CODEX_INSTALL_URL"
  printf '[dry-run] Claude Code native installer: %s\n' "$CLAUDE_INSTALL_URL"
  exit 0
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

# Both native installers use ~/.local/bin. Putting it on PATH first prevents
# their supported installers from adding another PATH block to a shell profile.
export PATH="$HOME/.local/bin:$PATH"

curl -fsSL --retry 3 --retry-all-errors "$CODEX_INSTALL_URL" -o "$tmp_dir/install-codex.sh"
CODEX_NON_INTERACTIVE=1 sh "$tmp_dir/install-codex.sh"

curl -fsSL --retry 3 --retry-all-errors "$CLAUDE_INSTALL_URL" -o "$tmp_dir/install-claude.sh"
bash "$tmp_dir/install-claude.sh"

echo 'Codex と Claude Code を導入しました。新しいシェルで各 CLI を起動し、手動で認証してください。'
