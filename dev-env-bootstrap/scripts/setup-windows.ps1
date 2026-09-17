#requires -Version 5.1
<#
    dev-env-bootstrap · Windows 环境初始化

    安装：Node.js (LTS)、Rust (stable)、Tauri CLI
    以及 Tauri 的 Windows 前置依赖：Microsoft C++ Build Tools、WebView2 Runtime。

    安装策略（每个组件，按优先级）：
      1. 已安装                -> 跳过
      2. installers/ 有本地安装包 -> 检查版本差距 -> 使用它静默安装
      3. 无本地安装包           -> 尝试 winget（可能因防火墙/无外网失败）
      4. 全部失败               -> 提示手动下载网址，放入 installers/ 后重跑

    说明：winget 在部分网络环境（防火墙/无外网）下不可用，因此优先使用手动下载的
    本地安装包；脚本会读取本地安装包版本并与最新版本对比，差距较大时推荐下载新版。
#>
param(
    # 本地安装包目录（手动下载后放入此处，文件名需匹配各工具的 Pattern）
    [string]$InstallersDir = (Join-Path $PSScriptRoot '..\installers')
)

$ErrorActionPreference = 'Continue'
$script:hadError = $false

# ---------- 输出辅助 ----------
function Write-Info { Write-Host '[setup] ' -NoNewline -ForegroundColor Cyan;   Write-Host $args }
function Write-Ok   { Write-Host '[OK]    ' -NoNewline -ForegroundColor Green;  Write-Host $args }
function Write-Warn { Write-Host '[warn]  ' -NoNewline -ForegroundColor Yellow; Write-Host $args }
function Write-Err  { Write-Host '[error] ' -NoNewline -ForegroundColor Red;    Write-Host $args }

# ---------- 基础工具 ----------
function Has-Command {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

# 从注册表刷新当前会话 PATH（安装完成后新命令才能被找到）
function Refresh-Path {
    $machine = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
}

# 读取本地安装包的文件版本（读不到返回 $null）
function Get-FileVersion {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        $vi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
        if (-not [string]::IsNullOrWhiteSpace($vi.FileVersion)) {
            try { return [version]($vi.FileVersion -replace '^v') } catch { return $null }
        }
    } catch { }
    return $null
}

# 在 installers 目录下按文件名模式查找安装包
function Find-Installer {
    param([string]$Pattern)
    if (-not (Test-Path $InstallersDir)) { return $null }
    Get-ChildItem -Path $InstallersDir -Filter $Pattern -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
}

# 版本差距是否较大：大版本落后，或同大版本下小版本落后 >= 2
function Test-VersionGapLarge {
    param([version]$Local, [version]$Latest)
    if ($Local.Major -lt $Latest.Major) { return $true }
    if ($Local.Major -eq $Latest.Major -and $Local.Minor -le ($Latest.Minor - 2)) { return $true }
    return $false
}

# ---------- 已安装检测（C++ Build Tools / WebView2 用注册表与 vswhere） ----------
function Test-VsBuildTools {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $vswhere) {
        $hits = & $vswhere -products * -requires Microsoft.VisualStudio.Workload.VCTools -property installationPath 2>$null
        return [bool]($hits | Where-Object { $_ })
    }
    return $false
}

function Test-WebView2 {
    $keys = @(
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
        'HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
    )
    foreach ($k in $keys) {
        $item = Get-ItemProperty -Path $k -ErrorAction SilentlyContinue
        if ($item -and $item.pv) { return $true }
    }
    return $false
}

# ---------- 获取最新版本（best effort，无外网时返回 $null） ----------
function Get-LatestNodeVersion {
    $data = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json' -TimeoutSec 15 -ErrorAction Stop
    $lts = @($data | Where-Object { $_.lts })
    if ($lts.Count -eq 0) { return $null }
    return [version]($lts[0].version -replace '^v')
}

function Get-LatestRustupVersion {
    $resp = Invoke-WebRequest -Uri 'https://static.rust-lang.org/rustup/release-stable.toml' -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
    if ($resp.Content -match '(?m)^version\s*=\s*"([^"]+)"') {
        return [version]$matches[1]
    }
    return $null
}

function Get-LatestWebView2Version {
    $data = Invoke-RestMethod -Uri 'https://edgeupdates.microsoft.com/api/products?view=enterprise' -TimeoutSec 15 -ErrorAction Stop
    $wv = @($data | Where-Object { $_.Product -eq 'Microsoft Edge WebView2 Runtime' })
    if ($wv.Count -gt 0 -and $wv[0].Releases.Count -gt 0) {
        $v = $wv[0].Releases[0].ProductVersion
        if ($v) { return [version]$v }
    }
    return $null
}

