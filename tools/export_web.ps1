# 导出 Web 版（手机浏览器可玩）
# 用法：
#   .\tools\export_web.ps1
#   .\tools\export_web.ps1 -GodotExe "D:\Godot\Godot_v4.6-stable_win64.exe"

param(
    [string]$GodotExe = $env:GODOT_EXE,
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$PresetName = "Web Mobile"
)

function Find-GodotExe {
    param([string]$Hint)
    if ($Hint -and (Test-Path $Hint)) { return (Resolve-Path $Hint).Path }
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Godot\Godot*.exe",
        "C:\Program Files\Godot\Godot*.exe",
        "$env:USERPROFILE\Downloads\Godot*.exe",
        "$env:USERPROFILE\scoop\shims\godot.exe"
    )
    foreach ($pattern in $candidates) {
        $hit = Get-Item $pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

$godot = Find-GodotExe -Hint $GodotExe
if (-not $godot) {
    Write-Error @"
未找到 Godot 可执行文件。
请先安装 Godot 4.6+，并在编辑器中下载 Web 导出模板：
  编辑器 → 管理导出模板 → 下载并安装
然后任选其一：
  1) 设置环境变量 GODOT_EXE 指向 Godot.exe
  2) 运行： .\tools\export_web.ps1 -GodotExe '你的Godot路径'
  3) 在 Godot 编辑器：项目 → 导出 → 选 Web Mobile → 导出项目
"@
    exit 1
}

$buildDir = Join-Path $ProjectPath "build\web"
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

Write-Host "Godot: $godot"
Write-Host "Project: $ProjectPath"
Write-Host "Preset: $PresetName"

& $godot --headless --path $ProjectPath --export-release $PresetName (Join-Path $buildDir "index.html")
if ($LASTEXITCODE -ne 0) {
    Write-Error "Web 导出失败。请确认已在 Godot 编辑器安装 Web 导出模板。"
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "导出完成: $buildDir"
Write-Host "本地预览: 用任意静态服务器打开 build/web/index.html"
Write-Host "  npx serve build/web"
Write-Host "手机访问: 部署到 GitHub Pages / itch.io / Cloudflare Pages 后用浏览器打开链接"
