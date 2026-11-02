# Windows 11 端末セットアップ（ネットワークエンジニア向け）

## 使い方

1. このフォルダを USB などで対象 PC にコピー
2. （任意）`installers\` に WinShot / ExPing の zip を置く
3. `Setup.bat` をダブルクリック → UAC で「はい」
4. 終了後に再起動

ログは `logs\setup_YYYYMMDD_HHMMSS_user.log`（昇格前）と `logs\setup_YYYYMMDD_HHMMSS_admin.log`（管理者側）に保存されます。何度実行しても問題ありません（インストール済みはスキップ）。

### オプション

```powershell
Setup.bat -SkipApps      # UI 設定だけ
Setup.bat -SkipUI        # ソフトだけ
Setup.bat -SkipSystem    # Windows 機能・電源設定をしない
```

## やること

### UI を Windows 10 風に
| 項目 | 内容 |
|---|---|
| タスクバー | 左寄せ / 結合しない（ラベル表示） / 検索はアイコン / タスクビュー・ウィジェット・チャット・Copilot 非表示 / 時計に秒表示 |
| 右クリック | 従来のメニュー（「その他のオプションを表示」なし） |
| エクスプローラー | 「PC」で開く / 拡張子・隠しファイル表示 / コンパクト表示 / ギャラリー非表示 |
| スタート | Web(Bing)検索なし / おすすめのヒント非表示 |
| Alt+Tab | Edge のタブを出さない |

### ソフト
| ソフト | 入れ方 |
|---|---|
| サクラエディタ | winget `sakura-editor.sakura` |
| Tera Term 5 | winget `TeraTermProject.teraterm5` |
| WinMerge | winget `WinMerge.WinMerge` |
| Omnissa Horizon Client（旧 VMware Horizon） | winget `Omnissa.HorizonClient` |
| Python 3.14（全ユーザー・PATH 追加） | winget `Python.Python.3.14` |
| 7-Zip / WinSCP / Wireshark | winget（既定で ON） |
| PuTTY / Nmap / iPerf3 / VS Code / Git / Open-Shell | winget（既定で OFF） |
| WinShot / ExPing | `installers\` の zip を `C:\Tools\` に展開し、スタートメニューに登録（WinShot は全ユーザー共通のスタートアップにも登録） |

Python パッケージ：netmiko, paramiko, pyserial, textfsm, ntc-templates, ttp, jinja2, netaddr, pyyaml, openpyxl, requests

### システム
- Telnet クライアント / TFTP クライアントを有効化
- 高速スタートアップ無効、AC 電源時はスリープしない

## カスタマイズ

`Setup-Windows.ps1` の先頭にある「設定ここから」〜「設定ここまで」を編集します。
ソフトは `Enabled = $true/$false` で入れるかどうかを切り替えられます。

## 注意

- **スタートメニューと、エクスプローラーのリボンは Windows 11 の標準機能では Windows 10 に戻せません。**
  スタートメニューは `Open-Shell` を `Enabled = $true` にすると Win7/10 風になります。
  タスクバーやリボンまで完全に戻したい場合は ExplorerPatcher（無料）か StartAllBack（有料）を使いますが、
  Windows Update で動かなくなることがあり、会社 PC では使用可否を確認してください。
- UI 設定は「今ログオンしているユーザー」に適用されます。`Setup.bat` はまず通常権限のままユーザー側の UI 設定を行い、
  その後で管理者権限に昇格してソフトや Windows 機能を設定するので、標準ユーザーが別の管理者アカウントで昇格しても UI 設定は入ります。
  （管理者の PowerShell から別アカウントで直接実行した場合だけ、ユーザー側の UI 設定をスキップします）
- スタート検索の Web 結果無効とウィジェット無効は、マシン全体のポリシー（HKLM）として設定します。
- ネットワークドライブから実行しても動くようにしていますが、昇格に使う管理者アカウントがその共有にアクセスできない場合は失敗します。PC にコピーしてから実行するのが確実です。
- Wireshark でパケットをキャプチャするには Npcap が必要です（無償版はサイレントインストールできないため手動で入れます）：https://npcap.com/
- プロキシ環境では、pip は `pip install --proxy http://proxy:port ...` の指定が必要になることがあります。
- `.ps1` は **UTF-8（BOM 付き）・CRLF** で保存してください（BOM なしだと Windows PowerShell 5.1 で日本語が化けてエラーになります）。
