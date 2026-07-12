# 一键部署「门户 + 游戏」到自有域名
#
# 目标结构（服务器 /var/www/portal/）：
#   /              门户选项目
#   /story/        OUR STORY（需你自行迁入，见 docs/CUSTOM_DOMAIN_DEPLOY.md）
#   /game/         Shell Survivor
#
# 用法：
#   .\tools\deploy_portal.ps1 -Host root@你的IP
#   .\tools\deploy_portal.ps1 -Host root@你的IP -SkipGame   # 只更新门户页

param(
    [Parameter(Mandatory = $true)]
    [string]$Host,
    [string]$RemoteRoot = "/var/www/portal",
    [string]$PortalDir = "",
    [string]$GameDir = "",
    [int]$Port = 22,
    [switch]$SkipGame
)

$ErrorActionPreference = "Stop"
$repo = Resolve-Path (Join-Path $PSScriptRoot "..")

if ([string]::IsNullOrWhiteSpace($PortalDir)) {
    $PortalDir = Join-Path $repo "deploy\portal"
}
if ([string]::IsNullOrWhiteSpace($GameDir)) {
    $GameDir = Join-Path $repo "build\web\game"
}

Write-Host "门户源: $PortalDir"
Write-Host "游戏源: $GameDir"
Write-Host "远程:   ${Host}:${RemoteRoot}"

ssh -p $Port $Host "mkdir -p '$RemoteRoot' '$RemoteRoot/game' '$RemoteRoot/story'"

function Sync-Dir {
    param(
        [string]$Local,
        [string]$RemotePath,
        [switch]$Delete
    )
    $rsync = Get-Command rsync -ErrorAction SilentlyContinue
    $localUnix = ($Local -replace '\\', '/') + "/"
    if ($rsync) {
        $args = @("-avz")
        if ($Delete) { $args += "--delete" }
        $args += "-e", "ssh -p $Port"
        $args += $localUnix, "${Host}:${RemotePath}/"
        & rsync @args
    } else {
        scp -P $Port -r "$Local\*" "${Host}:${RemotePath}/"
    }
}

Sync-Dir -Local $PortalDir -RemotePath $RemoteRoot

if (-not $SkipGame) {
    if (-not (Test-Path (Join-Path $GameDir "index.html"))) {
        Write-Error "未找到游戏导出包 $GameDir\index.html，请先运行 .\tools\export_web.ps1"
    }
    Sync-Dir -Local $GameDir -RemotePath "$RemoteRoot/game" -Delete
}

Write-Host ""
Write-Host "部署完成。"
Write-Host "  门户: https://www.sbhigakf215dadjwahi.xyz/"
Write-Host "  游戏: https://www.sbhigakf215dadjwahi.xyz/game/"
Write-Host "  回忆馆: https://www.sbhigakf215dadjwahi.xyz/story/  （需把 OUR STORY 迁到 story/ 目录）"
Write-Host "新增项目: 编辑 deploy/portal/projects.json 后重新运行本脚本（可加 -SkipGame）。"
