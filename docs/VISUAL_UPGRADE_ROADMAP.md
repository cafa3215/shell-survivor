# 视觉升级路线图（告别「廉价原型感」）

> 适用：单人 · 25h/周 · 肉鸽幸存者  
> 结论先说：**调 Bloom / 换 Kenney 光晕救不了「低级美工」**——需要 **统一美术方向 + 成套资产 + 少量动效分层**。

---

## 1. 为什么现在看起来廉价

| 层级 | 现状 | 玩家感知 |
|------|------|----------|
| **主角** | 单张 `player_chibi.png` 或程序骨架 | 像插画贴图，不是「游戏角色」 |
| **敌人** | MultiMesh 色块 / 程序 atlas | 像 debug 圆点 |
| **弹体** | Kenney 径向光晕（通用粒子） | 像 Unity 默认粒子，不是「武器」 |
| **地面** | 程序噪声瓦片 | 灰、平、无场景叙事 |
| **风格** | 2D 立绘 + 3D 占位 GLB + CC0 粒子 **混用** | **没有一套世界观** |

**廉价感的本质**：不是分辨率低，而是 **资产来源不一致 + 缺少动画 + 缺少轮廓与层次**。

参考：`docs/WEAPON_ART_REFERENCES.md`（已调研项目与许可）

---

## 2. 两条可行美术路线（二选一，不要混）

### 路线 A — 2D 像素 / 手绘俯视角（最快出「游戏感」）

**适合**：坚持 2D、希望 2–4 周内明显变样。

