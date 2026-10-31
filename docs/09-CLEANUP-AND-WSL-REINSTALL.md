---
title: 既存環境の整理と Ubuntu の入れ替え
permalink: /docs/09-CLEANUP-AND-WSL-REINSTALL/
nav_order: 140
nav_label: 整理と Ubuntu 入れ替え
nav_section: reference
---

# 既存環境の整理と Ubuntu の入れ替え

Windows を使い続けながら、不要なデータを整理したり、既存の Ubuntu を新しく作り直したりするための補足です。必要な項目だけ実施します。新規セットアップの必須手順には含めません。

## 1. 削除対象と残すものを決める

Windows の設定 → システム → ストレージと、設定 → アプリ → インストールされているアプリで、容量と利用状況を確認します。アプリ本体、設定、認証情報、キャッシュ、保存データを分け、削除対象を具体的なアプリ名・フォルダー名で決めます。

- Windows 版 VS Code、WSL 拡張、ユーザー設定は、WSL 接続を続けるために残す。
- Docker Desktop 本体と WSL 2 の基盤は、Docker を使う場合に残す。
- `.codex`、認証情報、SSH 鍵、作業リポジトリは、アプリのキャッシュと区別する。
- LG gram のキー置き換えだけに使っていた PowerToys は、[Windows 標準設定への移行と再起動後の実入力確認]({{ '/docs/02-WINDOWS-SETUP/' | relative_url }}) が済めば削除できる。他の機能を使っている場合は利用状況を確認する。
- ドライバー、共有ランタイム、Windows の更新・セキュリティ機能は、一括削除の対象にしない。

個人文書や Downloads は中身を確認します。クラウド同期フォルダーやリンク先を含むフォルダーの一括削除は避けます。

## 2. 退避済みの旧 Ubuntu を入れ替える

**登録解除すると、そのディストリビューション内の全データが失われます。** コード、未 push の変更、ローカル DB、必要な設定などが退避済みで、退避先から読めることを確認してから進めます。バックアップの作成・移行自体はこのガイドの対象外です。

通常の PowerShell で一覧を確認します。

```powershell
wsl --list --verbose
```

以下は、削除対象が一覧上で `Ubuntu` という名前の場合だけの例です。実際の名前が異なる場合は置き換えます。Docker 用のディストリビューションを削除対象にしません。

```powershell
wsl --terminate Ubuntu
wsl --unregister Ubuntu
wsl --list --verbose
```

旧 Ubuntu が一覧からなくなったことを確認します。仮想ディスクのファイルを直接削除せず、[WSL の登録解除コマンド](https://learn.microsoft.com/en-us/windows/wsl/basic-commands#unregister-or-uninstall-a-linux-distribution)を使います。

続いて [03. Windows アプリ・WSL・Docker]({{ '/docs/03-WINDOWS-DEVELOPMENT-SETUP/' | relative_url }}) の導入手順で `Ubuntu-26.04` をインストールし、初回ユーザー作成とメトリクス設定を完了します。新しい Linux ユーザーと開発環境の設定は、旧 Ubuntu から自動では移りません。

入れ替え後は Windows Terminal の既定プロファイルと Docker Desktop の WSL Integration を新しい Ubuntu に合わせ、Ubuntu 内で `whoami`、`docker version`、`docker compose version` を確認します。`code .` で開いた画面の左下が `WSL: Ubuntu-26.04` であることも確認します。

## 3. 再取得できるキャッシュを整理する

### VS Code と一時ファイル

VS Code を終了してから、ユーザープロファイル直下の `vscode-remote-wsl` が WSL 用サーバーのダウンロードだけを保持していることを確認し、不要なダウンロードを削除します。次回接続時に必要なサーバーが再取得されます。Windows 版 VS Code 本体、`.vscode\extensions`、ユーザー設定やワークスペース情報は残します。[VS Code の WSL 接続の説明](https://code.visualstudio.com/docs/remote/wsl)も参照してください。

Windows の設定 → システム → ストレージ → 一時ファイルで、削除対象を選びます。Downloads とごみ箱は内容を確認してから選び、使用中・ロック中のファイルは残します。`.cache` や `AppData` にはツールの実行環境もあるため、フォルダー名だけで全体を削除しません。

### Docker のビルドキャッシュ

Docker Desktop を起動し、使用量を確認します。ビルドや CI が動いていないときに、不要なビルドキャッシュを削除します。

```powershell
docker system df
docker builder prune --all
docker system df
```

`prune` は削除の確認を求めます。[`docker builder prune --all`](https://docs.docker.com/reference/cli/docker/builder/prune/)は、未使用のビルドキャッシュを削除する操作です。次回ビルドではキャッシュを作り直すため、時間がかかる場合があります。追加の builder を作成している場合は、その builder のキャッシュも個別に確認します。

コンテナ、イメージ、ボリュームの削除は別の判断にします。特にボリュームには DB などの保存データがあるため、キャッシュ整理に含めません。

Docker 内部の空き容量が増えても、Windows 上の VHDX ファイルが同じだけ縮むとは限りません。削除前後で Docker の使用量と Windows の空き容量を別々に確認します。VHDX の直接削除や Docker の初期化で容量を回収しようとしないでください。

## 4. アプリを削除するときの設定の扱い

不要なアプリは Windows の「インストールされているアプリ」からアンインストールします。設定も消す場合は、そのアプリ専用の保存先を確認し、アプリを終了してから残存データを整理します。

ChatGPT のデスクトップアプリを整理するときも、Codex CLI と共有する設定・認証情報・履歴・スキル・ランタイムを区別します。CLI を使い続ける場合は `.codex` 全体や共有の実行環境を削除しません。アプリのバージョン付きパッケージ名や、インストーラーの製品 ID を別の PC へそのまま流用しないようにします。

## 5. ディスクを最適化して結果を確認する

Windows の「ドライブのデフラグと最適化」で媒体と最適化状況を確認します。通常は Windows の自動最適化に任せます。大量削除後の SSD で手動の TRIM が必要な場合は、管理者 PowerShell で対象ドライブを確認してから実行します。

```powershell
Get-PhysicalDisk | Select-Object FriendlyName, MediaType, HealthStatus
Optimize-Volume -DriveLetter C -ReTrim -Verbose
```

この例は C ドライブが TRIM 対応 SSD の場合です。[Microsoft の説明](https://learn.microsoft.com/en-us/powershell/module/storage/optimize-volume)では、SSD と HDD で最適化の処理が異なります。TRIM は空き領域を SSD に通知する処理で、空き容量の増加量や速度改善を保証するものではありません。

最後に、削除対象がなくなったこと、残したアプリが起動すること、WSL・Docker・VS Code の接続が使えることを確認します。Windows の空き容量、削除できなかった使用中ファイル、残した共有設定を記録します。画面操作や接続の確認を含めて完了とし、コマンドの成功だけで判定しません。

[Windows Setup]({{ '/' | relative_url }}) に戻ります。
