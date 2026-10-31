---
title: 03. Windows アプリ・WSL・Docker
permalink: /docs/03-WINDOWS-DEVELOPMENT-SETUP/
nav_order: 30
nav_label: 03. Windows アプリ・WSL・Docker
nav_section: setup
---

# 03. Windows アプリ・WSL・Docker

Windows 側には GUI と仮想化の境界だけを置き、開発 CLI とランタイムは WSL に集約します。

## 完了条件

- VS Code、Docker Desktop、Chrome、PowerToys が導入されている。
- VS Code の WSL 拡張 `ms-vscode-remote.remote-wsl` が導入されている。
- WSL 本体を `wsl --update` で更新し、Ubuntu の初回起動と Linux ユーザー `kou` の作成が完了している。
- WSL 2 と `Ubuntu-26.04` が導入され、既定ディストリビューションになっている。
- Docker Desktop の WSL 2 engine と `Ubuntu-26.04` integration が有効である。
- Ubuntu 内から `docker`、`docker compose`、`code .` が使える。

## 1. このリポジトリを取得する

Windows PowerShell で次を実行します。Git を Windows へ入れずに、公開リポジトリの ZIP を展開します。

```powershell
$zip = Join-Path $env:TEMP 'windows-setup.zip'
$destination = Join-Path $env:USERPROFILE 'Downloads\windows-setup'
Invoke-WebRequest 'https://github.com/koumatsumoto/windows-setup/archive/refs/heads/main.zip' -OutFile $zip
Expand-Archive $zip -DestinationPath $destination -Force
Set-Location "$destination\windows-setup-main"
```

## 2. 必須アプリと WSL を導入する

`kou` の PowerShell を管理者として開き、ZIP の展開先へ移動してから dry-run を確認します。

```powershell
Set-ExecutionPolicy -Scope Process RemoteSigned
$repo = Join-Path $env:USERPROFILE 'Downloads\windows-setup\windows-setup-main'
Set-Location $repo
& .\scripts\windows\Install-Setup.ps1 -WhatIf
& .\scripts\windows\Install-Setup.ps1
```

パッケージ ID と Ubuntu 名の正本は `scripts/windows/SetupConfig.psd1` です。スクリプトは導入済みアプリをスキップし、`wsl --update` で WSL 本体を通常の安定版経路で更新します。アプリ削除、アカウント操作、OneDrive 設定を行いません。Ubuntu を今回新規導入した場合は、その時点で正常終了します。再起動を求められたら Windows を再起動し、求められなかった場合も同じスクリプトをもう一度実行してください。WSL 本体の更新と既定バージョン・既定ディストリビューションの設定は、再実行時に行います。

再起動後は `kou` の管理者 PowerShell を開き、次のブロック全体を実行します。再起動しなかった場合の再実行にも使えます。ZIP を別の場所に展開した場合は `$repo` を実際の展開先に置き換えてください。

```powershell
Set-ExecutionPolicy -Scope Process RemoteSigned
$repo = Join-Path $env:USERPROFILE 'Downloads\windows-setup\windows-setup-main'
Set-Location $repo
& .\scripts\windows\Install-Setup.ps1
```

## 3. Ubuntu を初回起動する

再起動とスクリプトの再実行を終えてから、`kou` の新しい通常の PowerShell / Windows Terminal を開きます。インストーラーは `--no-launch` を使うため、次のコマンドで明示的に起動します。

```powershell
wsl -d Ubuntu-26.04
```

初回の案内に従って Linux ユーザー `kou` とパスワードを作成します。Ubuntu のプロンプトが表示されたら `whoami` が `kou` であることを確認し、`exit` で PowerShell に戻ります。ここまで完了してから Docker Desktop integration と WSL 側 bootstrap へ進みます。

