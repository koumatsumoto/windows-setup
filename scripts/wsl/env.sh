# shellcheck shell=bash
# Managed by windows-setup. Keep personal shell settings outside this file.
export PATH="$HOME/.local/bin:$HOME/.local/share/fnm:$PATH"

# Let gh login use the Windows default browser. Respect both gh/user overrides.
if [[ -n "${WSL_DISTRO_NAME:-}" && -z "${GH_BROWSER:-}" && -z "${BROWSER:-}" && -x "$HOME/.local/bin/windows-browser" ]] &&
  command -v powershell.exe >/dev/null 2>&1; then
  export GH_BROWSER=windows-browser
fi

if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell bash)"
fi

if [[ -r "${BASH_SOURCE[0]%/*}/git-helpers.sh" ]]; then
  # shellcheck source=../shell/git-helpers.sh
  source "${BASH_SOURCE[0]%/*}/git-helpers.sh"
fi
