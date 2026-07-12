# 手机端线上部署指南

> 目标：用手机浏览器打开链接就能玩（无需安装 App）。  
> 备选：导出 Android APK 侧载安装。

---

## 方案对比

| 方案 | 难度 | 手机体验 | 推荐 |
|------|------|----------|------|
| **Web（浏览器）** | ★☆☆ | 打开链接即玩，支持触摸摇杆 | ✅ 首选 |
| **itch.io 托管** | ★☆☆ | 同上，上传 ZIP 即可 | ✅ 最快上线 |
| **GitHub Pages** | ★★☆ | 推送代码自动部署 | 有 GitHub 时用 |
| **Android APK** | ★★★ | 原生 App，需签名/SDK | 想装桌面图标时 |

游戏已内置移动端输入：左下虚拟摇杆移动、右下冲刺按钮。

---

## 第一步：本机导出 Web 包

### 1. 安装 Godot 4.6+

- 下载：[godotengine.org/download](https://godotengine.org/download)
- 打开本项目后：**编辑器 → 管理导出模板 → 下载并安装**（选 4.6）

### 2. 导出

**方式 A — 编辑器（推荐首次）**

1. **项目 → 导出**
2. 选择预设 **「Web Mobile」**
3. 导出到 `build/web/index.html`

**方式 B — 命令行**

```powershell
# 设置 Godot 路径（按你本机实际路径改）
$env:GODOT_EXE = "D:\Godot\Godot_v4.6-stable_win64.exe"
.\tools\export_web.ps1
```

导出成功后，`build/web/` 内会有 `index.html`、`.wasm`、`.pck` 等文件。

### 3. 本机预览

```powershell
npx serve build/web
```

同一 WiFi 下手机访问 `http://你的电脑IP:3000` 试玩。

---

## 第二步：部署到线上

### 选项 A — itch.io（最快，约 5 分钟）

1. 注册 [itch.io](https://itch.io) 账号
2. **Create new project** → 选 **HTML**
3. 把 `build/web/` **文件夹内所有文件**打成 ZIP 上传
4. 勾选 **This file will be played in the browser**
5. 发布后将链接发到手机打开

适合个人试玩、分享给朋友。

### 选项 B — GitHub Pages（自动部署）

1. 在 GitHub 新建仓库，推送本项目：

```powershell
git remote add origin https://github.com/你的用户名/shell-survivor.git
git branch -M main
git push -u origin main
```

2. 仓库 **Settings → Pages**：
   - Source 选 **GitHub Actions**
3. 推送后 `.github/workflows/deploy-web.yml` 会自动构建并发布
4. 访问：`https://你的用户名.github.io/shell-survivor/`

> 首次构建约 3–8 分钟；包体较大时手机首次加载需等待 10–30 秒。

### 选项 C — Cloudflare Pages / Netlify

1. 注册 Cloudflare Pages 或 Netlify
2. 连接 GitHub 仓库，或手动上传 `build/web/` 文件夹
3. 构建命令留空，发布目录填 `build/web`（若用 CI 先导出再上传）

---

## 第三步（可选）：Android APK

1. Godot 安装 **Android 导出模板**
2. 安装 **JDK 17** + **Android SDK**（Godot 编辑器 → 编辑器设置 → 导出 → Android 可一键引导）
3. **项目 → 导出 → Android** → 导出 `build/android/ShellSurvivor.apk`
4. 手机开启「允许安装未知来源」，传输 APK 安装

APK 适合想「像 App 一样」从桌面启动；维护成本高于 Web。

---

## 手机端体验建议

- **横屏**游玩（项目已配置 `sensor_landscape`）
- 首次加载较慢属正常（WASM + 资源包）
- 卡顿可在游戏设置里降低画质 / 关闭粒子
- iOS Safari：添加到主屏幕后可全屏玩（PWA 已开启）

---

## 常见问题

**Q: 导出时报「找不到模板」**  
A: 编辑器 → 管理导出模板 → 安装与编辑器同版本的模板。

**Q: 手机打开白屏**  
A: 确认托管平台支持 `.wasm` MIME；GitHub Pages / itch.io 均支持。

**Q: 包太大加载慢**  
A: Web 预设已排除 `assets/vendor/` 等大目录；KayKit 3D 默认关闭，不影响 2D 游玩。

**Q: 没有 GitHub 远程仓库**  
A: 优先用 **itch.io** 上传 ZIP，无需 Git。

---

## 相关文件

- `export_presets.cfg` — Web / Android 导出预设
- `deploy/custom_shell.html` — 手机全屏 HTML 外壳
- `tools/export_web.ps1` — 本机一键导出脚本
- `.github/workflows/deploy-web.yml` — GitHub Pages 自动部署
