---
title: 05. AI コーディングツールと完了確認
permalink: /docs/08-AI-CODING-TOOLS/
nav_order: 50
nav_label: 05. AI ツールと完了確認
nav_section: setup
---

# 05. AI コーディングツールと完了確認

WSL に Codex CLI と Claude Code のネイティブ版だけを導入し、認証を手動で完了します。

## 完了条件

- `codex` と `claude` が公式のネイティブ配布経路で導入されている。
- Codex と Claude Code にサインインし、WSL 内のリポジトリで起動できる。
- Windows / WSL の検証スクリプトと手動チェックが完了している。

## 1. ネイティブ CLI を導入する

リポジトリの WSL 側コピーで実行します。

```bash
./scripts/wsl/install-ai.sh --dry-run
./scripts/wsl/install-ai.sh
exec bash
codex --version
claude --version
```

Codex は [OpenAI の現行手順](https://learn.chatgpt.com/docs/codex/cli) にある macOS / Linux 用 standalone installer、Claude Code は [Anthropic の現行手順](https://code.claude.com/docs/en/setup) にある macOS / Linux / WSL 用 native installer を使います。npm のグローバルパッケージとしては導入しません。

インストーラーは取得後に一度ファイルへ保存し、通信成功を確認してから実行します。固定バージョンのバイト単位再現ではなく、各ベンダーがサポートする更新経路を優先します。

## 2. 手動で認証する

プロジェクトディレクトリから順に起動し、画面の案内に従います。

```bash
cd ~/work/windows-setup
codex
claude
```

認証情報、API キー、セッションファイルはこのリポジトリへコピーしません。`verify.sh --final` は認証の成否だけを確認し、アカウント名やトークンを表示しません。

## 3. WSL の最終確認

```bash
./scripts/wsl/verify.sh --final
./scripts/wsl/verify-runtime.sh
```

`verify.sh --final` は WSL 基盤に加え、Codex / Claude Code の存在と認証を確認します。認証だけが未完了なら Codex / Claude Code を再度起動します。`verify-runtime.sh` は Docker daemon と一時 Playwright セッションを実際に起動して閉じます。

導入や更新に問題がある場合は、公式の補助診断 `claude doctor` を手動で実行します。診断結果はローカルで確認し、`verify.sh --final` の必須判定には含めません。

## 4. Windows の最終確認

Windows 側で ZIP 展開したリポジトリへ移動し、通常の PowerShell で実行します。

```powershell
& .\scripts\windows\Verify-Setup.ps1
```

最後に画面で確認します。

- 対象端末向けのサポート中の Windows 11 と通常更新が適用され、Windows Insider Program に参加していない。
- Explorer に拡張子と隠しファイルが表示される。
- VS Code に WSL 拡張があり、Ubuntu から開いた window に `WSL: Ubuntu-26.04` が表示される。
- IME は `無変換 = オフ`、`変換 = オン/オフ切り替え`、`Ctrl + Space = なし`。対象の LG gram では、スペース右の「カタカナ／ひらがな／ローマ字」で切り替わり、PowerToys がなくても使える。
- OneDrive は未サインイン、フォルダーバックアップ無効、自動起動無効。
- `$env:USERPROFILE` と Known Folder は `C:\Users\kou` 直下。
- Docker Desktop の WSL Integration は `Ubuntu-26.04` だけに必要な範囲で有効。

以上で必須セットアップは完了です。[トップへ戻る]({{ '/' | relative_url }})。
