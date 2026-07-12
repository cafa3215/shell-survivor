# Shell Survivor / 弹壳幸存者

**Vampire Survivors 类型俯视角生存射击游戏** | Godot 4.6

**当前版本：v2.2**

### v2.2 更新摘要（可直接复制发布）
- 武器与特效全面升格：主题色统一、冲击波层、Lv4 成熟期与进化层级更清晰
- 中盘节奏换挡：敌种构成阶段化，关键节点轻量播报
- 关键威胁闭环：命中/击杀高威胁目标有统一反馈，并在回稳时 HUD/音画自动降噪
- 复盘与引导：结算节奏复盘 + 主菜单下一局建议（跨重启保留）

---

## 快速开始

1. 用 Godot 4.6+ 打开本项目
2. 按 F5 运行
3. 移动：WASD / 方向键 / 触摸摇杆
4. 武器自动射击，专注走位即可

### 手机 / 线上试玩

- 导出 Web 版后可用手机浏览器打开链接游玩（触摸摇杆已内置）
- 通用部署：[docs/MOBILE_DEPLOY.md](docs/MOBILE_DEPLOY.md)（itch.io / GitHub Pages / APK）
- **自有域名**：[docs/CUSTOM_DOMAIN_DEPLOY.md](docs/CUSTOM_DOMAIN_DEPLOY.md)（Nginx / Cloudflare + 子域名）

---

## 游戏机制

### 武器系统（11种）
| 武器 | 特色 | 进化效果 |
|------|------|----------|
| 苦无 | 单体投射 | 无限追踪穿透+多重投射 |
| 足球 | AOE反弹 | 链式反弹+BOSS神圣一击 |
| 雷电 | 爆发+眩晕 | 超长眩晕+5次链式跳跃 |
| 火箭 | 延迟爆炸 | 二次爆炸+1.5x范围 |
| 燃烧瓶 | 持续灼烧 | 1.5x时间+1.3x范围 |
| 守卫者 | 旋转挡弹 | +2守卫者+强力击退 |
| AB无人机 | 轨道攻击 | +2无人机+轨道扩展 |
| 回旋镖 | 双程伤害 | 90%回程伤害+环绕 |
| **冰霜领域** ⭐ | 持续减速 | 冻结敌人 |
| **眩晕地雷** ⭐ | 范围眩晕 | 连锁爆炸 |
| **治疗光环** ⭐ | 持续回血 | 生命吸收 |

### 被动技能（10种）
| 被动 | 每级效果 | 满级 |
|------|----------|------|
| 经验增幅 | +14% 经验 | +70% |
| 攻击提升 | +10% 伤害 | +50% |
| 移动速度 | +7% 速度 | +35% |
| 减伤 | +7% 减伤(上限75%) | +35% |
| 吸血 | +4% 吸血 | +20% |
| 额外射速 | +10% 射速 | +50% |
| 暴击率 | +6% 暴击 | +30% |
| 拾取半径 | +28像素 | +140px |
| 生命成长 | +18 HP | +90 HP |
| **护盾** ⭐ | +15 护盾值 | +45 |
| **冰霜** ⭐ | +8%减速 | 30%减速 |
| **击杀爆炸** ⭐ | +20伤害 | 60伤害 |
| **破甲** ⭐ | +5%破甲 | +15%破甲 |

### 融合系统
武器5级 + 关联被动3级 → 进化为6级（1.5x伤害 + 独特强化）
- 升级时有 Soft Pity 机制保证融合出现率
- 融合选项标记为"★推荐"

### BOSS战
- 15分钟出现BOSS
- **3种BOSS类型** ⭐:
  - 暗影巨兽 (均衡型) - 默认
  - 雷霆领主 (快速攻击型) - 闪电链技能
  - 熔岩巨魔 (高血量型) - 岩浆弹幕
- 3个阶段，混合攻击模式（冲撞/脉冲/锥形/组合技）
- **狂暴机制**：BOSS血量低于30%时进入狂暴状态
- 击杀BOSS后进入**无尽模式**：敌人持续增强

### 导演系统
- 根据玩家HP/等级动态调整敌人压力和经验补偿
- 低血量时降低压力+增加经验
- 高等级雪球时增加压力

### 冲刺系统 ⭐
- 空格键冲刺，CD 0.8秒（大幅优化）
- 无敌帧 0.25秒，提升生存能力
- 冲刺速度 900，冲刺手感更流畅

### 随机事件系统 ⭐
- **宝箱**：随机奖励（经验/武器/被动+1）
- **诅咒祭坛**：获得debuff换取临时强化
- **治疗祭坛**：恢复30-50%生命
- 事件每2-3分钟随机出现一次

### BOSS战特殊机制 ⭐
- BOSS战期间精英增援波次
- BOSS血量越低，敌人越疯狂
- 狂暴状态触发时通知玩家

---

## 性能优化

- **SpatialGrid 空间分区**：伤害/眩晕/击退查询 O(n)→O(k)
- **MultiMesh 批量渲染**：2600敌人+2200经验球同屏
- **对象池**：敌人/经验球/粒子/伤害跳字复用
- **分桶更新**：每帧只更新1/N桶敌人AI
- **主动索引**：经验球只遍历活跃实例

---

## 架构

```
Autoload: EventBus / GameDB / AudioManager / Settings / RunStats / InputManager
场景树: Main → MenuLayer / PauseLayer / ResultLayer / Game
Game: Player / EnemyManager / WeaponSystem / SkillSystem / UpgradeSystem
      ExperienceSystem / ParticleManager / DamageNumberManager
      BossTelegraph / WeaponTelegraph / HUD
```

