---
title: 02. 日本語入力と Windows 設定
permalink: /docs/02-WINDOWS-SETUP/
nav_order: 20
nav_label: 02. 日本語入力と Windows 設定
nav_section: setup
---

# 02. 日本語入力と Windows 設定

日本語表示と入力の癖、Explorer、OneDrive を復旧します。プリインストールアプリの一括削除は行いません。

## 完了条件

- 表示言語、国または地域、地域形式、システムロケール、キーボードが日本語である。
- `無変換 = IME オフ`、`変換 = IME オン/オフ切り替え`、`Ctrl + Space = 割り当てなし`になっている。
- 対象の LG gram では、スペース右の「カタカナ／ひらがな／ローマ字」を「変換」として使え、PowerToys がなくても IME を切り替えられる。
- Explorer に拡張子と隠しファイルが表示される。
- OneDrive は未サインイン、フォルダーバックアップ無効、自動起動無効で、アプリ自体は残っている。
- Known Folder の実パスが `C:\Users\kou` の直下から移動していない。

## 1. 日本語設定

設定 → 時刻と言語 → 言語と地域 で次を確認します。

- Windows の表示言語: 日本語
- 国または地域: 日本
- 地域形式: 日本語（日本）
- 優先する言語の先頭: 日本語
- 日本語のキーボード: Microsoft IME

設定検索で「管理用の言語の設定」を開き、「システム ロケールの変更」で日本語（日本）を選びます。変更した場合は再起動します。

## 2. Microsoft IME のキー設定

設定 → 時刻と言語 → 言語と地域 → 日本語 → 言語のオプション → Microsoft IME → キーボード オプション → キーとタッチのカスタマイズ を開きます。「キーの割り当て」を有効にし、次の値へ合わせます。

| キー | 動作 |
| --- | --- |
| 無変換 | IME オフ |
| 変換 | IME オン/オフ |
| Ctrl + Space | なし（割り当てない） |

メモ帳で日本語入力を開き、各キーの実挙動を確認します。IME 設定は安定した公開自動化インターフェースがないため、画面と実入力を正本にします。