# ---------- 通用安装流程 ----------
function Install-Tool {
    param(
        [string]$Name,
        [scriptblock]$InstalledCheck,
        [scriptblock]$VersionText,
        [string]$Pattern,
        [string]$DownloadUrl,
        [string]$WingetId,
        [scriptblock]$GetLatestVersion,
        [scriptblock]$InstallFromFile
    )
    Write-Info "----- $Name -----"

    # 1) 已安装 -> 跳过
    if (& $InstalledCheck) {
        try { Write-Ok "已安装: $(& $VersionText)" } catch { Write-Ok '已安装' }
        return
    }

    # 2) 本地安装包
    $file = Find-Installer -Pattern $Pattern
    if ($file) {
        $localVer  = Get-FileVersion $file.FullName
        $latestVer = $null
        if ($GetLatestVersion) {
            try { $latestVer = & $GetLatestVersion } catch { $latestVer = $null }
        }

        if ($localVer) { Write-Info "本地安装包版本: $localVer  ($($file.Name))" }
        else           { Write-Info "本地安装包: $($file.Name)（无法读取版本信息）" }
        if ($latestVer) {
            Write-Info "最新版本: $latestVer"
        } else {
            Write-Warn '未能获取最新版本（可能无外网），将直接使用本地安装包'
            $age = (Get-Date) - $file.LastWriteTime
            if ($age.Days -gt 120) {
                Write-Warn "该安装包下载于 $($file.LastWriteTime.ToString('yyyy-MM-dd'))，时间较早，可能不是最新版本"
            }
        }

        # 版本差距较大 -> 推荐下载新版
        if ($localVer -and $latestVer -and (Test-VersionGapLarge -Local $localVer -Latest $latestVer)) {
            Write-Warn "本地版本 ($localVer) 与最新 ($latestVer) 差距较大，推荐下载新版："
            Write-Host "  $DownloadUrl" -ForegroundColor Yellow
            $answer = Read-Host '仍使用旧版本安装? (Y/n)'
            if ($answer -match '^[nN]') {
                Write-Info "已跳过 $Name。请下载新版安装包放入 $InstallersDir 后重新运行。"
                return
            }
        }

        # 使用本地安装包静默安装
        try {
            & $InstallFromFile $file
            if (& $InstalledCheck) {
                try { Write-Ok "安装成功: $(& $VersionText)" } catch { Write-Ok "$Name 安装成功" }
            } else {
                Write-Warn '安装程序执行完毕，但当前会话未检测到该组件，请新开一个终端后再验证。'
            }
        } catch {
            $script:hadError = $true
            Write-Err "安装失败: $($_.Exception.Message)"
            Write-Err '本地安装包可能已损坏、被拦截或与系统不兼容。请删除后重新下载：'
            Write-Host "  $DownloadUrl" -ForegroundColor Red
        }
        return
    }

    # 3) 无本地安装包 -> 尝试 winget
    if ($WingetId -and (Has-Command 'winget')) {
        Write-Info "未找到本地安装包，尝试 winget 安装 ($WingetId) ..."
        winget install --id $WingetId --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Refresh-Path
            if (& $InstalledCheck) {
                try { Write-Ok "winget 安装成功: $(& $VersionText)" } catch { Write-Ok "$Name 安装成功" }
                return
            }
        }
        Write-Warn "winget 安装失败（退出码 $LASTEXITCODE，常见原因是防火墙/无外网）。"
    }

    # 4) 提示手动下载
    $script:hadError = $true
    Write-Err "未能自动安装 $Name，需要手动处理："
    Write-Err "请下载安装包（文件名需匹配 $Pattern）并放入目录：$InstallersDir"
    Write-Host "  $DownloadUrl" -ForegroundColor Red
    Write-Err '完成后重新运行本脚本即可自动安装。'
}

# ---------- Tauri CLI（npm 全局安装，无本地安装包/winget 方案） ----------
function Install-TauriCli {
    Write-Info '----- Tauri CLI -----'
    if (Has-Command 'tauri') {
        Write-Ok "已安装: $(tauri --version)"
        return
    }
    if (-not (Has-Command 'npm')) {
        $script:hadError = $true
        Write-Err '未检测到 npm，请先完成 Node.js 安装后重试。'
        return
    }
    Write-Info '通过 npm 全局安装 @tauri-apps/cli ...'
    npm install -g @tauri-apps/cli 2>&1 | Out-Host
    Refresh-Path
    if (Has-Command 'tauri') {
        Write-Ok "Tauri CLI 安装成功: $(tauri --version)"
    } else {
        $script:hadError = $true
        Write-Err 'Tauri CLI 安装失败，请手动执行: npm install -g @tauri-apps/cli'
    }
}

