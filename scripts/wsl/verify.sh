#!/usr/bin/env bash
set -uo pipefail

final=false
if [[ $# -eq 1 && "$1" == "--final" ]]; then
  final=true
elif [[ $# -ne 0 ]]; then
  echo "usage: $0 [--final]" >&2
  exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.sh
source "$script_dir/config.sh"

failures=0

pass() { printf '[PASS] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1"; failures=$((failures + 1)); }

check_command() {
  local command_name="$1"
  if command -v "$command_name" >/dev/null 2>&1; then
    pass "$command_name が見つかりました。"
  else
    fail "$command_name が見つかりません。"
    return 1
  fi
}

# shellcheck source=/etc/os-release
source /etc/os-release
if [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "$EXPECTED_UBUNTU_VERSION" ]]; then
  pass "Ubuntu $EXPECTED_UBUNTU_VERSION です。"
else
  fail "Ubuntu $EXPECTED_UBUNTU_VERSION ではありません (${ID:-unknown} ${VERSION_ID:-unknown})。"
fi

for package in "${APT_PACKAGES[@]}"; do
  if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -Fq 'install ok installed'; then
    pass "apt package $package"
  else
    fail "apt package $package がありません。"
  fi
done

managed_env="$HOME/$MANAGED_ENV_RELATIVE_PATH"
if [[ -r "$managed_env" ]]; then
  # shellcheck source=env.sh
  source "$managed_env"
  pass '管理対象のシェルフラグメントを読めます。'
else
  fail '管理対象のシェルフラグメントがありません。'
fi

managed_git_helpers="$HOME/$MANAGED_GIT_HELPERS_RELATIVE_PATH"
if [[ -r "$managed_git_helpers" ]]; then
  pass '管理対象の Git helper フラグメントを読めます。'
else
  fail '管理対象の Git helper フラグメントがありません。'
fi

if [[ -x "$HOME/$MANAGED_BROWSER_RELATIVE_PATH" ]]; then
  pass '管理対象の Windows ブラウザー helper を実行できます。'
else
  fail '管理対象の Windows ブラウザー helper がありません。'
fi

for helper_name in gr grb grw; do
  if declare -F "$helper_name" >/dev/null 2>&1; then
    pass "$helper_name function を利用できます。"
  else
    fail "$helper_name function を利用できません。"
  fi
done

source_count="$(grep -Fxc "$MANAGED_SOURCE_LINE" "$HOME/.bashrc" 2>/dev/null || true)"
if [[ "$source_count" == "1" ]]; then
  pass '.bashrc の source 行は1件です。'
else
  fail ".bashrc の source 行が1件ではありません (現在: $source_count)。"
fi

for command_name in git gh fnm node npm uv playwright-cli docker; do
  check_command "$command_name"
done

if command -v node >/dev/null 2>&1 && [[ "$(node -p 'process.release.lts || ""' 2>/dev/null)" != "" ]]; then
  pass 'Node.js は LTS リリースです。'
else
  fail 'Node.js が LTS リリースではありません。'
fi

if command -v npm >/dev/null 2>&1 && npm list --global --depth=0 @playwright/cli >/dev/null 2>&1; then
  pass '@playwright/cli はグローバル導入されています。'
else
  fail '@playwright/cli のグローバル導入を確認できません。'
fi

engine_packages=()
for package in docker-ce docker.io containerd.io; do
  if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -Fq 'install ok installed'; then
    engine_packages+=("$package")
  fi
done
if [[ ${#engine_packages[@]} -eq 0 ]]; then
  pass 'Ubuntu 内に別の Docker Engine package はありません。'
else
  fail "Ubuntu 内に Docker Engine package があります: ${engine_packages[*]}"
fi

if docker compose version >/dev/null 2>&1; then
  pass 'Docker Compose CLI を利用できます。'
else
  fail 'Docker Compose CLI を利用できません。'
fi

for key in user.name user.email; do
  if value="$(git config --global --get "$key" 2>/dev/null)" && [[ "$value" =~ [^[:space:]] ]]; then
    pass "Git global $key は設定済みです。"
  else
    fail "Git global $key が未設定です。git config --global $key で設定してください。"
  fi
done
if [[ "$(git config --global --get init.defaultBranch 2>/dev/null)" == "main" ]]; then
  pass 'Git global init.defaultBranch は main です。'
else
  fail 'git config --global init.defaultBranch main を実行してください。'
fi

if gh auth status >/dev/null 2>&1; then pass 'GitHub CLI は認証済みです。'; else fail 'GitHub CLI は未認証です。'; fi
printf '[手動確認] gh auth setup-git を実施済みであることを確認してください。\n'
if [[ "$final" == true ]]; then
  if check_command codex; then
    if codex login status >/dev/null 2>&1; then pass 'Codex は認証済みです。'; else fail 'Codex は未認証です。'; fi
  fi
  if check_command claude; then
    if claude auth status >/dev/null 2>&1; then pass 'Claude Code は認証済みです。'; else fail 'Claude Code は未認証です。'; fi
  fi
fi

if [[ $failures -gt 0 ]]; then
  printf '%d 件の必須チェックが失敗しました。\n' "$failures" >&2
  exit 1
fi

echo 'WSL の read-only 検証は PASS です。'
