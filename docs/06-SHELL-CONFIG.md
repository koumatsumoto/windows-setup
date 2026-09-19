---
title: 管理対象のシェル初期化
permalink: /docs/06-SHELL-CONFIG/
nav_order: 120
nav_label: 管理対象のシェル初期化
nav_section: reference
---

# 管理対象のシェル初期化

`scripts/wsl/install.sh` は既存の `~/.bashrc` を維持し、次の1行だけを追加します。

```bash
[ -f "$HOME/.config/windows-setup/env.sh" ] && . "$HOME/.config/windows-setup/env.sh"
```

管理対象フラグメントは次だけを担当します。

- `~/.local/bin`、fnm、Codex の実行パス
- `fnm env --use-on-cd --shell bash` による Node.js の切り替え
- `gr` / `grb` / `grw` Git helper の読み込み

`gr` はprimary worktreeへ移動して `origin` のremote HEADが示す既定branchへ切り替えた後、`grw`、`grb` の順に実行します。既定branchがlinked worktreeでcheckout済みの場合は、そのworktreeを同じcommitのdetached HEADにしてからprimary worktreeへbranchを移します。これにより、呼び出し元のlinked worktreeを含むlinked worktreeの削除、既定branchの更新、マージ済みlocal branchの削除を1コマンドで行います。未コミット変更などにより既定branchを安全に移せない場合は、cleanupを開始せず停止します。個別の操作には引き続き `grw` と `grb` を利用できます。

`grb` は `origin` のremote HEADが示す現在の既定branchを安全にfast-forwardした後、その既定branchにマージ済みで、どのworktreeでも使用されていないローカルbranchだけを削除します。呼び出し元のbranchは切り替えません。localの既定branchがaheadまたはdivergedの場合は、branchを削除せず停止します。

`grw` はprimary worktreeが `origin` のremote HEADが示す現在の既定branchの場合に、すべてのlinked worktreeを削除します。dirty worktreeも削除しますが、locked worktreeは残し、branch自体は削除しません。既定branchを取得できない場合やprimary worktreeが既定branchでない場合は、何も削除せず停止します。

そのほかのエイリアス、プロンプト、apt 更新、Windows アプリ起動などの個人用関数は復旧条件に含めません。

## Git Bashで使う

Git for Windows / Git Bashを既に導入している場合は、このリポジトリ内の同じfragmentを `~/.bashrc` からsourceします。Git for Windowsの導入自体は、このセットアップの必須項目ではありません。

```bash
[ -f "/c/Users/kou/path/to/windows-setup/scripts/shell/git-helpers.sh" ] && \
  . "/c/Users/kou/path/to/windows-setup/scripts/shell/git-helpers.sh"
```

`/c/Users/kou/path/to/windows-setup` は実際のclone先へ置き換えます。空白を含むpathでも、上記のように引用符で囲めば利用できます。

## 管理対象フラグメントを更新する

WSL 基盤の導入済み環境では、リポジトリを更新した後に次を実行します。

```bash
cd ~/work/windows-setup
git pull --ff-only
./scripts/wsl/sync-config.sh
exec bash
```

`env.sh` と `git-helpers.sh` のコピーだけを更新します。apt やランタイムの導入、`.bashrc` の変更は行いません。初回導入には Step 4 の `install.sh` を使います。

## 基盤の確認

```bash
grep -F '.config/windows-setup/env.sh' ~/.bashrc
sed -n '1,80p' ~/.config/windows-setup/env.sh
type fnm node uv playwright-cli gr grb grw
```

source 行が1件だけであることを確認します。再実行時にも重複しません。

AI CLI の導入・認証を終えた Step 5 では、リポジトリのルートから最終確認を実行します。

```bash
./scripts/wsl/verify.sh --final
```

[04. WSL 開発環境]({{ '/docs/04-UBUNTU-SETUP/' | relative_url }}) に戻ります。
