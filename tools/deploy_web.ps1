# 上传 Web 导出包到自有服务器（域名 sbhigakf215dadjwahi.xyz）
#
# 用法：
#   .\tools\deploy_web.ps1 -Host user@你的服务器IP -RemoteDir /var/www/shell-survivor
#
# 前提：
#   1) 已运行 .\tools\export_web.ps1 生成 build/web/
#   2) 本机可 SSH 到服务器（建议配置密钥登录）
#   3) 服务器已按 deploy/nginx-shell-survivor.conf 配置站点

param(
    [Parameter(Mandatory = $true)]
    [string]$Host,
    [string]$RemoteDir = "/var/www/shell-survivor",
    [string]$LocalDir = "",
    [int]$Port = 22
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($LocalDir)) {
    $LocalDir = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "build\web"
}

if (-not (Test-Path (Join-Path $LocalDir "index.html"))) {
    Write-Error "未找到 $LocalDir\index.html，请先运行 .\tools\export_web.ps1"
}

Write-Host "本地: $LocalDir"
Write-Host "目标: ${Host}:${RemoteDir}"

# 创建远程目录
ssh -p $Port $Host "mkdir -p '$RemoteDir'"

# 同步（需要本机安装 rsync；Git for Windows / WSL 通常自带）
$rsync = Get-Command rsync -ErrorAction SilentlyContinue
if ($rsync) {
    $localUnix = ($LocalDir -replace '\\', '/') + "/"
    rsync -avz --delete -e "ssh -p $Port" $localUnix "${Host}:${RemoteDir}/"
} else {
    Write-Warning "未找到 rsync，改用 scp 上传（较慢）"
    scp -P $Port -r "$LocalDir\*" "${Host}:${RemoteDir}/"
}

Write-Host ""
Write-Host "上传完成。"
Write-Host "若使用子域名 game.sbhigakf215dadjwahi.xyz，请在 DNS 添加 A 记录指向服务器 IP。"
Write-Host "然后：sudo nginx -t && sudo systemctl reload nginx"
