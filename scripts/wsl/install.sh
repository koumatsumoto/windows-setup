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

if [[ ! -r /etc/os-release ]]; then
  echo "/etc/os-release を読めません。" >&2
  exit 1
fi

# shellcheck source=/etc/os-release
source /etc/os-release
if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "$EXPECTED_UBUNTU_VERSION" ]]; then
  echo "Ubuntu $EXPECTED_UBUNTU_VERSION が必要です。現在: ${ID:-unknown} ${VERSION_ID:-unknown}" >&2
  exit 1
fi

if [[ "$dry_run" == true ]]; then
  printf '[dry-run] apt packages:'
  printf ' %s' "${APT_PACKAGES[@]}"
  printf '\n[dry-run] GitHub CLI repository and package\n'
  printf '[dry-run] fnm + Node.js LTS: %s\n' "$FNM_INSTALL_URL"
  printf '[dry-run] uv: %s\n' "$UV_INSTALL_URL"
  printf '[dry-run] global @playwright/cli@latest + Chromium\n'
  printf '[dry-run] managed shell fragment: ~/%s\n' "$MANAGED_ENV_RELATIVE_PATH"
  printf '[dry-run] managed Git helpers: ~/%s\n' "$MANAGED_GIT_HELPERS_RELATIVE_PATH"
  printf '[dry-run] Windows default browser helper: ~/%s\n' "$MANAGED_BROWSER_RELATIVE_PATH"
  exit 0
fi

sudo apt-get update
sudo apt-get install -y --no-install-recommends "${APT_PACKAGES[@]}"

keyring="/etc/apt/keyrings/githubcli-archive-keyring.gpg"
repo_file="/etc/apt/sources.list.d/github-cli.list"
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

curl -fsSL --retry 3 --retry-all-errors https://cli.github.com/packages/githubcli-archive-keyring.gpg -o "$tmp_dir/githubcli.gpg"
sudo install -d -m 0755 /etc/apt/keyrings /etc/apt/sources.list.d
sudo install -m 0644 "$tmp_dir/githubcli.gpg" "$keyring"
printf 'deb [arch=%s signed-by=%s] https://cli.github.com/packages stable main\n' \
  "$(dpkg --print-architecture)" "$keyring" | sudo tee "$repo_file" >/dev/null
sudo apt-get update
sudo apt-get install -y --no-install-recommends gh

curl -fsSL --retry 3 --retry-all-errors "$FNM_INSTALL_URL" -o "$tmp_dir/install-fnm.sh"
bash "$tmp_dir/install-fnm.sh" --skip-shell

managed_env="$HOME/$MANAGED_ENV_RELATIVE_PATH"
bash "$script_dir/sync-config.sh"

touch "$HOME/.bashrc"
if ! grep -Fqx "$MANAGED_SOURCE_LINE" "$HOME/.bashrc"; then
  backup="$HOME/.bashrc.windows-setup.$(date +%Y%m%d%H%M%S).bak"
  cp -- "$HOME/.bashrc" "$backup"
  printf '\n%s\n' "$MANAGED_SOURCE_LINE" >> "$HOME/.bashrc"
  printf '既存の .bashrc を %s へ退避しました。\n' "$backup"
fi

# shellcheck source=env.sh
source "$managed_env"
fnm install --lts --use
fnm default "$(fnm current)"

if command -v uv >/dev/null 2>&1; then
  UV_NO_MODIFY_PATH=1 uv self update
else
  curl -fsSL --retry 3 --retry-all-errors "$UV_INSTALL_URL" -o "$tmp_dir/install-uv.sh"
  UV_NO_MODIFY_PATH=1 sh "$tmp_dir/install-uv.sh"
fi

export PATH="$HOME/.local/bin:$PATH"
npm install --global @playwright/cli@latest
playwright-cli install-browser chromium --with-deps

echo 'WSL の基盤導入が完了しました。新しいシェルを開いて verify.sh を実行してください。'