| 资产包 | 价格 | 链接 | 含什么 |
|--------|------|------|--------|
| Top Down Survival Pack | ~$0.8 | [Anwar2077](https://anwar2077.itch.io/top-down-survival-pack) | 多角色动画、僵尸、枪、载具 |
| Simple Cute 2D Zombies | $25 | [Jovial Games](https://jovialgamesofficial.itch.io/simple-cute-2d-zombies-pack) | 10 英雄 + 10 僵尸 + 10 武器，风格统一 |
| Cute Fantasy RPG 16×16 | 免费 | itch 搜 tag `top-down` | 瓦片 + 基础角色 |
| Ninja Adventure | 免费 | itch | 俯视角 tile + 角色 |

**集成到本项目**（drop-in 路径见 `GameDB.gd`）：

```
assets/game_pack/textures/player_chibi.png      ← 换成动画条带 idle/run/attack
assets/game_pack/textures/player_run_strip.png  ← 4/8 方向跑步
assets/game_pack/textures/enemy_atlas.png       ← 256×64 四格，64×64/格
assets/game_pack/textures/ground_tile.png       ← 1024 或 2048 瓦片
assets/game_pack/vfx/projectiles/<weapon>/      ← 用包内 **方向性** bullet，不要光晕圆
```

### 路线 B — 低多边形 3D（KayKit，与现有 GLB 武器一致）

**适合**：愿意做「斜俯 3D 幸存者」（类似部分手游壳）。

| 资产包 | 价格 | 链接 |
|--------|------|------|
| KayKit Adventurers | **免费 CC0** | [kaylousberg.itch.io/kaykit-adventurers](https://kaylousberg.itch.io/kaykit-adventurers) |
| KayKit Skeletons（敌人） | **免费 CC0** | [kaykit-skeletons](https://kaylousberg.itch.io/kaykit-skeletons) |
| KayKit Forest / Dungeon | 免费 | 场景地面与道具 |
| KayKit Character Animations | 免费 | 160+ 人形动画 |

**集成思路**：

1. 用 Adventurer GLB 替换 `Player` 的 Sprite2D（SubViewport 或 MeshInstance2D 烘焙）。
2. `assets/game_pack/models/weapons/*.glb` 已有占位 → 换成 KayKit 配件 GLB。
3. 敌人用 Skeleton MultiMesh 或 instanced 3D → 2D 相机渲染。

> 若选 B，**停用 Kenney 2D 弹体**，改为 3D 飞弹 + 粒子尾迹，否则又混风格。

---

## 3. 提升视觉的优先级（ROI 排序）

按 **「玩家第一眼」** 排序，单人每周只做 1 项：

| 优先级 | 内容 | 预期提升 | 工时 |
|--------|------|----------|------|
| **P0** | **定美术方向**（像素 cute / 机甲 3D / 暗黑写实 选一） | 后续不白做 | 2h 找参考拼图 |
| **P1** | **主角可动画**（跑、受击、至少 4 方向） | 从贴图变「角色」 | 4–8h |
| **P2** | **敌人 4–6 种可辨 silhouette**（ atlas 或 3D） | 战场不再像色块 | 4–6h |
| **P3** | **地面 + 少量装饰**（同包 tile） | 有「场景」 | 2–4h |
| **P4** | **武器：方向 sprite 或 3D 模型**（同风格 12 种） | 弹道有「物件感」 | 6–12h |
| **P5** | **命中/击杀 VFX**（GODOT-VFX-LIBRARY 等，MIT） | 爽感 +30% | 4h |
| **P6** | UI 皮肤与 HUD 降噪 | 少「工具感」 | 按需 |

**不要先做**：继续放大 Kenney 光晕、加 Bloom、程序画三角弹体——这些只会更像 placeholder。

---

## 4. 武器美工专门说明

### 为什么 Kenney 仍显廉价

- Kenney Particle Pack 设计用途是 **粒子特效**，不是 **弹道实体**。
- 12 种武器共用「发光圆/星芒」语言 → **形变不足**。
- 与机甲主角、程序敌人 **不在同一美术世代**。

### 正确做法（幸存者常见）

1. **同一画师/同一 asset pack** 出 12 个小 icon（32×32 或 64×64），每种 **形状不同**：针、弹、弧、瓶、雷、环…
2. 飞行时：**本体 sprite + 短拖尾粒子**（拖尾用 Kenney 可以，本体不行）。
3. Lv4/进化：换色 + 外圈 + 命中爆点（`WeaponTelegraph` / `ParticleManager` 已有钩子）。

### 可抄的结构（非抄图）

- [Survivors Starter Kit](https://github.com/DarkRewar/SurvivorsStarterKit)：环绕球 vs 直线弹 vs 地面 AOE **分层**。
- [haowg/GODOT-VFX-LIBRARY](https://github.com/haowg/GODOT-VFX-LIBRARY)：只借 **命中/闪电链**，不借弹体本体。

---

## 5. 代码层能做的事（不替代美术，但放大美术）

在 **P1–P4 资产到位后** 再做，否则收益低：

| 手段 | 作用 |
|------|------|
| 统一后处理档位 `CINEMATIC` | 已有；只调色，不造细节 |
| 角色外轮廓 shader / 描边 | 让像素/3D 在乱战场里跳出 |
| 击杀冲击波 + 闪屏 | 已有；资产好了才显贵 |
| 相机 zoom 0.84 + 主角光晕 | 已有；需配合更大更清晰的主角 |
| `Player` 跑步/转向条带动画 | 路径已留，缺的是 **序列帧 PNG** |

---

## 6. 单人 4 周执行表（示例）

| 周 | 交付 | 验收标准 |
|----|------|----------|
| W1 | 选定路线 A 或 B + 购买/下载 **同一套包** | 参考板 1 页，不再混 Kenney 弹体 |
| W2 | 主角动画进游戏 | 跑起来有 4 方向，不是单图平移 |
| W3 | enemy_atlas + ground_tile 替换 | 10 分钟试玩不觉得「色块追人」 |
| W4 | 6 种核心武器方向弹体 + 命中 VFX | 能分清苦无/火箭/雷电 |

---

## 7. 若预算允许（最快质变）

- **$25–80**：itch 成套 survivor pack（角色+怪+弹+UI 同作者）。
- **$150–400**：约稿 1 主角 + 12 武器 icon + 1 enemy sheet（Fiverr / 米画师），**指定俯视角与 palette**。
- **禁止**：从 5 个免费站拼 12 种弹体——比现在还廉价。

---

## 8. 与本仓库的对接命令

资产放好后：

```bash
# 弹体（若仍用 PNG 目录结构）
godot --headless --script res://tools/install_kenney_weapon_sprites.gd  # 仅临时；最终应换 pack 内 bullet

python verify_project.py --full
```

文档同步：`CHANGELOG.md`、`docs/VISUAL_EXPERIENCE.md`

---

## 9. 请你拍板的一个选择

回复 **A（2D 像素）** 或 **B（KayKit 3D）** 或 **C（约稿定制）**，我可以按选定路线做 **下一版具体集成**（替换 Player / enemy_atlas / 武器弹体目录与验收清单）。

未选方向前，**不建议再改数值或粒子缩放**——投入产出比最低。
