#Requires -Version 5.1
<#
.SYNOPSIS
    ネットワークエンジニア向け Windows 11 端末セットアップスクリプト

.DESCRIPTION
    1. Windows 11 の UI を Windows 10 風に変更（タスクバー / エクスプローラー / 右クリックメニュー）
    2. winget でソフトを一括インストール
       サクラエディタ / Tera Term / WinMerge / Omnissa Horizon Client / Python ほか
    3. winget に無いソフト（WinShot / ExPing）を installers フォルダから展開・配置
    4. Python のネットワーク系ライブラリを pip でインストール
    5. Windows 機能（Telnet / TFTP クライアント）の有効化、電源設定

    設定は下の「設定ここから」の部分を編集して変更します。

.PARAMETER SkipApps
    ソフトのインストールをスキップ
.PARAMETER SkipUI
    UI（Windows 10 風）の変更をスキップ
.PARAMETER SkipSystem
    Windows 機能・電源設定をスキップ
.PARAMETER NoPause
    終了時に Enter 待ちをしない
.PARAMETER Elevated
    （内部用）昇格前のプロセスがユーザー側の UI 設定を済ませた後に、管理者側として起動されたことを示す
.PARAMETER ResultPath
    （内部用）管理者側の結果を書き出す JSON ファイル

.NOTES
    実行の流れ（Setup.bat をダブルクリックした場合）
      1. 通常権限のまま、ログオン中のユーザーに UI 設定(HKCU)を適用し、エクスプローラーを再起動
      2. 管理者権限に昇格して、ソフト / Windows 機能 / マシン全体のポリシーを設定
      3. 両方の結果をまとめて表示
    標準ユーザーが別の管理者アカウントで昇格しても、UI 設定は 1 でログオン中のユーザーに入る。

.EXAMPLE
    Setup.bat をダブルクリック（管理者権限への昇格は自動）
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Setup-Windows.ps1 -SkipApps
#>
[CmdletBinding()]
param(
    [switch]$SkipApps,
    [switch]$SkipUI,
    [switch]$SkipSystem,
    [switch]$NoPause,
    [switch]$Elevated,
    [string]$ResultPath
)

# ============================================================================
#  設定ここから
# ============================================================================

# --- winget でインストールするソフト ----------------------------------------
#   Enabled = $false にすると入れない。Id は `winget search <名前>` で確認できる。
$WingetApps = @(
    # ---- 必須 ----
    @{ Enabled = $true;  Name = 'サクラエディタ';         Id = 'sakura-editor.sakura' }
    @{ Enabled = $true;  Name = 'Tera Term 5';            Id = 'TeraTermProject.teraterm5' }
    @{ Enabled = $true;  Name = 'WinMerge';               Id = 'WinMerge.WinMerge' }
    @{ Enabled = $true;  Name = 'Omnissa Horizon Client'; Id = 'Omnissa.HorizonClient' }
    @{ Enabled = $true;  Name = 'Python 3.14';            Id = 'Python.Python.3.14'
       # 全ユーザー向け + PATH 追加 + py ランチャー
       Override = '/quiet InstallAllUsers=1 PrependPath=1 Include_launcher=1 InstallLauncherAllUsers=1 Include_test=0' }

    # ---- あると便利（不要なら $false に） ----
    @{ Enabled = $true;  Name = '7-Zip';                  Id = '7zip.7zip' }
    @{ Enabled = $true;  Name = 'WinSCP';                 Id = 'WinSCP.WinSCP' }
    @{ Enabled = $true;  Name = 'Wireshark';              Id = 'WiresharkFoundation.Wireshark' }   # Npcap は別途手動インストール
    @{ Enabled = $false; Name = 'PuTTY';                  Id = 'PuTTY.PuTTY' }
    @{ Enabled = $false; Name = 'Nmap';                   Id = 'Insecure.Nmap' }
    @{ Enabled = $false; Name = 'iPerf3';                 Id = 'ar51an.iPerf3' }
    @{ Enabled = $false; Name = 'Visual Studio Code';     Id = 'Microsoft.VisualStudioCode' }
    @{ Enabled = $false; Name = 'Git';                    Id = 'Git.Git' }

    # ---- スタートメニューも Windows 10/7 風にしたい場合 ----
    @{ Enabled = $false; Name = 'Open-Shell';             Id = 'Open-Shell.Open-Shell-Menu' }
)

