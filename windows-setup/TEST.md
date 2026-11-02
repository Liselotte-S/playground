# テスト手順書：Windows 11 セットアップスクリプト

所要時間の目安：60〜90 分（ダウンロード速度による）

---

## 0. テスト環境の準備

**できれば仮想マシン（Hyper-V / VMware / VirtualBox）の Windows 11 でテストしてください。**
実行前にチェックポイント（スナップショット）を取っておけば、何度でもやり直せます。

> Windows サンドボックスは winget が入っていないため、このテストには使えません。

実機でテストする場合は、実行前に以下を **管理者の PowerShell** で実行しておきます（戻せるようにするため）。

```powershell
# 復元ポイント作成（「システムの保護」が有効な場合のみ成功する）
Checkpoint-Computer -Description "Before Setup-Windows" -RestorePointType MODIFY_SETTINGS

# UI 関係のレジストリをバックアップ
mkdir C:\backup -Force
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" C:\backup\advanced.reg /y
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Search"            C:\backup\search.reg   /y
```

### 事前確認（結果をメモしておく）

| 確認項目 | 方法 | メモ |
|---|---|---|
| Windows のバージョン | `Win + R` → `winver` | 例：24H2 (26100.xxxx) |
| エディション | 設定 → システム → バージョン情報 | Home / Pro / Enterprise |
| winget があるか | コマンドプロンプトで `winget --version` | |
| ログオンユーザーが管理者か | 設定 → アカウント | 管理者 / 標準ユーザー |
| プロキシ環境か | 社内ネットワークかどうか | |

---

## 1. ファイルの入手

1. GitHub の `Liselotte-S/playground` を開く
2. ブランチを **`claude/windows-setup-script`** に切り替える
3. 「Code」→「Download ZIP」でダウンロード
4. **zip を右クリック → プロパティ →「許可する」にチェック → OK**（展開する前に行う）
5. 展開して、中の `windows-setup` フォルダを `C:\work\windows-setup` などに置く

