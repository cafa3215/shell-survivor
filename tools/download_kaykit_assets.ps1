# 下载 KayKit CC0 资产到 assets/vendor/kaykit/（与 GitHub 官方镜像一致）
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Vendor = Join-Path $Root "assets\vendor\kaykit"
$Tmp = Join-Path $Root ".vendor\kaykit-dl"
New-Item -ItemType Directory -Force -Path $Vendor, $Tmp | Out-Null

$repos = @(
    @{ Name = "adventurers"; Url = "https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventurers-1.0/archive/refs/heads/main.zip" },
    @{ Name = "skeletons"; Url = "https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0/archive/refs/heads/main.zip" }
)

foreach ($r in $repos) {
    $zip = Join-Path $Tmp ($r.Name + ".zip")
    Write-Host "Downloading $($r.Name)..."
    curl.exe -L $r.Url -o $zip
    if ((Get-Item $zip).Length -lt 10000) {
        Write-Error "Download failed (zip too small): $($r.Url)"
    }
    Expand-Archive -Path $zip -DestinationPath $Tmp -Force
    $extracted = Get-ChildItem $Tmp -Directory | Where-Object { $_.Name -like "*$($r.Name)*" -or $_.Name -like "*Adventurers*" -or $_.Name -like "*Skeletons*" } | Select-Object -First 1
    if ($r.Name -eq "adventurers") {
        $src = Get-ChildItem $Tmp -Recurse -Directory | Where-Object { $_.Name -eq "KayKit Character Pack - Adventurers" -or $_.FullName -match "Adventurers.*Characters" } | Select-Object -First 1
        if (-not $src) { $src = Get-ChildItem (Join-Path $Tmp "*Adventurers*") -Directory | Select-Object -First 1 }
        $dest = Join-Path $Vendor "adventurers"
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        # 标准 zip 根目录含 Characters + Assets
        $root = Get-ChildItem $Tmp -Directory | Where-Object { $_.Name -match "Adventurers" } | Select-Object -First 1
        if ($root) {
            Copy-Item -Path $root.FullName -Destination $dest -Recurse -Force
        }
    } else {
        $root = Get-ChildItem $Tmp -Directory | Where-Object { $_.Name -match "Skeletons" } | Select-Object -First 1
        $dest = Join-Path $Vendor "skeletons"
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        if ($root) {
            Copy-Item -Path $root.FullName -Destination $dest -Recurse -Force
        }
    }
}

Write-Host "Done. Run: godot --headless --script res://tools/install_kaykit_assets.gd"