# --- winget に無いソフト（installers フォルダに置いたファイルを使う） ---------
#   Patterns に一致する zip / exe を installers フォルダから探す。
#   zip → Dest に展開してスタートメニューにショートカット作成
#   exe → インストーラーとして起動（画面の指示に従って操作）
$InstallerDir = Join-Path $PSScriptRoot 'installers'
$ToolsRoot    = 'C:\Tools'
$LocalApps = @(
    @{ Enabled = $true; Name = 'WinShot'; Patterns = @('ws1*.zip', 'winshot*.zip', 'ws1*.exe', 'winshot*.exe')
       Dest = (Join-Path $ToolsRoot 'WinShot'); Exe = 'WinShot.exe'; Startup = $true   # ログオン時に常駐
       Info = '窓の杜 https://forest.watch.impress.co.jp/library/software/winshot/' }
    @{ Enabled = $true; Name = 'ExPing';  Patterns = @('exping*.zip', 'exping*.exe')
       Dest = (Join-Path $ToolsRoot 'ExPing');  Exe = 'ExPing.exe';  Startup = $false
       Info = 'Vector で「ExPing」を検索してダウンロード' }
)

# --- Python パッケージ --------------------------------------------------------
$PythonPackages = @(
    'netmiko'        # SSH/Telnet で NW 機器操作
    'paramiko'       # SSH
    'pyserial'       # コンソール（シリアル）接続
    'textfsm'        # show コマンドのパース
    'ntc-templates'  # TextFSM テンプレート集
    'ttp'            # テンプレートベースのパーサー
    'jinja2'         # コンフィグ生成
    'netaddr'        # IP アドレス計算
    'pyyaml'
    'openpyxl'       # Excel パラメータシート読み書き
    'requests'
)

# --- UI 設定（Windows 10 風） -------------------------------------------------
$UI = @{
    TaskbarLeft          = $true   # タスクバーのアイコンを左寄せ
    SearchboxMode        = 1       # 検索: 0=非表示 1=アイコン 2=検索ボックス(Win10風) 3=アイコン+ラベル
    TaskbarCombine       = 2       # ボタン結合: 0=常に結合 1=いっぱいの時 2=結合しない(ラベル表示)
    HideTaskView         = $true   # タスクビューボタン非表示
    HideWidgets          = $true   # ウィジェット非表示（ポリシーで無効化）
    HideChatCopilot      = $true   # チャット / Copilot ボタン非表示
    ShowClockSeconds     = $true   # 時計に秒を表示（ログ突合せに便利）
    ClassicContextMenu   = $true   # 右クリックメニューを従来版に（「その他のオプション」を省略）
    ExplorerOpenThisPC   = $true   # エクスプローラーを「PC」で開く
    ShowFileExtensions   = $true   # 拡張子を表示
    ShowHiddenFiles      = $true   # 隠しファイルを表示
    CompactMode          = $true   # エクスプローラーの行間を詰める（Win10 と同等）
    HideGallery          = $true   # ナビゲーションの「ギャラリー」を非表示
    DisableWebSearch     = $true   # スタート検索で Bing を使わない
    DisableStartRecommend= $true   # スタートの「おすすめ」のヒント類を非表示
    AltTabWindowsOnly    = $true   # Alt+Tab に Edge のタブを出さない
}

# --- システム設定 -------------------------------------------------------------
$Sys = @{
    EnableTelnetClient   = $true   # Telnet クライアント
    EnableTftpClient     = $true   # TFTP クライアント
    DisableFastStartup   = $true   # 高速スタートアップ無効（NIC / ドライバ周りのトラブル回避）
    NoSleepOnAC          = $true   # AC 電源時にスリープしない（長時間ログ取得・ping 監視用）
}

# ============================================================================
#  設定ここまで
# ============================================================================

$ErrorActionPreference = 'Stop'
$script:Results = New-Object System.Collections.Generic.List[object]
$script:RebootRequired = $false

