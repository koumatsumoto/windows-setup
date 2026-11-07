# Site Authoring Guide

このファイルはサイト運用者向けの正本です。利用者向けセットアップは `index.md` から始めます。

## ローカル確認

Ruby 3.3 / Bundler がある環境では次を実行します。依存は `vendor/bundle` に閉じます。

```bash
./bin/setup-site
./bin/build-site
./bin/serve-site
```

公開先は `http://127.0.0.1:4000` です。Ruby をホストへ入れない場合は `docker compose up site` を使います。Compose のポートは localhost だけへ公開し、生成先は `_site-local` に分離しています。

## Theme Contract

- 公開ページには front matter を付ける。
- `nav_section` は必須手順なら `setup`、補足なら `reference` にする。
- ナビ順の正本は `nav_order`、表示名は `nav_label` とする。
- ナビに出さないページは `nav_hidden: true` とする。
- 既存の `/docs/.../` permalink は維持し、本文リンクは `relative_url` を使う。
- 共通フレームは `_layouts/default.html`、ナビ描画は `_includes/site-nav-links.html`、見た目は `assets/css/style.scss` が担う。

## 内容確認日

`_config.yml` の `verified_on` は、Windows / WSL / ツールの導入経路など主要な前提を公式仕様と照合した日です。単なるページ編集やビルドでは更新せず、主要前提を再照合した場合だけ更新します。実機でのセットアップ実施日ではありません。

## 表示確認

サイトを起動した状態で、グローバル `playwright-cli` を使います。リポジトリには CLI が生成する skill やブラウザープロファイルを保存しません。

```bash
playwright-cli -s=docs-check open http://127.0.0.1:4000
playwright-cli -s=docs-check resize 1440 900
playwright-cli -s=docs-check screenshot --filename .playwright-cli/docs-desktop.png --full-page
playwright-cli -s=docs-check resize 390 844
playwright-cli -s=docs-check screenshot --filename .playwright-cli/docs-mobile.png --full-page
playwright-cli -s=docs-check close
```

トップ、Windows 設定、WSL 設定、AI ツール、リファレンスの代表ページで、必須手順とリファレンスの区別、コードブロック、表、前後リンクを確認します。

## 変更時の検証

サイト依存を `./bin/setup-site` で用意したうえで、リポジトリのルートから実行します。Bash 構文は各ファイルを個別に検査します。ShellCheck は CI で必須です。GitHub Actions と Bundler の依存更新は Dependabot が月次で確認します。

```bash
for file in bin/setup-site bin/build-site bin/serve-site bin/verify-site \
  scripts/shell/*.sh scripts/wsl/*.sh tests/shell/*.sh; do
  bash -n "$file" || exit 1
done

bash tests/shell/git-helpers-test.sh
bash tests/shell/wsl-setup-test.sh
bash tests/shell/windows-browser-test.sh
./bin/build-site
./bin/verify-site
./bin/verify-site --self-test

# コピー先のホームを使い捨てコンテナに隔離して同期を検証する
docker run --rm -e WINDOWS_SETUP_DISPOSABLE_TEST=1 \
  -v "$PWD:/app:ro" -w /app ubuntu:26.04 \
  bash tests/shell/sync-config-test.sh
```

CI の ShellCheck をローカルで再現する場合は、ShellCheck を別途用意して次を実行します。標準の WSL セットアップには含めません。

```bash
shellcheck --external-sources --source-path=SCRIPTDIR \
  bin/setup-site bin/build-site bin/serve-site bin/verify-site \
  scripts/shell/*.sh scripts/wsl/*.sh tests/shell/*.sh
```

PowerShell スクリプトまたは `SetupConfig.psd1` を変更した場合は、Windows PowerShell 5.1 で次も実行します。スクリプト本体は実行せず、構文とデータファイルの読み込みを確認します。

```powershell
$ErrorActionPreference = 'Stop'
foreach ($file in Get-ChildItem ./scripts/windows/*.ps1) {
    $parseErrors = $null
    $tokens = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        $parseErrors | ForEach-Object { Write-Host $_ }
        throw "PowerShell parse failed: $($file.Name)"
    }
}
$null = Import-PowerShellDataFile ./scripts/windows/SetupConfig.psd1
```

PR・main への push・手動実行では `.github/workflows/verify.yml` が Ubuntu の Bash 構文・ShellCheck・Git helper integration test・WSL Git 設定の回帰テスト・Ruby 3.3 による Jekyll build とサイト検証、Windows の Git Bash で Bash 構文・Git helper integration test・Windows PowerShell 5.1 の構文・設定ファイル読み込みを自動確認します。GitHub Actions の minor / patch 更新は Dependabot が1グループにまとめ、major 更新は個別 PR にします。

CI はホストのセットアップを実行しません。フラグメント同期のテストは使い捨てコンテナ内で実行します。winget / apt / WSL install、AI CLI install・認証、利用者環境の Docker runtime、`verify-runtime.sh`、Pages deploy は検証対象外です。Pages の公開は既存の `deploy-pages.yml` が担います。

`bin/verify-site` は生成 HTML の href / src のローカルファイルと HTML アンカーを確認します。外部 URL はアクセスしません。旧リポジトリ名、旧 AI CLI npm パッケージ、廃止ツールと Windows 開発 CLI の既知の識別子は `scripts/site/verify.rb` の限定的な禁止パターンで検出します。生成 HTML と README・index・docs・セットアップスクリプトを検査し、新しい対象外ツール一般の判断はレビューに残します。

公開時の baseurl を含めて検証する場合は `./bin/build-site --baseurl /windows-setup` に続けて `./bin/verify-site _site /windows-setup` を実行します。別の生成先も第1引数で指定できます。
