#!/usr/bin/env bash
set -euo pipefail

session="windows-setup-smoke-$$"
close_browser() {
  playwright-cli "-s=$session" close >/dev/null 2>&1 || true
}
trap close_browser EXIT

docker info >/dev/null
docker compose version >/dev/null
playwright-cli "-s=$session" open about:blank --browser chromium >/dev/null
playwright-cli "-s=$session" close >/dev/null
trap - EXIT

echo 'Docker daemon と Playwright CLI の実動作確認は PASS です。'
