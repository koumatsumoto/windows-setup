---
title: Windows Setup
nav_hidden: true
---

# Windows Setup

対象端末に Microsoft が通常提供する、サポート中の日本語 Windows 11（GA / 安定版）を基準に、必要最小限の開発環境を復旧する手順です。判断を減らすため、必須手順は次の5段階だけにしています。

## 必須セットアップ

| 段階 | 手順 | 完了する状態 |
| --- | --- | --- |
| 1 | [Windows 11 と `C:\Users\kou`]({{ '/docs/01-WINDOWS-CLEAN-INSTALL/' | relative_url }}) | 日本語版 Windows 11 と固定したプロファイルパス |
| 2 | [日本語入力と Windows 設定]({{ '/docs/02-WINDOWS-SETUP/' | relative_url }}) | IME、Explorer、OneDrive を意図した状態にする |
| 3 | [Windows アプリ・WSL・Docker]({{ '/docs/03-WINDOWS-DEVELOPMENT-SETUP/' | relative_url }}) | 必須アプリ、WSL 2、Ubuntu 26.04 LTS、Docker / VS Code 連携 |
| 4 | [WSL 開発環境]({{ '/docs/04-UBUNTU-SETUP/' | relative_url }}) | Git / gh、Node.js LTS、uv、2種類の Playwright 用途 |
| 5 | [AI コーディングツールと完了確認]({{ '/docs/08-AI-CODING-TOOLS/' | relative_url }}) | Codex / Claude Code の導入・認証と全体検証 |

## 復旧完了条件

- Windows はサポート中の GA / 安定版で、その端末向けの通常更新を適用し、Insider Program に参加していない。
- Windows プロファイルは `C:\Users\kou`、既知のフォルダーの実パスは `Documents`、`Desktop`、`Downloads`、`Pictures` の英語名である。
- 日本語表示・地域・システムロケール・日本語キーボードと、個人用 IME キー設定が復旧している。
- OneDrive はアプリを残し、未サインイン、フォルダーバックアップ無効、自動起動無効である。
- Windows 側は VS Code、Docker Desktop、Chrome、PowerToys のみをこのガイドで導入する。
- VS Code の WSL 拡張 `ms-vscode-remote.remote-wsl` を導入し、Ubuntu から WSL window を開ける。
- WSL 2 の `Ubuntu-26.04` で Git / GitHub、Node.js / TypeScript、Python / uv、Docker、Playwright、Codex、Claude Code が使える。
- Playwright Test はプロジェクトの依存と lockfile で管理し、AI エージェント用 `playwright-cli` だけをグローバル導入する。

## 設定リファレンス

必須経路に含めない補足です。必要になった場合だけ参照します。

- [Git の最小設定]({{ '/docs/05-DEV-TOOL-CONFIG/' | relative_url }})
- [管理対象のシェル初期化]({{ '/docs/06-SHELL-CONFIG/' | relative_url }})
- [Windows Terminal の最小設定]({{ '/docs/07-WINDOWS-TERMINAL/' | relative_url }})
- [既存環境の整理と Ubuntu の入れ替え]({{ '/docs/09-CLEANUP-AND-WSL-REINSTALL/' | relative_url }})
