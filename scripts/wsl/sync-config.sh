#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "usage: $0" >&2
  exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.sh
source "$script_dir/config.sh"

mkdir -p "$(dirname -- "$HOME/$MANAGED_ENV_RELATIVE_PATH")"
mkdir -p "$(dirname -- "$HOME/$MANAGED_BROWSER_RELATIVE_PATH")"
install -m 0644 "$script_dir/env.sh" "$HOME/$MANAGED_ENV_RELATIVE_PATH"
install -m 0644 "$script_dir/../shell/git-helpers.sh" "$HOME/$MANAGED_GIT_HELPERS_RELATIVE_PATH"
install -m 0755 "$script_dir/windows-browser.sh" "$HOME/$MANAGED_BROWSER_RELATIVE_PATH"
echo '管理対象の env.sh、git-helpers.sh、windows-browser を同期しました。新しいシェルを開いてください。'
