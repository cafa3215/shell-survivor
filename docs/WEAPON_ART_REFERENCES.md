# 武器视觉借鉴清单

> 调研日期：2026-07-12  
> 目标：幸存者类弹体/特效的可读性与风格参考（优先 MIT / CC0）

---

## 已接入（本仓库）

| 来源 | 许可 | 用途 | 路径 |
|------|------|------|------|
| [Calinou/kenney-particle-pack](https://github.com/Calinou/kenney-particle-pack) | CC0 | 12 武器弹体 frame_0~3 | `assets/vendor/kenney_particle_pack/` → `assets/game_pack/vfx/projectiles/*/` |
| 安装脚本 | — | `tools/install_kenney_weapon_sprites.gd` | 从 Kenney 映射复制到 game_pack |

### 武器 → Kenney 映射

| 武器 | Kenney 帧 | 视觉意图 |
|------|-----------|----------|
| 苦无 kunai | trace_01~04 | 细长弹道拖尾 |
| 足球 quantum_ball | magic_01~04 | 能量球/魔法环 |
| 雷电 lightning | spark_01~04 | 电弧火花 |
| 主动技 active_bolt | spark_05~07 | 高亮闪电 |
| 火箭 rocket | flame_05/06 + muzzle + trace | 火焰推进 |
| 燃烧瓶 molotov | flame_01~04 | 火团 |
| 守卫 guardian | slash + twirl | 旋转刃 |
| 无人机 drone_ab | star + light | 浮游光点 |
| 回旋镖 boomerang | twirl_01~03 | 旋涡轨迹 |
| 冰霜 frost_aura | magic_05~02 | 冷色魔法环 |
| 治疗 heal_aura | star_01~04 | 柔和星芒 |
| 地雷 stun_mine | symbol + circle | 符文陷阱 |

---

## 推荐继续参考（未集成）

### 幸存者模板 / 玩法结构

| 项目 | 链接 | 可借鉴点 |
|------|------|----------|
| **Survivors Starter Kit** | [DarkRewar/SurvivorsStarterKit](https://github.com/DarkRewar/SurvivorsStarterKit) | 4 种法术（子弹/吸血圈/环绕球/随机 AOE）的**载体与逻辑分层** |
| **DemoSurvivors** | [zhtsu/DemoSurvivors](https://github.com/zhtsu/DemoSurvivors) | Godot 4 幸存者最小实现，武器/敌人资源组织 |
| **survivors-clone** | [bulkashmak/survivors-clone](https://github.com/bulkashmak/survivors-clone) | GDScript 轻量克隆 |

### 弹体引擎 / 高密度弹幕

| 项目 | 链接 | 可借鉴点 |
|------|------|----------|
| **Godot Projectile Engine** | [AzyrGames/GodotProjectileEngine](https://github.com/AzyrGames/GodotProjectileEngine) | MIT；Template + Spawner + Pattern 资源化 |
| **BulletUpHell** | [Dark-Peace/BulletUpHell](https://github.com/Dark-Peace/BulletUpHell) | 弹幕模式节点化（偏弹幕 STG，非幸存者） |
| **BlastBullets2D** | [nikoladevelops/godot-blast-bullets-2d](https://github.com/nikoladevelops/godot-blast-bullets-2d) | 万弹性能；附件粒子跟随弹体 |

### 特效库（下一刀候选）

| 项目 | 链接 | 可借鉴点 |
|------|------|----------|
| **GODOT-VFX-LIBRARY** | [haowg/GODOT-VFX-LIBRARY](https://github.com/haowg/GODOT-VFX-LIBRARY) | MIT；35+ 粒子 + 17 shader（闪电链、火球尾迹） |
| **Kenney Top-down Tanks** | [kenney.nl](https://kenney.nl/assets/top-down-tanks-redux) | CC0；导弹/爆炸实体 sprite（若要做「实体导弹」而非光晕） |

---

## 设计结论（对标幸存者可读性）

1. **弹体用「高对比光晕 + 不同形状族」**，不要 12 种都是小三角 —— Kenney trace/spark/magic 分族即此思路。  
2. **载体与弹道分层**：环绕/无人机用 star/light；直线弹用 trace/muzzle；AOE 用 magic/circle。  
3. **配色**：Kenney 原图已分色，运行时仅做轻微 `modulate` 提亮，避免再染成同色。  
4. **下一优先级**：从 GODOT-VFX-LIBRARY 抽 `lightning chain` / `fireball trail` 挂到命中与 Lv4 进化特效。

---

## 许可说明

- Kenney Particle Pack：**CC0**，可商用，见 `assets/vendor/kenney_particle_pack/LICENSE.txt`
- 集成前请保留 LICENSE；替换单帧时保持 `frame_N.png` 命名以兼容 `WeaponProjectileLayer`
