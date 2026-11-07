#!/usr/bin/env bash
# Shared values are consumed by the scripts that source this file.
# shellcheck disable=SC2034

EXPECTED_UBUNTU_VERSION="26.04"

APT_PACKAGES=(
  # build-essential and python3 support Node.js native addon builds (node-gyp).
  build-essential
  ca-certificates
  curl
  git
  python3
  unzip
)

FNM_INSTALL_URL="https://fnm.vercel.app/install"
UV_INSTALL_URL="https://astral.sh/uv/install.sh"
CODEX_INSTALL_URL="https://chatgpt.com/codex/install.sh"
CLAUDE_INSTALL_URL="https://claude.ai/install.sh"

MANAGED_ENV_RELATIVE_PATH=".config/windows-setup/env.sh"
MANAGED_GIT_HELPERS_RELATIVE_PATH=".config/windows-setup/git-helpers.sh"
MANAGED_BROWSER_RELATIVE_PATH=".local/bin/windows-browser"
# Expand HOME when the managed line is sourced, not when it is written.
# shellcheck disable=SC2016
MANAGED_SOURCE_LINE='[ -f "$HOME/.config/windows-setup/env.sh" ] && . "$HOME/.config/windows-setup/env.sh"'