[Microsoft の WSL コマンド](https://learn.microsoft.com/en-us/windows/wsl/basic-commands)では `wsl --list --online` で配布名を確認し、`wsl --install -d <Distro>` で明示導入できます。このガイドは可変の `Ubuntu` ではなく `Ubuntu-26.04` を固定します。

### メトリクス収集を OFF にする

初回起動で `Would you like to opt-in to platform metrics collection (Y/n)?` と聞かれたら、`n` を入力します。Enter だけで同意しないようにします。

すでに同意した場合は、Ubuntu 内で作成済みのユーザー `kou` として次を実行します。同意設定はユーザーごとなので、`sudo` は付けません。

```bash
ubuntu-insights consent linux wsl_setup ubuntu_release_upgrader --state=false
ubuntu-insights consent linux wsl_setup ubuntu_release_upgrader
```

`linux`、`wsl_setup`、`ubuntu_release_upgrader` がすべて `false` であることを確認します。

今後作成する Ubuntu インスタンスも OFF を既定にする場合は、Windows の通常の PowerShell で次を実行します。

```powershell
$key = 'HKCU:\Software\Canonical\Ubuntu'
if (-not (Test-Path -LiteralPath $key)) {
    New-Item -Path $key -Force | Out-Null
}
New-ItemProperty -Path $key -Name UbuntuInsightsConsent -PropertyType DWord -Value 0 -Force | Out-Null
Get-ItemPropertyValue -Path $key -Name UbuntuInsightsConsent
```

最後の出力が `0` であることを確認します。この Windows 側の値は初期設定時にだけ参照されるため、既存インスタンスには Ubuntu 内のコマンドで変更します。OFF にしても、収集を拒否したことを示す通知だけは送られます。詳細は [Ubuntu のデータ収集と同意設定](https://ubuntu.com/wsl/docs/stable/explanation/data-collection/)を参照してください。

## 4. Docker Desktop を WSL と接続する

1. Docker Desktop を起動する。
2. Settings → General で「Use the WSL 2 based engine」が表示される場合は有効にする。
3. Settings → Resources → WSL Integration で `Ubuntu-26.04` を有効にする。
4. Apply を選ぶ。

Ubuntu 側へ Docker Engine や `docker.io` を別途インストールしません。[Docker 公式](https://docs.docker.com/desktop/features/wsl/)も、WSL 内へ直接入れた Engine / CLI との併用は競合しうると説明しています。

Ubuntu で確認します。

```bash
docker version
docker compose version
```

## 5. VS Code の WSL 拡張を導入して起動する

VS Code 導入後に開いた新しい通常の PowerShell で、[WSL 拡張](https://code.visualstudio.com/docs/remote/wsl-tutorial)を導入します。

```powershell
code --install-extension ms-vscode-remote.remote-wsl
```

完了後、Ubuntu のホーム以下に作業ディレクトリを置き、次を実行します。

```bash
mkdir -p ~/work
cd ~/work
code .
```

初回は VS Code が WSL 用サーバーを導入します。画面左下に `WSL: Ubuntu-26.04` が表示されることを確認します。

## 6. Windows 側を検証する

管理者でない通常の PowerShell から read-only 検証を実行します。

```powershell
Set-ExecutionPolicy -Scope Process RemoteSigned
$repo = Join-Path $env:USERPROFILE 'Downloads\windows-setup\windows-setup-main'
Set-Location $repo
& .\scripts\windows\Verify-Setup.ps1
```

検証では WSL の version / status を診断情報として表示し、WSL 2・既定ディストリビューションと WSL 拡張の有無を確認します。`code` コマンドの存在だけでは WSL window の動作確認になりません。

Explorer、IME、OneDrive、Windows Update、VS Code window などの一部は公開 API だけでは断定できないため、スクリプトが示す「手動確認」も完了させます。

## 次に読む

[04. WSL 開発環境]({{ '/docs/04-UBUNTU-SETUP/' | relative_url }}) に進みます。[Windows Terminal]({{ '/docs/07-WINDOWS-TERMINAL/' | relative_url }}) の見た目は任意です。
