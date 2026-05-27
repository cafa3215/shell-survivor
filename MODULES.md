# 模块化开发与逐步合并（独立可运行）

本项目采用“单工程内模块化”的方式，把特效/音效/UI/原画/技能/动作/建模/骨骼/地编/程序拆成 **10 个可独立运行 Demo 场景**，先在模块内迭代，再逐步合并到主玩法。

## 目录结构

```
scenes/modules/
  vfx/VFXDemo.tscn
  sfx/SFXDemo.tscn
  ui/UIDemo.tscn
  art/ArtDemo.tscn
  skills/SkillsDemo.tscn
  animation/AnimationDemo.tscn
  modeling/ModelingDemo.tscn
  rigging/RiggingDemo.tscn
  level/LevelDemo.tscn
  programming/ProgrammingDemo.tscn

scripts/modules/
  ModuleDemoBase.gd
  ArtDemo.gd / ModelingDemo.gd / LevelDemo.gd / …（各 Demo 同名脚本）
```

## 独立开发者十维：本工程落点（分析 + 自检）

| 维度 | 当前工程落点 | 建议节奏（单人） |
|------|----------------|------------------|
| **程序** | `Main`/`Game`、`EventBus`、`MetaProgress`、门禁 `verify_project.py` | 先保合约与烟测，再扩系统；合并前必跑门禁。 |
| **技能** | `ActiveSkillManager`、`SkillSystem`、`SkillsDemo`（桩 + 多帧复检） | 桩与真 `Game` 易漂移；改技能必跑 `--full`。 |
| **动作** | `Player` 动画与 `AnimationDemo` | 与骨骼同一套 `apply_visual_state`，改接口要双测。 |
| **骨骼** | `PlayerBodyRig`、`RiggingDemo` | 骨命名自检在 `RiggingDemo.module_self_test`。 |
| **建模** | 二维切片与碰撞对齐；`ModelingDemo` 文案占位 + 门禁中文 | 新资源进局内场景肉眼看对齐。 |
| **原画** | 立绘/主题；`ArtDemo` + 中文门禁 | 定色板与剪影后再细画；合并前跑 `audit_ui_cn_strings`。 |
| **UI** | `UIDemo`、`cyber_theme`、`Main` 战备强化/遗物图鉴 | 主题变更同步扫 `theme_type_variation`。 |
| **音效** | `AudioManager`、`SFXDemo`、`EventBus.play_sfx` | 高频事件注意池化与音量曲线（按需迭代）。 |
| **特效** | `ParticleManager`、`Settings` 档位、`VFXDemo` | 高压场面与 HUD 可读性一起调。 |
| **地编** | `LevelDemo` 导航烘焙、`Game` 地图表 | `make_polygons_from_outlines` 已标记弃用迁移方向；主关卡若用瓦片地图需另补验证。 |

## 如何“独立运行”

- 在 Godot 编辑器中，把任意 `*Demo.tscn` 设为 Main Scene（或直接打开后 F6 运行当前场景）。

## 如何“逐步合并”

- **模块内开发**：只改动对应模块目录 + 必要的公共接口（autoload/核心系统）。
- **合并门禁**：每次合并前跑 `python verify_project.py`，它会依次执行：
  - `validate_load`：关键场景能加载
  - `validate_modules`：10 个模块 Demo 能加载并实例化
  - `validate_dimensions`：十维在 `Main_new` / `Game` 主链路关键节点与接口对齐
  - `validate_release`：关键合约（autoload/关键节点/关键方法）不破坏
- **主玩法接入**：当某模块的 Demo 能稳定通过门禁，再把它的接口接入 `Game.tscn` / `WeaponSystem` / `SkillSystem` 等主链路。

## 合并前检查清单（一页）

按顺序执行；任一步失败则先修再合并。

1. **自动化门禁（必跑）**  
   - `python verify_project.py`  
   - 发版或合并战斗/关卡大改前：`python verify_project.py --full`（含 `validate_play` 烟测）

2. **界面中文抽检（合并 UI / 主题 / 文案时建议跑）**  
   - `python tools/audit_ui_cn_strings.py`（退出码 0 为通过；例外写入 `tools/ui_string_allowlist.txt`）

3. **本轮改动与「真主链路」对齐（技能 / 关卡优先自查）**  
   - **技能**：`SkillsDemo` 使用桩节点；合并后确认 `scenes` 下真实 `Game` / `Player` 路径仍满足 `ActiveSkillManager` 与技能脚本约定（避免「Demo 绿、真局崩」）。  
   - **地编**：`LevelDemo` 仅验证最小导航闭环；若主关卡用 `TileMap` / 不同导航层级，需在主场景手工或补测「可走区 + 代理试跑」。  
   - **原画 / 建模**：`ArtDemo`/`ModelingDemo` 已接中文文案与 `module_self_test`；合并新贴图/切片后，在编辑器中确认导入无报错、关键路径资源可加载。

4. **推荐合并顺序（降低耦合风险）**  
   - 程序合约与 autoload 不变的前提下：**UI / 主题** → **音效 / 特效（`EventBus` + `Settings`）** → **骨骼 / 动作（`PlayerBodyRig`）** → **技能与战斗** → **地编与主关卡**；原画/建模随资源迭代并行，不单独挡合并，但需满足第 3 步资源自检。

5. **跨模块关系（合并时对照）**  
   - **资产链**：原画 / 建模 → 骨骼 → 动作（表现层，落点在 `Player` / `PlayerBodyRig`）。  
   - **玩法链**：程序 / 地编 / 技能（规则与场景）。  
   - **反馈链**：UI、音效、特效（多经 `EventBus` 与 `Settings`，勿在反馈层写战斗规则）。

