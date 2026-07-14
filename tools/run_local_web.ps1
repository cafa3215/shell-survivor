# Local Web preview: export + static server
# Usage: .\tools\run_local_web.ps1

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $root

if (-not $env:GODOT_EXE) {
    $env:GODOT_EXE = "E:\Desktop\Godot_v4.6.2-stable_win64.exe"
}

Write-Host "==> Export Web build..."
& (Join-Path $PSScriptRoot "export_web.ps1") -GodotExe $env:GODOT_EXE
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Re-apply build stamp if Godot overwrote index.html after export
$gameDir = Join-Path $root "build\web\game"
$htmlPath = Join-Path $gameDir "index.html"
$gameDbPath = Join-Path $root "scripts\autoload\GameDB.gd"
if ((Test-Path $htmlPath) -and (Test-Path $gameDbPath)) {
    $gdbText = [System.IO.File]::ReadAllText($gameDbPath)
    $m = [regex]::Match($gdbText, 'WEB_BUILD_STAMP := "([^"]+)"')
    if ($m.Success) {
        $stamp = $m.Groups[1].Value
        $html = [System.IO.File]::ReadAllText($htmlPath)
        if ($html.Contains("__SS_BUILD_STAMP__")) {
            $html = $html.Replace("__SS_BUILD_STAMP__", $stamp)
        } else {
            $pattern = '(<div id="ss-build-stamp"[^>]*>build )[^<]*(</div>)'
            $replacement = '${1}' + $stamp + '${2}'
            $html = [regex]::Replace($html, $pattern, $replacement)
        }
        [System.IO.File]::WriteAllText($htmlPath, $html, [System.Text.UTF8Encoding]::new($false))
        Write-Host "Build stamp confirmed: $stamp"
    }
}

$required = @("index.html", "index.js", "index.wasm", "index.pck")
foreach ($f in $required) {
    $p = Join-Path $gameDir $f
    if (-not (Test-Path $p)) {
        Write-Error "Missing build artifact: $p"
        exit 1
    }
}

Write-Host ""
Write-Host "==> Verify Godot scripts (headless boot)..."
& $env:GODOT_EXE --headless --path $root --quit-after 1 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Godot quit with code $LASTEXITCODE - check editor output for script errors."
}

Write-Host ""
Write-Host "==> Serve $gameDir on http://localhost:3000"
Write-Host "    Version check: main menu footer should show"
Write-Host "    version v2.2 - build YYYYMMDD-HHMMSS"
Write-Host "    If only v2.2 without build id: old bundle, re-run this script"
Write-Host "    Hard refresh browser: Ctrl+Shift+R"
Write-Host "    Stop server: Ctrl+C"

Push-Location $gameDir
try {
    if (Test-Path "serve.json") {
        npx --yes serve . -l 3000 -c serve.json
    } else {
        npx --yes serve . -l 3000
    }
} finally {
    Pop-Location
}
