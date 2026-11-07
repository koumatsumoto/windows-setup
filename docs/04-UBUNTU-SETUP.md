---
title: 04. WSL 開発環境
permalink: /docs/04-UBUNTU-SETUP/
nav_order: 40
nav_label: 04. WSL 開発環境
nav_section: setup
---

# 04. WSL 開発環境

`Ubuntu-26.04` に Git / GitHub、Node.js / TypeScript、Python / uv、Playwright の最小基盤を導入します。

## 完了条件

- Git / GitHub CLI と必要最小限の OS パッケージが使える。
- fnm が Node.js LTS を管理し、`node` / `npm` が使える。
- Python はプロジェクトごとに uv で管理できる。
- AI エージェント用 `playwright-cli` と専用 Chromium が使える。
- Playwright Test とそのブラウザーをグローバルには導入していない。

## 1. WSL 基盤を導入する

最初の1回だけ、Windows 側で展開した ZIP のスクリプトを使います。内容を確認し、dry-run、実行の順に進めます。

```bash
cd /mnt/c/Users/kou/Downloads/windows-setup/windows-setup-main
./scripts/wsl/install.sh --dry-run
./scripts/wsl/install.sh
exec bash
```

スクリプトは Ubuntu 26.04 以外では停止します。既存の `.bashrc` 全体は置換せず、管理対象フラグメントを1行だけ source します。変更前の `.bashrc` は初回だけ日時付きでバックアップします。Docker Desktop 連携のために `/etc/wsl.conf` や systemd は変更しません。

## 2. リポジトリを WSL へ clone する

Git の導入後は Windows の ZIP 展開先ではなく、Linux ファイルシステム内のホーム直下で作業します。このガイドは `~/windows-setup` を標準の配置先にします。

```bash
cd ~
git clone https://github.com/koumatsumoto/windows-setup.git
cd ~/windows-setup
```

以後のコマンドはこの WSL 側コピーで実行します。他のリポジトリもホーム直下へ clone します。WSL を初期化し直した場合も同じ配置で取得し直すため、端末ごとにパスを変える必要はありません。すでに同名ディレクトリがある場合は内容を確認し、既存の作業を削除・上書きしません。

## 3. Git と GitHub を設定する

[Git の最小設定]({{ '/docs/05-DEV-TOOL-CONFIG/' | relative_url }}) で名前とメールアドレスを設定します。続いて認証します。

基盤スクリプトは `~/.local/bin/windows-browser` を配置します。WSL から `powershell.exe` が使え、既存の [`GH_BROWSER` / `BROWSER` 設定](https://cli.github.com/manual/gh_help_environment)がない場合は、新しいシェルで `GH_BROWSER=windows-browser` を設定します。GitHub CLI の HTTP / HTTPS 認証 URL を Windows の既定ブラウザーで開くための設定です。

```bash
gh auth login
gh auth setup-git
```

トークン、SSH 鍵、認証済み設定はこのリポジトリへ保存しません。

### ブラウザーが見つからない場合

`xdg-open,x-www-browser,www-browser,wslview` が見つからないエラーが出た場合は、管理対象の設定を同期し、新しいシェルで確認します。既存の WSL もこの手順で更新できます。

```bash
cd ~/windows-setup
git pull --ff-only
./scripts/wsl/sync-config.sh
exec bash
command -v powershell.exe
windows-browser https://github.com
gh auth login
gh auth setup-git
```

`windows-browser` は HTTP / HTTPS の URL だけを受け取り、Windows PowerShell の `Start-Process` で既定ブラウザーを開きます。URL はコードへ埋め込まず、base64 のデータとして標準入力へ渡します。[Windows interop](https://learn.microsoft.com/en-us/windows/wsl/filesystems) や `powershell.exe` の PATH が使えない場合は、その設定を確認してください。すぐに認証する場合は、GitHub CLI が表示した URL を Windows のブラウザーで手動で開き、同じ画面に表示されたコードを入力できます。自分で `GH_BROWSER` または `BROWSER` を指定済みの場合は上書きしません。

## 4. Node.js / TypeScript

Node.js のバージョン管理には [fnm](https://github.com/Schniz/fnm) を使います。基盤スクリプトは fnm の公式インストーラーを `--skip-shell` で実行し、シェル初期化はこのリポジトリの `env.sh` に集約します。続いて次の処理で、その時点の Node.js LTS を導入して既定にします。

```bash
fnm install --lts --use
fnm default "$(fnm current)"
```

導入後は新しいシェルで確認します。

```bash
fnm --version
fnm current
node --version
node -p 'process.release.lts'
npm --version
```

`node -p 'process.release.lts'` が `null` ではなく LTS のコードネームを返すことを確認します。

新しいプロジェクトでは `.node-version` に Node.js のバージョンを記録し、依存は lockfile で固定します。既存プロジェクトに `.nvmrc` がある場合も fnm が読み取れるため、そのファイルを使えます。`.nvmrc` は互換のバージョン指定ファイル名であり、nvm の導入を求める記述ではありません。`env.sh` の `fnm env --use-on-cd --shell bash` が、ディレクトリ移動時にプロジェクトの指定を読み取ります。

TypeScript などは各プロジェクトの `devDependencies` に追加し、グローバル導入しません。

## 5. Python / uv

システム Python やグローバル pip を開発用パッケージで変更しません。新しいプロジェクトでは次のように uv の設定と lockfile を使います。

```bash
uv init example-python
cd example-python
uv python pin 3.14
uv add --dev pytest
uv run pytest
```

開発用の Python バージョンは各プロジェクトで決め、uv で管理します。OS の `python3` と `build-essential` は [node-gyp による Node.js native addon のビルド](https://github.com/nodejs/node-gyp#on-unix)に備える汎用ビルド基盤として導入します。プロジェクト用 Python の系列を固定するものではありません。`unzip` は fnm の展開に必要です。

## 6. Playwright の用途を分ける

### プロジェクトの E2E テスト

Playwright Test は対象 Node.js プロジェクトでだけ追加します。

```bash
npm init playwright@latest
npx playwright install --with-deps
npx playwright test
```

`package.json` と lockfile を commit し、必要なブラウザーをそのプロジェクトで取得します。

### AI エージェントのブラウザー操作

基盤スクリプトは `@playwright/cli@latest` と CLI 用 Chromium をグローバル導入します。生成 skill は固定保存せず、Codex / Claude Code から `playwright-cli --help` を読ませます。

```bash
playwright-cli --version
playwright-cli --help
playwright-cli -s=smoke open about:blank
playwright-cli -s=smoke close
```

特定プロジェクトで生成 skill が必要になった場合だけ、その時点の CLI で `playwright-cli install --skills` を実行します。

## 7. read-only 検証

WSL 基盤、Git の global `user.name` / `user.email`（非空）、`init.defaultBranch=main`、GitHub CLI の認証を確認します。`gh auth setup-git` による Git の credential helper 設定は自動判定せず、実施済みかを手動で確認します。Codex / Claude Code の導入・認証は次の Step 5 で確認します。

```bash
./scripts/wsl/verify.sh
```

Docker daemon とブラウザーの起動を含む動作確認は、明示的に次を実行します。一時セッションは終了時に閉じます。

```bash
./scripts/wsl/verify-runtime.sh
```

## 次に読む

[05. AI コーディングツールと完了確認]({{ '/docs/08-AI-CODING-TOOLS/' | relative_url }}) に進みます。
