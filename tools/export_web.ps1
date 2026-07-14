# Export Web build (playable in mobile browsers)
# Usage:
#   .\tools\export_web.ps1
#   .\tools\export_web.ps1 -GodotExe "D:\Godot\Godot_v4.6-stable_win64.exe"

param(
    [string]$GodotExe = $env:GODOT_EXE,
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$PresetName = "Web Mobile"
)

# Godot 往 stderr 打日志；父级若为 Stop 会中断导出
$ErrorActionPreference = "Continue"

function Find-GodotExe {
    param([string]$Hint)
    if ($Hint -and (Test-Path $Hint)) { return (Resolve-Path $Hint).Path }
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Godot\Godot*.exe",
        "C:\Program Files\Godot\Godot*.exe",
        "$env:USERPROFILE\Downloads\Godot*.exe",
        "$env:USERPROFILE\scoop\shims\godot.exe",
        "E:\Desktop\Godot_v4.6.2-stable_win64.exe",
        "E:\Desktop\Godot*.exe"
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
Godot executable not found.
Install Godot 4.6+ and download the Web export templates in the editor.
Then either:
  1) Set GODOT_EXE to your Godot.exe path
  2) Run: .\tools\export_web.ps1 -GodotExe 'C:\path\to\Godot.exe'
  3) In Godot: Project -> Export -> Web Mobile -> Export Project
"@
    exit 1
}

$buildDir = Join-Path $ProjectPath "build\web"
$gameDir = Join-Path $buildDir "game"
$outHtml = Join-Path $gameDir "index.html"
New-Item -ItemType Directory -Force -Path $gameDir | Out-Null

$buildStamp = Get-Date -Format "yyyyMMdd-HHmmss"
$gameDbPath = Join-Path $ProjectPath "scripts\autoload\GameDB.gd"
if (Test-Path $gameDbPath) {
    $gdbRaw = Get-Content $gameDbPath -Raw -Encoding UTF8
    $gdbNew = [regex]::Replace($gdbRaw, 'const WEB_BUILD_STAMP := "[^"]*"', "const WEB_BUILD_STAMP := `"$buildStamp`"")
    if ($gdbNew -ne $gdbRaw) {
        Set-Content -Path $gameDbPath -Value $gdbNew -Encoding UTF8 -NoNewline
        Write-Host "Build stamp: $buildStamp"
    }
}

Write-Host "Godot: $godot"
Write-Host "Project: $ProjectPath"
Write-Host "Preset: $PresetName"
Write-Host "Output: $outHtml"

$emitScript = Join-Path $ProjectPath "tools\emit_weapon_projectile_pngs.gd"
if (Test-Path $emitScript) {
    Write-Host "Generating internal projectile PNGs..."
    & $godot --headless --path $ProjectPath -s "res://tools/emit_weapon_projectile_pngs.gd" 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Projectile PNG generation returned exit code $LASTEXITCODE (continuing export)."
    }
}

# 清掉旧 index，避免误给旧文件盖戳后又被 Godot 用未替换占位符的外壳覆盖
Remove-Item -Force -ErrorAction SilentlyContinue $outHtml
# 用 call operator，避免 Start-Process 把「Web Mobile」拆成两个参数
Write-Host "Exporting preset '$PresetName'..."
& $godot --headless --path $ProjectPath --export-release $PresetName $outHtml 2>&1 | Out-Host
$exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }

$exportOk = (Test-Path $outHtml) -and ((Get-Item $outHtml).Length -gt 0)
if (-not $exportOk) {
    Write-Error "Web export failed. Install Web export templates in Godot first. Exit code: $exitCode"
    exit $(if ($exitCode -ne 0) { $exitCode } else { 1 })
}

if ($exitCode -ne 0) {
    Write-Warning "Godot exited with code $exitCode, but $outHtml was produced. Continuing."
}

$htmlPath = $outHtml
if (Test-Path $htmlPath) {
    $html = [System.IO.File]::ReadAllText($htmlPath)
    $stampDiv = "<div id=`"ss-build-stamp`" style=`"position:fixed;left:8px;bottom:8px;z-index:99999;font:11px/1.3 system-ui,sans-serif;color:rgba(150,190,255,0.92);pointer-events:none;text-shadow:0 1px 4px rgba(0,0,0,0.85);`">build $buildStamp</div>"
    if ($html.Contains('__SS_BUILD_STAMP__')) {
        $html = $html.Replace('__SS_BUILD_STAMP__', $buildStamp)
    } elseif ($html.Contains('id="ss-build-stamp"')) {
        $html = [regex]::Replace($html, '<div id="ss-build-stamp"[^>]*>[^<]*</div>', $stampDiv)
    } elseif ($html.Contains('</body>')) {
        $html = $html.Replace('</body>', "$stampDiv`r`n</body>")
    }
    [System.IO.File]::WriteAllText($htmlPath, $html, [System.Text.UTF8Encoding]::new($false))
    $verify = [System.IO.File]::ReadAllText($htmlPath)
    if ($verify.Contains('__SS_BUILD_STAMP__')) {
        Write-Error "Build stamp placeholder still present in $htmlPath after replace."
        exit 1
    }
    Write-Host "HTML stamp applied: build $buildStamp"
}
$serveCfg = Join-Path $gameDir "serve.json"
$serveJson = @'
{
  "headers": [
    {
      "source": "**/*",
      "headers": [
        { "key": "Cache-Control", "value": "no-store, no-cache, must-revalidate, max-age=0" },
        { "key": "Pragma", "value": "no-cache" }
      ]
    }
  ]
}
'@
[System.IO.File]::WriteAllText($serveCfg, $serveJson, [System.Text.UTF8Encoding]::new($false))
Write-Host ""
Write-Host "Done: $gameDir"
Write-Host "Build stamp: $buildStamp  (see bottom-left in browser + in-game HUD)"
Write-Host "Deploy this folder to your portfolio /game/ route."