# ---------- 组件配置 ----------
$tools = @(
    @{
        Name              = 'Node.js (LTS)'
        InstalledCheck    = { Has-Command 'node' }
        VersionText       = { node --version }
        Pattern           = 'node-*.msi'
        DownloadUrl       = 'https://nodejs.org/dist/latest-v24.x/'
        WingetId          = 'OpenJS.NodeJS.LTS'
        GetLatestVersion  = { Get-LatestNodeVersion }
        InstallFromFile   = {
            param($file)
            Write-Info '静默安装 Node.js LTS（msiexec /qn）...'
            $args = @('/i', "`"$($file.FullName)`"", '/qn', '/norestart')
            $p = Start-Process msiexec.exe -ArgumentList $args -Wait -PassThru
            if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) { throw "msiexec 退出码 $($p.ExitCode)" }
            Refresh-Path
        }
    },
    @{
        Name              = 'Rust (stable)'
        InstalledCheck    = { Has-Command 'rustc' }
        VersionText       = { rustc --version }
        Pattern           = 'rustup-init*.exe'
        DownloadUrl       = 'https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe'
        WingetId          = 'Rustlang.Rustup'
        GetLatestVersion  = { Get-LatestRustupVersion }
        InstallFromFile   = {
            param($file)
            Write-Info '通过 rustup-init 静默安装 stable 工具链...'
            $p = Start-Process -FilePath $file.FullName -ArgumentList '-y', '--default-toolchain', 'stable', '--profile', 'minimal' -Wait -PassThru -NoNewWindow
            if ($p.ExitCode -ne 0) { throw "rustup-init 退出码 $($p.ExitCode)" }
            Refresh-Path
            $cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
            if ($env:Path -notlike "*$cargoBin*") { $env:Path = "$cargoBin;$env:Path" }
        }
    },
    @{
        Name              = 'Microsoft C++ Build Tools'
        InstalledCheck    = { Test-VsBuildTools }
        VersionText       = { 'C++ Build Tools (MSVC) 已就绪' }
        Pattern           = 'vs_BuildTools*.exe'
        DownloadUrl       = 'https://aka.ms/vs/17/release/vs_BuildTools.exe'
        WingetId          = 'Microsoft.VisualStudio.2022.BuildTools'
        GetLatestVersion  = $null
        InstallFromFile   = {
            param($file)
            Write-Info '静默安装 VS Build Tools（含 MSVC + Windows SDK），可能需要数分钟...'
            $vargs = @('--quiet', '--wait', '--norestart', '--nocache', '--add', 'Microsoft.VisualStudio.Workload.VCTools', '--includeRecommended')
            $p = Start-Process -FilePath $file.FullName -ArgumentList $vargs -Wait -PassThru -NoNewWindow
            if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) { throw "vs_BuildTools 退出码 $($p.ExitCode)" }
        }
    },
    @{
        Name              = 'WebView2 Runtime'
        InstalledCheck    = { Test-WebView2 }
        VersionText       = { 'WebView2 Runtime (Evergreen) 已就绪' }
        Pattern           = 'MicrosoftEdgeWebView2*.exe'
        DownloadUrl       = 'https://go.microsoft.com/fwlink/p/?LinkId=2124703'
        WingetId          = 'Microsoft.EdgeWebView2Runtime'
        GetLatestVersion  = { Get-LatestWebView2Version }
        InstallFromFile   = {
            param($file)
            Write-Info '静默安装 WebView2 Evergreen Runtime...'
            $p = Start-Process -FilePath $file.FullName -ArgumentList '/silent', '/install' -Wait -PassThru -NoNewWindow
            if ($p.ExitCode -ne 0) { throw "WebView2 安装程序退出码 $($p.ExitCode)" }
        }
    }
)

# ---------- 主流程 ----------
Write-Host '===== dev-env-bootstrap · Windows =====' -ForegroundColor Cyan

# 确保 installers 目录存在并给出提示
if (-not (Test-Path $InstallersDir)) {
    New-Item -ItemType Directory -Path $InstallersDir -Force | Out-Null
}
Write-Info "本地安装包目录: $InstallersDir（可手动下载放入，文件名模式见 installers/README.md）"

foreach ($tool in $tools) {
    Install-Tool @tool
}

Install-TauriCli

Write-Host ''
Write-Host '===== 环境配置完成 =====' -ForegroundColor Cyan
if (Has-Command 'node')  { Write-Ok "Node.js : $(node --version)" }      else { Write-Err 'Node.js : 未安装' }
if (Has-Command 'rustc') { Write-Ok "Rust    : $(rustc --version)" }     else { Write-Err 'Rust    : 未安装' }
if (Has-Command 'tauri') { Write-Ok "Tauri   : $(tauri --version)" }     else { Write-Err 'Tauri   : 未安装' }
$vsText  = $(if (Test-VsBuildTools) { '已安装' } else { '未安装' })
$wvText  = $(if (Test-WebView2)     { '已安装' } else { '未安装' })
Write-Ok "C++ Build Tools : $vsText"
Write-Ok "WebView2 Runtime: $wvText"

if ($script:hadError) {
    Write-Warn '部分组件未安装成功，请根据上方提示手动处理。'
    exit 1
}
exit 0
