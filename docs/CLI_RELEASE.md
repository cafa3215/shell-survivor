# 肉鸽 CLI 发版约定

Web 产物在 `build/web/`（**不进 Git**）。Git Deploy Hook 只能重部仓库树，**不能**替代本机导出。

## 前置

1. Godot 4.6+（本机默认：`E:\Desktop\Godot_v4.6.2-stable_win64.exe`）
2. Editor → Manage Export Templates → 安装与引擎版本匹配的 **Web** 模板
3. 导出预设名：`Web Mobile`（见 `export_presets.cfg`）

可选环境变量：

```powershell
$env:GODOT_EXE = "E:\Desktop\Godot_v4.6.2-stable_win64.exe"
```

## 一键发版（推荐）

在工作区根目录：

```powershell
.\release.ps1 -Project game -Version 2.4.0 -Notes "更新说明"
```

等价步骤：

1. `.\tools\export_web.ps1`（或由 release.ps1 自动调用）
2. `node portfolio\scripts\publish-release.mjs 肉鸽 <版本> "<说明>"`
3. 在 `肉鸽` 目录 `vercel deploy --prod`
4. CMS「立即检测」→ 确认部署（校验线上 `releases/latest.json`）

## 仅本地试玩

```powershell
.\tools\run_local_web.ps1
```