#region ---- 共通関数 ----------------------------------------------------------
function Write-Section([string]$Text) {
    Write-Host ''
    Write-Host ('=' * 70) -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host ('=' * 70) -ForegroundColor Cyan
}
function Add-Result([string]$Category, [string]$Item, [string]$Status, [string]$Note = '') {
    $script:Results.Add([pscustomobject]@{ Category = $Category; Item = $Item; Result = $Status; Note = $Note })
    $color = switch ($Status) { 'OK' { 'Green' } 'SKIP' { 'DarkGray' } 'WARN' { 'Yellow' } default { 'Red' } }
    $msg = "  [$Status] $Item"
    if ($Note) { $msg += "  ($Note)" }
    Write-Host $msg -ForegroundColor $color
}
function Set-Reg {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] $Value,
        [ValidateSet('DWord', 'String')] [string]$Type = 'DWord',
        [string]$Label = "$Name"
    )
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        Add-Result 'UI/設定' $Label 'OK'
    } catch {
        Add-Result 'UI/設定' $Label 'WARN' $_.Exception.Message
    }
}
function Test-WingetInstalled([string]$Id) {
    # PS 5.1 では EAP=Stop のままネイティブコマンドの stderr をリダイレクトすると例外になるため一時的に変更
    $ErrorActionPreference = 'Continue'
    $null = & winget.exe list --id $Id --exact --accept-source-agreements --disable-interactivity 2>&1
    return ($LASTEXITCODE -eq 0)
}
function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}
function New-Shortcut([string]$LinkPath, [string]$Target) {
    $dir = Split-Path $LinkPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $ws = New-Object -ComObject WScript.Shell
    $lnk = $ws.CreateShortcut($LinkPath)
    $lnk.TargetPath = $Target
    $lnk.WorkingDirectory = Split-Path $Target
    $lnk.Save()
}
function Expand-ZipFile([string]$ZipPath, [string]$Dest) {
    # PS 5.1 の Expand-Archive は Shift_JIS のファイル名が化けるため、.NET で cp932 を指定して展開する
    # （UTF-8 フラグ付きのエントリは自動的に UTF-8 として読まれる）
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    $destRoot = [IO.Path]::GetFullPath($Dest).TrimEnd('\') + '\'
    $zip = [IO.Compression.ZipFile]::Open($ZipPath, 'Read', [Text.Encoding]::GetEncoding(932))
    try {
        foreach ($entry in $zip.Entries) {
            $target = [IO.Path]::GetFullPath((Join-Path $destRoot $entry.FullName))
            if (-not $target.StartsWith($destRoot, [StringComparison]::OrdinalIgnoreCase)) {
                throw "zip 内に展開先の外を指すパスがあります: $($entry.FullName)"
            }
            if ($entry.Name -eq '') { New-Item -ItemType Directory -Path $target -Force | Out-Null; continue }
            New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
        }
    } finally { $zip.Dispose() }
}
function Get-UncPath([string]$Path) {
    # ネットワークドライブ(Z: など)は昇格後のプロセスから見えないので、\\server\share 形式に変換する
    try {
        $qualifier = Split-Path $Path -Qualifier
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$qualifier'"
        if ($disk.DriveType -eq 4 -and $disk.ProviderName) {
            return $disk.ProviderName + $Path.Substring($qualifier.Length)
        }
    } catch { }
    return $Path
}
function Restart-Explorer {
    Write-Section 'エクスプローラーを再起動して UI 設定を反映'
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    # 通常は Winlogon が自動で再起動する（AutoRestartShell）ので、それを待つ
    for ($i = 0; $i -lt 10 -and -not (Get-Process -Name explorer -ErrorAction SilentlyContinue); $i++) {
        Start-Sleep -Seconds 1
    }
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        if ($script:IsAdmin) {
            # 管理者のまま起動するとシェル全体が管理者権限になるため、権限を落として起動する
            & runas.exe /trustlevel:0x20000 "$env:WINDIR\explorer.exe"
        } else {
            Start-Process "$env:WINDIR\explorer.exe"
        }
    }
}
function Show-Summary {
    Write-Section '結果'
    $script:Results | Format-Table -AutoSize -Wrap | Out-String -Width 200 | Write-Host

    $ng   = @($script:Results | Where-Object { $_.Result -eq 'NG' }).Count
    $warn = @($script:Results | Where-Object { $_.Result -eq 'WARN' }).Count
    Write-Host "NG: $ng 件 / WARN: $warn 件" -ForegroundColor $(if ($ng) { 'Red' } elseif ($warn) { 'Yellow' } else { 'Green' })
    Write-Host ''
    Write-Host '手動で行うこと:' -ForegroundColor Yellow
    Write-Host '  - Wireshark でキャプチャするには Npcap が必要（https://npcap.com/ から手動インストール）'
    Write-Host '  - 一部の設定(ウィジェット無効・秒表示など)はサインアウト/再起動後に反映'
    if ($script:RebootRequired -or -not $SkipSystem) {
        Write-Host '  - 再起動してください（Windows 機能・Horizon Client などの反映のため）' -ForegroundColor Yellow
    }
}
#endregion