### 伤害流（统一）
```
EnemyManager._player_take_damage() → Player.take_damage()
    → 减伤计算 → 扣HP → 吸血 → EventBus.player_damaged(实际伤害)
    → HUD更新 / RunStats记录
```

---

## 平台支持

- **PC**: 键盘WASD移动 + 自动瞄准
- **移动端**: 浮动摇杆 + 自动瞄准（触摸力度感知）

---

## 设置

- 画质：低/中/高（影响敌人数量、更新频率、经验球合并）
- 低画质：自动合并远处经验球，减少更新桶数

---

## 发布前自检

- 快速自检：`python verify_project.py`
  - 执行 `validate_load` + `validate_modules` + `validate_dimensions` + `validate_release` + `validate_boss_chain` + `validate_active_skill_chain` + `validate_reward_result_chain`
- 完整自检：`python verify_project.py --full`
  - 额外执行 `validate_play`（更长玩法烟测）
- 可指定 Godot 可执行路径：
  - `python verify_project.py --godot-bin "godot"`
  - `python verify_project.py --full --godot-bin "D:\\Godot\\Godot_v4.6.exe"`
- 自动推进（生成周计划/评估表/周报）：
  - `python tools/advance_project.py bootstrap-week --hours 25 --focus "Core gameplay + stable delivery"`
  - `python tools/advance_project.py evaluate-candidate --name "Godot插件名" --repo "https://github.com/owner/repo"`
  - `python tools/advance_project.py weekly-report --hours 25`
  - 一键全自动流水：`python tools/advance_project.py run-auto`
  - 自动产物一致性守卫：`python tools/advance_project.py validate-auto`
  - Windows 脚本入口：`powershell -ExecutionPolicy Bypass -File tools/run_auto_pipeline.ps1`
  - 外部候选全量归档：`python tools/advance_project.py run-auto --archive-all-candidates`
  - beehave 隔离试接入脚手架：`python tools/advance_project.py run-auto --scaffold-beehave-trial`
  - beehave 脚手架附带 Day1/Day2 清单与回滚脚本模板（`tmp/integrations/beehave_trial/scripts/rollback_beehave_trial.ps1`）
  - beehave 脚手架附带 trial 开关与场景骨架（`tmp/integrations/beehave_trial/trial_config.json`、`tmp/integrations/beehave_trial/scenes/BeehaveTrial.tscn`）
  - beehave Day2 对照记录模板（`docs/integrations/BEEHAVE_DAY2_COMPARE_YYYY-MM-DD.md`）
  - beehave Day4 自动汇总：`python tools/summarize_beehave_trial.py --generate-sample-if-missing`

---

## 协作与推进文档（单人）

- **当前状态（每周只维护这一页）：** `docs/PROJECT_STATUS.md`
- 风险登记：`docs/RISK_REGISTER.md`
- 贡献规范：`CONTRIBUTING.md`
- 决策执行系统（30/60/90）：`docs/DECISION_EXECUTION_SYSTEM.md`
- 每周25h推进排程：`docs/WEEKLY_25H_PLAYBOOK.md`
- 外部接入准入规范：`docs/EXTERNAL_INTEGRATION_POLICY.md`
- GitHub项目评估清单：`docs/GITHUB_PROJECT_EVALUATION_CHECKLIST.md`
- 看板配置：`docs/PROJECT_BOARD_SETUP.md`
- 初始任务池：`docs/INITIAL_BACKLOG_30.md`
- P0执行地图：`docs/P0_EXECUTION_MAP.md`
- 首个可玩版本清单：`docs/FIRST_PLAYABLE_RELEASE_CHECKLIST.md`
- 可玩版本流水线：`docs/PLAYABLE_RELEASE_PIPELINE.md`
- 平衡看板手册：`docs/gameplay/balance_dashboard.md`
- Sentry最小接入：`docs/SENTRY_SETUP.md`
- 核心埋点事件：`docs/ANALYTICS_EVENTS.md`
- 埋点周报导出：`docs/ANALYTICS_REPORTING.md`
- 全权接管控制台：`docs/TAKEOVER_COMMAND_CENTER.md`

---

## 版本

- v2.2 - **节奏闭环与成品化收口**
  - 武器特效升级：统一主题色 + 冲击波层；Lv4 成熟期与进化层级更清晰
  - 中盘换挡更明确：敌种构成阶段化 + 轻量导演播报
  - 高威胁闭环：命中/击杀关键目标的统一反馈（并节流降噪）
  - “战局回稳”系统：清掉关键威胁触发短时降压，HUD/音画随之收口
  - 升级三选一前上下文提示（回稳可偏成长，高压优先保命/控场）
  - 结算节奏复盘 + 主菜单下一局建议（RunStats 持久化 + 版本号 + 清洗容错）
  - 发布前自检工具链：`verify_project.py`（含 `validate_boss_chain` / `validate_active_skill_chain` / `validate_reward_result_chain`）
  - 自动推进守卫：`advance_project.py validate-auto`（校验产物齐全/一致/新鲜度）

- v2.1 - **平衡性大改版**
  - 新增4种被动技能（护盾/冰霜/击杀爆炸/破甲）
  - 武器基础属性增强
  - BOSS系统重做（3种类型+狂暴机制）
  - 经验曲线优化（前期更快成长）
  - 导演系统优化（更动态的难度调整）
  - 升级系统优化（弱势武器扶持）
  - 敌人行为优化（后期更频繁攻击）
  - 美化版UI（暂停面板/结果面板）

- v2.0 - 性能优化(SpatialGrid) + 统一伤害流 + BOSS混合攻击 + 无尽模式 + UI增强 + 敌人属性缩放