（任意）WinShot / ExPing の zip を入手して `windows-setup\installers\` に置く。
置かない場合は「WARN」と表示されるのが正常な動作です。

---

## 2. 段階的にテストする

いきなり全部を流さず、**A → B → C → D の順に 1 つずつ** 実行します。
各ステップの終わりに、確認表の「結果」欄に ○ / × を記入してください。

### 実行のしかた（引数を付ける場合）

1. エクスプローラーで `windows-setup` フォルダを開く
2. アドレスバーに `cmd` と入力して Enter（そのフォルダでコマンドプロンプトが開く）
3. 下の各ステップのコマンドを入力
4. UAC の画面が出たら「はい」
5. 新しく開いた青いウィンドウで処理が進み、最後に **結果の表** が出る → **スクリーンショットを撮る**
6. Enter で閉じる

---

### ステップ A：UI だけを変更

```bat
Setup.bat -SkipApps -SkipSystem
```

途中で画面が一瞬消える（エクスプローラーの再起動）のは正常です。
終わったら **一度サインアウトしてサインインし直してから** 確認します。

| # | 確認項目 | 期待する結果 | 結果 |
|---|---|---|---|
| A1 | タスクバーのアイコンの位置 | 左寄せ | |
| A2 | 検索 | 虫めがねのアイコンだけ（入力欄なし） | |
| A3 | タスクビューのボタン | 表示されない | |
| A4 | ウィジェット（左下の天気など） | 表示されない | |
| A5 | Copilot / チャットのボタン | 表示されない | |
| A6 | アプリを 2 つ以上開いた時のタスクバー | ボタンが結合されず、アプリ名が表示される | |
| A7 | 右下の時計 | 秒まで表示される | |
| A8 | デスクトップやファイルを右クリック | いきなり従来のメニュー（「その他のオプションを表示」が出ない） | |
| A9 | エクスプローラーを開く（`Win + E`） | 「PC」が開く（ホームではない） | |
| A10 | ファイル名 | 拡張子（.txt など）が表示される | |
| A11 | `C:\ProgramData` | フォルダが（半透明で）表示される＝隠しファイル表示 | |
| A12 | エクスプローラーの行間 | 詰まっている（表示 → コンパクト ビューにチェック） | |
| A13 | エクスプローラー左側 | 「ギャラリー」が無い | |
| A14 | スタートで `abc` と検索 | Web（Bing）の検索結果が出ない | |
| A15 | Edge でタブを複数開いて `Alt + Tab` | Edge のタブが個別に出ない | |

---

### ステップ B：ソフトのインストール

```bat
Setup.bat -SkipUI -SkipSystem
```

時間がかかります（特に Horizon Client と Python）。途中で止まっているように見えても、10 分程度は待ってください。

| # | 確認項目 | 方法 / 期待する結果 | 結果 |
|---|---|---|---|
| B1 | サクラエディタ | スタートメニューにあり、起動できる | |
| B2 | Tera Term | 起動できる。メニューが日本語 | |
| B3 | WinMerge | 起動できる | |
| B4 | Horizon Client | **再起動後に** 起動できる | |
| B5 | 7-Zip / WinSCP / Wireshark | それぞれ起動できる | |
| B6 | Python | **新しく開いた** コマンドプロンプトで `python --version` → `Python 3.14.x` | |
| B7 | py ランチャー | `py -0` → 3.14 が表示される | |
| B8 | Python ライブラリ | `python -c "import netmiko, paramiko, serial, textfsm, ttp, jinja2, netaddr, yaml, openpyxl, requests; print('OK')"` → `OK` | |
| B9 | WinShot（zip を置いた場合） | `C:\Tools\WinShot` に展開され、スタートメニュー「Tools」にある。サインインし直すとタスクトレイに常駐する | |
| B10 | ExPing（zip を置いた場合） | `C:\Tools\ExPing` に展開され、スタートメニュー「Tools」にある | |
| B11 | zip を置かなかった場合 | 結果の表で WARN と入手先が表示される（エラーで止まらない） | |

---

### ステップ C：Windows の機能・電源設定

```bat
Setup.bat -SkipUI -SkipApps
```

終わったら **再起動** してから確認します。

| # | 確認項目 | 方法 / 期待する結果 | 結果 |
|---|---|---|---|
| C1 | Telnet クライアント | `where telnet` → `C:\Windows\System32\telnet.exe` | |
| C2 | TFTP クライアント | `where tftp` → `C:\Windows\System32\TFTP.EXE` | |
| C3 | 高速スタートアップ | `reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled` → `0x0` | |
| C4 | AC 電源時のスリープ | 設定 → システム → 電源 →「電源接続時に、次の時間が経過した後にデバイスをスリープ状態にする」が「なし」 | |

---

### ステップ D：全部まとめて再実行（2 回目）

```bat
Setup.bat
```

または `Setup.bat` をダブルクリック。

| # | 確認項目 | 期待する結果 | 結果 |
|---|---|---|---|
| D1 | エラーにならずに最後まで進むか | 最後まで進む | |
| D2 | ソフトの結果 | 「SKIP（インストール済み）」になり、入れ直さない | |
| D3 | Windows 機能 | 「SKIP（有効化済み）」 | |
| D4 | NG の件数 | 0 件 | |

---

## 3. （余裕があれば）異常系のテスト

| # | 内容 | 方法 | 期待する結果 | 結果 |
|---|---|---|---|---|
| E1 | 標準ユーザーで実行 | 標準ユーザーでサインインし、`Setup.bat -SkipApps -SkipSystem` を実行。UAC で別の管理者 ID とパスワードを入力 | 「ユーザーが異なります」の警告が出て、UI 設定がスキップされる | |
| E2 | ネットワークを切って実行 | LAN / Wi-Fi を切って `Setup.bat -SkipUI -SkipSystem` | 各ソフトが NG になるが、スクリプトは最後まで進んで結果の表が出る | |

---

## 4. 報告してほしいもの

以下をまとめて送ってください。

1. **0 章の事前確認のメモ**（Windows のバージョン、エディションなど）
2. **確認表**（○ / × を記入したもの）
3. **各ステップの最後に出た結果の表のスクリーンショット**
4. **ログファイル**：`windows-setup\logs\setup_*.log`（全部）
5. × になった項目は、**どう表示されたか**（スクリーンショットかエラーの文言）

---

## 5. 元に戻す方法

### 仮想マシンの場合
チェックポイント（スナップショット）に戻すだけで終わりです。

### 実機の場合

**UI 設定を戻す**（ふつうの PowerShell で実行）

```powershell
reg import C:\backup\advanced.reg
reg import C:\backup\search.reg
reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f   # 右クリックメニュー
reg delete "HKCU\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" /f   # ギャラリー
reg delete "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /f
Stop-Process -Name explorer -Force
```

**ウィジェットを戻す**（管理者の PowerShell で実行）

```powershell
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /f
```

**ソフトを削除する**（例）

```powershell
winget uninstall --id Omnissa.HorizonClient -e
```

WinShot / ExPing は `C:\Tools` のフォルダと、スタートメニューの「Tools」フォルダを削除します。

**全部まとめて戻す場合**は、コントロールパネル →「回復」→「システムの復元を開く」から、0 章で作った復元ポイント「Before Setup-Windows」を選びます。