#region ---- ログ ---------------------------------------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$script:IsAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$logDir = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir ("setup_{0:yyyyMMdd_HHmmss}_{1}.log" -f (Get-Date), $(if ($script:IsAdmin) { 'admin' } else { 'user' }))
Start-Transcript -Path $logFile | Out-Null

$os = Get-CimInstance Win32_OperatingSystem
Write-Host "OS      : $($os.Caption) (Build $($os.BuildNumber))"
Write-Host "ユーザー: $env:USERDOMAIN\$env:USERNAME（管理者権限: $script:IsAdmin）"
Write-Host "ログ    : $logFile"
#endregion

# ============================================================================
#  1. UI を Windows 10 風に
#     ユーザー側(HKCU)は管理者権限なしで書けるので、昇格前にログオン中のユーザーで適用する。
#     HKCU\Software\Policies は管理者しか書けないため、ポリシー系はマシン全体(HKLM)に入れる。
# ============================================================================
function Invoke-UserUI {
    Write-Section '1. UI を Windows 10 風に変更'

    $adv    = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $search = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'

    # ---- タスクバー ----
    if ($UI.TaskbarLeft)     { Set-Reg $adv 'TaskbarAl' 0 -Label 'タスクバー左寄せ' }
    if ($UI.HideTaskView)    { Set-Reg $adv 'ShowTaskViewButton' 0 -Label 'タスクビューボタン非表示' }
    if ($UI.HideChatCopilot) {
        Set-Reg $adv 'TaskbarMn' 0 -Label 'チャットボタン非表示'
        Set-Reg $adv 'ShowCopilotButton' 0 -Label 'Copilot ボタン非表示'
    }
    if ($null -ne $UI.SearchboxMode) {
        Set-Reg $search 'SearchboxTaskbarMode' ([int]$UI.SearchboxMode) -Label "検索表示モード=$($UI.SearchboxMode)"
    }
    if ($null -ne $UI.TaskbarCombine) {
        Set-Reg $adv 'TaskbarGlomLevel'   ([int]$UI.TaskbarCombine) -Label "タスクバー結合=$($UI.TaskbarCombine)"
        Set-Reg $adv 'MMTaskbarGlomLevel' ([int]$UI.TaskbarCombine) -Label "タスクバー結合(マルチモニター)=$($UI.TaskbarCombine)"
    }
    if ($UI.HideWidgets) {
        # 24H2 以降は TaskbarDa を直接書けない(UCPD で保護)ことがあるので、Invoke-MachineUI でポリシーでも無効化
        try {
            Set-ItemProperty -Path $adv -Name 'TaskbarDa' -Value 0 -Type DWord -Force
            Add-Result 'UI/設定' 'ウィジェットボタン非表示' 'OK'
        } catch {
            Add-Result 'UI/設定' 'ウィジェットボタン非表示' 'SKIP' '保護キーのためポリシー側で対応'
        }
    }
    if ($UI.ShowClockSeconds) { Set-Reg $adv 'ShowSecondsInSystemClock' 1 -Label '時計に秒を表示' }

    # ---- スタート / 検索 ----
    if ($UI.DisableStartRecommend) {
        Set-Reg $adv 'Start_IrisRecommendations' 0 -Label 'スタートのおすすめ(ヒント)非表示'
    }
    if ($UI.AltTabWindowsOnly) { Set-Reg $adv 'MultiTaskingAltTabFilter' 3 -Label 'Alt+Tab はウィンドウのみ' }

    # ---- 右クリックメニュー ----
    if ($UI.ClassicContextMenu) {
        & reg.exe add 'HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' /f /ve | Out-Null
        if ($LASTEXITCODE -eq 0) { Add-Result 'UI/設定' '右クリックメニューを従来版に' 'OK' }
        else                     { Add-Result 'UI/設定' '右クリックメニューを従来版に' 'NG' "reg.exe exit $LASTEXITCODE" }
    }

    # ---- エクスプローラー ----
    if ($UI.ExplorerOpenThisPC) { Set-Reg $adv 'LaunchTo' 1 -Label 'エクスプローラーを「PC」で開く' }
    if ($UI.ShowFileExtensions) { Set-Reg $adv 'HideFileExt' 0 -Label '拡張子を表示' }
    if ($UI.ShowHiddenFiles)    { Set-Reg $adv 'Hidden' 1 -Label '隠しファイルを表示' }
    if ($UI.CompactMode)        { Set-Reg $adv 'UseCompactMode' 1 -Label 'コンパクトビュー' }
    if ($UI.HideGallery) {
        Set-Reg 'HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}' 'System.IsPinnedToNameSpaceTree' 0 -Label 'ギャラリー非表示'
    }
}

