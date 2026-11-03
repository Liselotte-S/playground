# 引き継ぎ：Windows 11 セットアップスクリプト

## 概要
ネットワークエンジニア向けの Windows 11 端末を、1 回の実行でセットアップするスクリプトです。
**実機ではまだ一度も動かしていません。** 実際の環境に合わせたテストをお願いします。

## 使い方
1. `windows-setup` フォルダを対象 PC にコピーする（GitHub から zip で落とした場合は、展開する前に zip のプロパティで「許可する」にチェック）
2. WinShot / ExPing を入れる場合は、その zip を `installers\` に置く
3. `Setup.bat` をダブルクリック → UAC で「はい」
4. 終わったら再起動

一部だけ実行することもできます：`Setup.bat -SkipApps`（UI だけ）／`-SkipUI`（ソフトだけ）／`-SkipSystem`（Windows 機能・電源設定をしない）
何度実行しても大丈夫です（インストール済みのものはスキップします）。

## やること
- **UI を Windows 10 風に**：タスクバーを左寄せ・アイコンのみ、不要なボタンを非表示、右クリックメニューを従来版に、エクスプローラーを「PC」で開く、拡張子と隠しファイルを表示 など
- **ソフト（winget）**：サクラエディタ、Tera Term 5、WinMerge、Horizon Client、Webex、Python 3.14、7-Zip、WinSCP、Wireshark
- **WinShot / ExPing**：`installers\` の zip を `C:\Tools` に展開し、スタートメニューに登録
- **デスクトップ**：上記ソフトのショートカットを全ユーザー共通のデスクトップに作成
- **Python ライブラリ**：netmiko、paramiko、pyserial、textfsm など
- **Windows**：Telnet / TFTP クライアントを有効化、高速スタートアップ無効、AC 電源時はスリープしない

入れるソフトや設定の ON / OFF は、`Setup-Windows.ps1` の先頭「設定ここから」で切り替えます。

## 特に見てほしいところ
- winget で各ソフトが入るか（特に Horizon Client と Python）
- 各ソフトのショートカットがデスクトップにできるか（スタートメニューのショートカット名から探しているため、名前が違うと WARN になる → 設定の `Desktop` を直す）
- 社内のプロキシ環境で、winget と pip がネットにつながるか
- サインインし直した後に、UI の設定が反映されているか

## 分かっている制限
- スタートメニューとエクスプローラーのリボンは、Windows 11 の標準機能では Windows 10 に戻せない（スタートメニューは設定で Open-Shell を ON にすれば Win10 風になる）
- Wireshark でキャプチャするには Npcap が必要（手動でインストール）
- ウィジェット（タスクバーの天気）は消せない。Windows 11 ビルド 26300 では、ボタンの設定(`TaskbarDa`)もポリシー(`HKLM\SOFTWARE\Policies\Microsoft\Dsh`)も、管理者でも書き込みが拒否される（結果に WARN が出る）。必要なら「設定 → 個人用設定 → タスク バー → ウィジェット」を手動でオフにする
- 管理者の PowerShell から、ログオン中とは別のアカウントで直接実行した場合は、ユーザー側の UI 設定がスキップされる（`Setup.bat` をダブルクリックすれば昇格前に適用されるので問題なし）

## 問題があったとき
`logs\setup_*_user.log` と `logs\setup_*_admin.log`、最後に出る結果の表のスクリーンショットを送ってください。