「IME オン/オフ」は押すたびに日本語入力を切り替える設定です。「IME オン」は日本語入力を有効にするだけなので、このガイドでは選びません。設定項目の詳細は [Microsoft 日本語 IME](https://support.microsoft.com/ja-jp/windows/hardware/input-devices/microsoft-japanese-ime) を参照してください。

### LG gram のスペース右のキーを「変換」にする

スペース左が Alt、右が「カタカナ／ひらがな／ローマ字」で、変換・無変換キーがない LG gram 向けの手順です。2026-10-31 に `16Z90U-KUB5J` の日本語配列で設定し、再起動後に利用者が PowerToys なしで動作することを実入力で確認しました。機種名だけで全 gram に適用せず、同じ配列であることを確認します。通常の JIS キーボードで変換・無変換キーを使える場合、この置き換えは不要です。

Windows 標準の `Scancode Map` に次の 1 件を登録します。追加アプリや常駐処理は不要で、Alt キーは変更しません。

| 押すキー | 元のスキャンコード | 置き換え先 | 置き換え先のスキャンコード |
| --- | --- | --- | --- |
| カタカナ／ひらがな／ローマ字 | `0x0070` | 変換 | `0x0079` |

この設定は全ユーザーと接続中の全キーボードに適用されます。外付け JIS キーボードの同じキーも「変換」になります。元のかなキーの機能や修飾キーとの組み合わせも変わるため、外付けキーボードを使う場合は合わせて確認します。登録・解除には管理者権限と Windows の再起動が必要です。[Microsoft の Scan Code Mapper の説明](https://learn.microsoft.com/en-us/previous-versions/windows/hardware/hid/keyboard-and-mouse-class-drivers#scan-code-mapper-for-keyboards)

管理者 PowerShell で次を実行します。既存の値が今回の 1 件と同じなら変更せず、異なる割り当てがある場合は上書きせず停止します。この処理はアプリ導入スクリプトからは実行しません。

```powershell
$ErrorActionPreference = 'Stop'
$keyPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout'
[byte[]]$map = @(0,0,0,0,0,0,0,0,2,0,0,0,0x79,0,0x70,0,0,0,0,0)
$key = Get-Item -LiteralPath $keyPath
if ($key.GetValueNames() -contains 'Scancode Map') {
    $current = $key.GetValue('Scancode Map')
    if ($current -isnot [byte[]] -or
        [Convert]::ToBase64String($current) -ne [Convert]::ToBase64String($map)) {
        throw '既存の Scancode Map が異なります。内容を確認し、上書きしないでください。'
    }
} else {
    New-ItemProperty -LiteralPath $keyPath -Name 'Scancode Map' `
        -PropertyType Binary -Value $map | Out-Null
}
[BitConverter]::ToString((Get-Item -LiteralPath $keyPath).GetValue('Scancode Map'))
```

表示される値が `00-00-00-00-00-00-00-00-02-00-00-00-79-00-70-00-00-00-00-00` であることを確認します。

1. PowerToys から移行する場合は、Keyboard Manager と PowerToys の「起動時に実行」を無効にし、PowerToys を終了する。
2. Windows を再起動する。
3. メモ帳でスペース右のキーを押し、日本語入力のオンとオフが切り替わることを確認する。IME オフの状態からも、オンの状態からも確認する。
4. PowerToys が起動していないことを確認し、導入済みなら Windows の「インストールされているアプリ」からアンインストールする。

この用途で PowerToys を再導入する必要はありません。無変換キーを持つ外付けキーボードでは無変換による IME オフも使えますが、gram の左 Alt は Alt のままです。

PowerToys の設定も不要になった場合は、アンインストール後に専用の `%LOCALAPPDATA%\Microsoft\PowerToys` フォルダーと `HKEY_CURRENT_USER\Software\Microsoft\PowerToys` キーの残存を確認して削除します。インストール先、スタートアップ、実行中プロセスも確認し、Windows 標準の `Scancode Map` は残します。一時的な設定バックアップや復元スクリプトを作った場合も、動作確認後に不要なら削除します。

置き換えを解除する場合は、管理者 PowerShell で現在の `Scancode Map` が上記の 1 件だけであることを確認し、次を実行して Windows を再起動します。他の割り当てを追加した場合は、その値全体を削除せず個別に見直してください。

```powershell
$ErrorActionPreference = 'Stop'
$keyPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout'
[byte[]]$expected = @(0,0,0,0,0,0,0,0,2,0,0,0,0x79,0,0x70,0,0,0,0,0)
$key = Get-Item -LiteralPath $keyPath
if ($key.GetValueNames() -contains 'Scancode Map') {
    $current = $key.GetValue('Scancode Map')
    if ($current -isnot [byte[]] -or
        [Convert]::ToBase64String($current) -ne [Convert]::ToBase64String($expected)) {
        throw 'Scancode Map が変更されています。値全体を削除せず、内容を確認してください。'
    }
    Remove-ItemProperty -LiteralPath $keyPath -Name 'Scancode Map'
}
```

## 3. Explorer

Explorer → 表示 → 表示 で「ファイル名拡張子」と「隠しファイル」を有効にします。アドレスバーへ `%USERPROFILE%` を入力し、`Desktop`、`Documents`、`Downloads`、`Pictures` が英語名の実フォルダーとして存在することも確認します。

## 4. OneDrive を使わない状態にする

Windows や Microsoft アカウントの案内で、OneDrive のサインイン、Windows Backup の復元、フォルダーバックアップを開始しません。

すでに OneDrive が関連付いている場合:

1. 通知領域の OneDrive → ヘルプと設定 → 設定 → アカウント を開く。
2. 「この PC のリンク解除」を実行する。
3. 同期とバックアップ → バックアップを管理 で Desktop、Documents、Pictures がすべてオフであることを確認する。
4. 設定 → アプリ → スタートアップ で Microsoft OneDrive をオフにする。
5. OneDrive を終了する。アプリのアンインストールはしない。

フォルダーバックアップを停止すると既存ファイルの場所を選ぶ画面が出る場合があります。実ファイルを `C:\Users\kou\Desktop`、`Documents`、`Pictures` に戻したうえで、次のパス確認を行います。クラウド側だけにあるファイルの移動はこのガイドでは自動化しません。

```powershell
[Environment]::GetFolderPath('Desktop')
[Environment]::GetFolderPath('MyDocuments')
[Environment]::GetFolderPath('MyPictures')
(Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders').'{374DE290-123F-4565-9164-39C4925E467B}'
Get-CimInstance Win32_StartupCommand | Where-Object Name -Match OneDrive
Get-Process OneDrive -ErrorAction SilentlyContinue
```

最初の4行が `C:\Users\kou` 直下を指し、再サインイン後に後半2つが何も返さないことを確認します。OneDrive のリンク解除は [Microsoft の公式手順](https://support.microsoft.com/en-US/onedrive/how-to-remove-an-account-in-onedrive)、フォルダーバックアップは [バックアップ管理](https://support.microsoft.com/en-US/onedrive/back-up-your-folders-with-onedrive) を参照します。

## 次に読む

[03. Windows アプリ・WSL・Docker]({{ '/docs/03-WINDOWS-DEVELOPMENT-SETUP/' | relative_url }}) に進みます。