function Invoke-MachineUI {
    # 管理者権限が必要なもの（マシン全体のポリシー）
    if ($UI.HideWidgets) {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0 -Label 'ウィジェット無効(ポリシー)'
    }
    if ($UI.DisableWebSearch) {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1 -Label 'スタート検索の Web 結果無効(ポリシー)'
    }
}

# ============================================================================
#  通常権限で起動された場合: ユーザー側の UI 設定 → 管理者側を起動して待つ → 結果をまとめて表示
# ============================================================================
if (-not $script:IsAdmin) {
    if (-not $SkipUI) {
        Invoke-UserUI
        Restart-Explorer
    }

    # マシン全体の UI ポリシー / ソフト / システムが残っていれば管理者側を起動
    if (-not ($SkipUI -and $SkipApps -and $SkipSystem)) {
        Write-Section '管理者権限で残りの処理を実行します（UAC で「はい」を選んでください）'
        $resultFile = Join-Path (Get-UncPath $logDir) ("result_{0:yyyyMMdd_HHmmss}.json" -f (Get-Date))
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Get-UncPath $PSCommandPath)`"",
                     '-Elevated', '-NoPause', '-ResultPath', "`"$resultFile`"")
        foreach ($k in 'SkipApps', 'SkipUI', 'SkipSystem') {
            if ($PSBoundParameters.ContainsKey($k)) { $argList += "-$k" }
        }
        try {
            Start-Process powershell.exe -Verb RunAs -ArgumentList $argList -Wait
            if (Test-Path $resultFile) {
                $r = Get-Content $resultFile -Raw -Encoding UTF8 | ConvertFrom-Json
                foreach ($x in @($r.Results)) { $script:Results.Add($x) }
                if ($r.RebootRequired) { $script:RebootRequired = $true }
                Remove-Item $resultFile -Force
            } else {
                Add-Result '管理者' '管理者側の処理' 'NG' '途中で終了しました（logs の *_admin.log を確認）'
            }
        } catch {
            Add-Result '管理者' '管理者権限への昇格' 'NG' "UAC が拒否されたか失敗しました: $($_.Exception.Message)"
        }
    }

    Show-Summary
    Stop-Transcript | Out-Null
    if (-not $NoPause) { Read-Host "`nEnter キーで終了" | Out-Null }
    exit
}

# ============================================================================
#  ここから管理者権限
# ============================================================================
# 昇格前にユーザー側の UI を済ませていない場合（管理者のコンソールから直接実行した場合）だけ HKCU を設定する
$doUserUI = (-not $SkipUI) -and (-not $Elevated)
if ($doUserUI) {
    # 別の管理者アカウントで実行している場合、HKCU はその管理者のものになるため止める
    try {
        $owner = Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" |
                 Select-Object -First 1 | Invoke-CimMethod -MethodName GetOwner
        if ($owner -and $owner.User -and ($owner.User -ne $env:USERNAME)) {
            Write-Warning "ログオン中のユーザー($($owner.User))と実行ユーザー($env:USERNAME)が異なります。"
            Write-Warning 'UI 設定は実行ユーザー側に適用されてしまうため、スキップします。'
            Write-Warning '→ ログオン中のユーザーで Setup.bat をダブルクリックすれば、UI 設定は昇格前にそのユーザーへ適用されます。'
            $doUserUI = $false
            Add-Result 'UI/設定' 'ユーザー側の UI 設定' 'SKIP' '実行ユーザー不一致'
        }
    } catch { }
}
if ($doUserUI)      { Invoke-UserUI }
if (-not $SkipUI)   { Invoke-MachineUI }

