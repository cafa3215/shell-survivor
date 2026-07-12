# KayKit Game Assets (CC0)

来源（GitHub 镜像，与 itch.io 免费包一致）：

- [KayKit Character Pack Adventures 1.0](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0)
- [KayKit Character Pack Skeletons 1.0](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0)

许可：**CC0** — 可商用，无需署名（建议保留本 README）。

## 目录

| 路径 | 内容 |
|------|------|
| `adventurers/Characters/gltf/` | 5 角色 GLB（含动画） |
| `adventurers/Assets/gltf/` | 武器/盾牌配件 GLTF |
| `skeletons/Characters/gltf/` | 4 骷髅敌人 GLB |

游戏内引用见 `scripts/autoload/KayKitAssets.gd` 与 `assets/game_pack/models/`。

## 一键安装

```powershell
# 1) 若 vendor 为空，先下载（约 50MB）
powershell -ExecutionPolicy Bypass -File tools/download_kaykit_assets.ps1

# 2) 同步到 game_pack + Godot 导入
godot --headless --script res://tools/install_kaykit_assets.gd

# 3) 校验
godot --headless --script res://tools/validate_kaykit_load.gd
```

## 游戏内集成

- **Autoload**：`KayKitAssets`（`project.godot` 已注册）
- **主角渲染**：`PlayerVisual3D`（SubViewport 3D → 2D），`Settings.use_kaykit_visual=true` 时 `Player` 自动启用
- **设置**：`Settings.use_kaykit_visual`（暂停菜单可关，回退 2D 骨架/立绘）
- **武器手持**：KayKit 配件 GLTF 挂 `handslot_r`（见 `KayKitAssets.WEAPON_ACCESSORY`）

重新安装：在项目根运行 Godot

```
godot --headless --script res://tools/install_kaykit_assets.gd
godot --headless --import
```
