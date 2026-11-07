#!/usr/bin/env bash
set -euo pipefail

# Run only in a disposable container: this test exercises the real home targets.
if [[ "${WINDOWS_SETUP_DISPOSABLE_TEST:-}" != 1 ]]; then
  echo 'Run in a disposable container with WINDOWS_SETUP_DISPOSABLE_TEST=1.' >&2
  exit 2
fi
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
touch "$HOME/.bashrc"
cp "$HOME/.bashrc" "$test_dir/bashrc"
cd "$test_dir"
for _iteration in 1 2; do
  bash "$repo/scripts/wsl/sync-config.sh"
  cmp "$repo/scripts/wsl/env.sh" "$HOME/.config/windows-setup/env.sh"
  cmp "$repo/scripts/shell/git-helpers.sh" "$HOME/.config/windows-setup/git-helpers.sh"
  cmp "$repo/scripts/wsl/windows-browser.sh" "$HOME/.local/bin/windows-browser"
  [[ -x "$HOME/.local/bin/windows-browser" ]]
  cmp "$test_dir/bashrc" "$HOME/.bashrc"
done
if bash "$repo/scripts/wsl/sync-config.sh" --unknown; then
  echo 'unexpected argument accepted' >&2
  exit 1
fi
echo 'Config sync tests PASS'