# ============================================================================
#  2. ソフトのインストール
# ============================================================================
if (-not $SkipApps) {
    Write-Section '2. ソフトのインストール (winget)'

    # winget の確認（新規 PC では App Installer が未登録のことがある）
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Write-Host '  winget が見つからないため App Installer の登録を試みます...'
        try {
            Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
            Start-Sleep -Seconds 5
        } catch { }
    }

    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Add-Result 'アプリ' 'winget' 'NG' 'Microsoft Store で「アプリ インストーラー」を更新してから再実行してください'
    } else {
        & winget.exe source update --disable-interactivity | Out-Null

        foreach ($app in $WingetApps | Where-Object { $_.Enabled }) {
            Write-Host ''
            Write-Host "  >> $($app.Name) [$($app.Id)]" -ForegroundColor White

            if (Test-WingetInstalled $app.Id) {
                Add-Result 'アプリ' $app.Name 'SKIP' 'インストール済み'
                continue
            }

            $wingetArgs = @('install', '--id', $app.Id, '--exact', '--source', 'winget',
                            '--accept-package-agreements', '--accept-source-agreements',
                            '--disable-interactivity')
            if ($app.Override) { $wingetArgs += @('--override', $app.Override) }
            else               { $wingetArgs += '--silent' }

            & winget.exe @wingetArgs
            $code = $LASTEXITCODE
            switch ($code) {
                0           { Add-Result 'アプリ' $app.Name 'OK' }
                -1978335189 { Add-Result 'アプリ' $app.Name 'SKIP' 'インストール済み(更新なし)' }     # 0x8A15002B
                -1978334967 { Add-Result 'アプリ' $app.Name 'OK' '再起動後に完了'; $script:RebootRequired = $true }  # 0x8A150109
                3010        { Add-Result 'アプリ' $app.Name 'OK' '要再起動'; $script:RebootRequired = $true }
                default     { Add-Result 'アプリ' $app.Name 'NG' ('winget exit 0x{0:X8}' -f $code) }
            }
        }
    }

    # ---- winget に無いソフト ----
    Write-Section '2-2. ソフトのインストール (installers フォルダ)'
    if (Test-Path $InstallerDir) {
        Get-ChildItem $InstallerDir -File | Unblock-File   # ダウンロードしたファイルのブロック解除
    }

    foreach ($app in $LocalApps | Where-Object { $_.Enabled }) {
        $file = $null
        if (Test-Path $InstallerDir) {
            $file = $app.Patterns | ForEach-Object { Get-ChildItem -Path $InstallerDir -Filter $_ -File } |
                    Sort-Object LastWriteTime -Descending | Select-Object -First 1
        }
        if (-not $file) {
            Add-Result 'アプリ' $app.Name 'WARN' "installers に無し → $($app.Info)"
            continue
        }

        try {
            $exePath = $null
            if ($file.Extension -eq '.zip') {
                if (-not (Test-Path $app.Dest)) { New-Item -ItemType Directory -Path $app.Dest -Force | Out-Null }
                Expand-ZipFile $file.FullName $app.Dest
                $exePath = Get-ChildItem -Path $app.Dest -Recurse -Filter $app.Exe -File | Select-Object -First 1
                if (-not $exePath) {
                    $exePath = Get-ChildItem -Path $app.Dest -Recurse -Filter '*.exe' -File |
                               Where-Object { $_.Name -like "*$($app.Name)*" } | Select-Object -First 1
                }
                if ($exePath) {
                    $smDir = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Tools'
                    New-Shortcut (Join-Path $smDir "$($app.Name).lnk") $exePath.FullName
                    if ($app.Startup) {
                        # 別の管理者アカウントで昇格していても効くよう、全ユーザー共通のスタートアップに置く
                        New-Shortcut (Join-Path ([Environment]::GetFolderPath('CommonStartup')) "$($app.Name).lnk") $exePath.FullName
                    }
                    Add-Result 'アプリ' $app.Name 'OK' "$($exePath.FullName)"
                } else {
                    Add-Result 'アプリ' $app.Name 'WARN' "$($app.Dest) に展開したが $($app.Exe) が見つからない"
                }
            } else {
                Write-Host "  $($app.Name) のインストーラーを起動します。画面の指示に従ってください。" -ForegroundColor Yellow
                Start-Process -FilePath $file.FullName -Wait
                Add-Result 'アプリ' $app.Name 'OK' 'インストーラー実行'
            }
        } catch {
            Add-Result 'アプリ' $app.Name 'NG' $_.Exception.Message
        }
    }

    # ---- Python パッケージ ----
    $pyApp = $WingetApps | Where-Object { $_.Enabled -and $_.Id -like 'Python.Python.3.*' } | Select-Object -First 1
    if ($pyApp -and $PythonPackages.Count -gt 0) {
        Write-Section '2-3. Python パッケージ'
        Update-SessionPath
        $pyVer = $pyApp.Id -replace '^Python\.Python\.', ''                       # 例: 3.14
        $pyExe = Join-Path $env:ProgramFiles ("Python{0}\python.exe" -f ($pyVer -replace '\.', ''))
        $py = $null
        if (Test-Path $pyExe)                                          { $py = @($pyExe) }
        elseif (Get-Command py.exe -ErrorAction SilentlyContinue)      { $py = @('py.exe', "-$pyVer") }

        if (-not $py) {
            Add-Result 'Python' 'pip install' 'NG' 'python.exe が見つからない（再起動後に -SkipUI -SkipSystem で再実行）'
        } else {
            $pyCmd  = $py[0]
            $pyArgs = @($py | Select-Object -Skip 1)
            & $pyCmd @pyArgs -m pip install --upgrade pip --disable-pip-version-check
            & $pyCmd @pyArgs -m pip install --upgrade --disable-pip-version-check @PythonPackages
            if ($LASTEXITCODE -eq 0) { Add-Result 'Python' ($PythonPackages -join ', ') 'OK' }
            else                     { Add-Result 'Python' 'pip install' 'NG' "exit $LASTEXITCODE（プロキシ環境なら --proxy を指定）" }
        }
    }
}

# ============================================================================
#  3. システム設定
# ============================================================================
if (-not $SkipSystem) {
    Write-Section '3. Windows 機能・電源設定'

    $features = @()
    if ($Sys.EnableTelnetClient) { $features += @{ Name = 'TelnetClient'; Label = 'Telnet クライアント' } }
    if ($Sys.EnableTftpClient)   { $features += @{ Name = 'TFTP';         Label = 'TFTP クライアント' } }
    foreach ($f in $features) {
        try {
            $state = (Get-WindowsOptionalFeature -Online -FeatureName $f.Name).State
            if ($state -eq 'Enabled') {
                Add-Result 'システム' $f.Label 'SKIP' '有効化済み'
            } else {
                $r = Enable-WindowsOptionalFeature -Online -FeatureName $f.Name -All -NoRestart
                if ($r.RestartNeeded) { $script:RebootRequired = $true }
                Add-Result 'システム' $f.Label 'OK'
            }
        } catch {
            Add-Result 'システム' $f.Label 'NG' $_.Exception.Message
        }
    }

    if ($Sys.DisableFastStartup) {
        try {
            Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Value 0 -Type DWord
            Add-Result 'システム' '高速スタートアップ無効' 'OK'
        } catch { Add-Result 'システム' '高速スタートアップ無効' 'NG' $_.Exception.Message }
    }
    if ($Sys.NoSleepOnAC) {
        & powercfg.exe /change standby-timeout-ac 0
        if ($LASTEXITCODE -eq 0) { Add-Result 'システム' 'AC 電源時スリープなし' 'OK' }
        else                     { Add-Result 'システム' 'AC 電源時スリープなし' 'NG' "powercfg exit $LASTEXITCODE" }
    }
}

# ============================================================================
#  後処理
# ============================================================================
if ($doUserUI) { Restart-Explorer }

if ($ResultPath) {
    # 昇格前のプロセスに結果を渡す（結果の表はそちらでまとめて表示）
    # PS 5.1 では @(List) をそのまま渡すと "Argument types do not match" になるため ToArray() する
    $json = ConvertTo-Json -InputObject @{ Results = $script:Results.ToArray(); RebootRequired = $script:RebootRequired } -Depth 3
    [IO.File]::WriteAllText($ResultPath, $json, (New-Object Text.UTF8Encoding $false))
}

Show-Summary
Stop-Transcript | Out-Null
if (-not $NoPause) { Read-Host "`nEnter キーで終了" | Out-Null }
