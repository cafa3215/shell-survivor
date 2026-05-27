# Shell Survivor - UI 美化说明

## 概述
本项目已完成UI全面美化，采用赛博朋克风格的视觉设计，提升游戏体验。

---

## UI 美化内容

### 1. HUD 界面 (scenes/ui/HUD_new.tscn)
**改进内容:**
- 采用面板容器设计，整体更加整洁
- 添加图标装饰 (❤ 生命, ★ 等级, ⏱ 时间, 👾 敌人)
- 血条和经验条使用圆角矩形设计，带有发光效果
- Boss血条独立区域显示，包含阶段和百分比信息
- 无尽模式徽章提示
- Shader驱动的动态血条颜色 (低血量红色 → 中等黄色 → 高血量绿色)

**节点结构:**
```
Root
├── TopBar (PanelContainer) - 顶部状态面板
│   └── VBox
│       ├── Row1 - 生命/等级/时间/FPS
│       ├── HpBarRow - 血条
│       └── Row3 - 经验条/敌人计数
├── BossContainer - Boss信息区域
├── EquipButton - 装备按钮
├── JoystickRoot - 移动端摇杆
└── BossWarn/DamageFlash - 全屏特效
```

### 2. 升级面板 (scenes/ui/UpgradePanel_new.tscn)
**改进内容:**
- 更大的卡片尺寸，展示更多内容
- 推荐选项使用金色边框高亮
- 悬停和按下状态有明显的视觉反馈
- 添加底部操作提示
- 标题区域带有闪电图标装饰

### 3. 主菜单 (scenes/Main_new.tscn)
**改进内容:**
- 动态Shader背景 - 包含网格线、粒子效果、扫描线
- 按钮悬停时边框发光效果
- 统一的赛博朋克风格配色
- 平滑的动画过渡效果

**Shader参数:**
- `time` - 动画时间
- `base_color` - 基础颜色
- `accent_color` - 强调色
- `glow_color` - 发光颜色
- `grid_size` - 网格大小
- `grid_opacity` - 网格透明度
- `particle_count` - 粒子数量

### 4. 暂停面板 (scenes/ui/PausePanel.tscn)
**改进内容:**
- 美观的暗角背景效果，带呼吸动画
- 装饰性背景层叠设计
- 按钮带图标 (▶ 继续, 🔄 重新开始, 🏠 主菜单)
- 底部快捷键提示
- 淡入/淡出动画效果
- 面板缩放弹跳动画

**控制器脚本:** `scripts/ui/PausePanel.gd`
- `show_pause()` - 显示暂停界面，带动画
- `hide_pause()` - 隐藏暂停界面，带动画
- `toggle_pause()` - 切换暂停状态

**信号:**
- `resume_pressed` - 继续游戏
- `restart_pressed` - 重新开始
- `menu_pressed` - 返回主菜单

### 5. 结果面板 (scenes/ui/ResultPanel.tscn)
**改进内容:**
- 胜利/失败两种标题样式 (绿色/红色)
- 统计数据卡片设计 - 生存时间、击杀数、伤害
- KPM (每分钟击杀) 和 DPM (每分钟受伤害) 计算
- BOSS战统计 - 出现时间、击杀用时、DPS
- 构筑分析 - 击杀最多的敌人类型、推荐构筑
- 融合统计 - 融合次数和伤害占比
- 构筑诊断 - 智能分析构筑优缺点
- 重新开始/主菜单按钮

**控制器脚本:** `scripts/ui/ResultPanel.gd`
- `show_result(data: Dictionary, is_win: bool)` - 显示结果
- `hide_result()` - 隐藏结果界面

**显示数据:**
- 生存时间 (分:秒)
- 击杀敌人数量 + KPM
- 总伤害
- BOSS: 未出现 / 已击杀 / 未击败
- 击杀最多的敌人类型
- 推荐构筑
- 伤害来源分布
- 融合次数和伤害占比
- 构筑诊断和建议

### 6. 通知系统 (scripts/ui/NotificationSystem.gd)
**功能:**
- 6种通知类型: info, success, warning, error, item, achievement
- 每种类型有独特的图标和颜色
- 滑入/滑出动画效果
- 队列机制，支持多个通知依次显示
- 便捷的静态方法快速发送通知

**使用方法:**
```gdscript
Notification.show("消息内容", 3.0, "success")
Notification.show_weapon_acquired("苦无")
Notification.show_fusion_ready("苦无进化")
```

### 7. Shader 特效

#### menu_bg.gdshader
动态菜单背景着色器，包含:
- 动态网格线
- 扫描线效果
- 漂浮粒子
- 中心光晕
- 边缘渐暗

#### glow_border.gdshader
发光边框着色器:
- 可配置的边缘发光
- 脉冲动画
- 圆角支持

#### hp_bar.gdshader (已有)
血条着色器:
- HP比例驱动的颜色渐变
- 受伤闪烁效果

---

## 配色方案

### 主色调
- **深蓝背景**: `Color(0.04, 0.06, 0.12)` - `#0a0f1e`
- **面板背景**: `Color(0.05, 0.08, 0.15)` - `#0d1426`
- **边框高亮**: `Color(0.15, 0.5, 0.9)` - `#2680e6`

### 状态颜色
- **生命-高**: `Color(0.15, 1.0, 0.55)` - 绿色
- **生命-中**: `Color(1.0, 0.8, 0.15)` - 黄色
- **生命-低**: `Color(1.0, 0.15, 0.1)` - 红色
- **经验条**: `Color(0.4, 0.7, 1.0)` - 蓝色

### 界面元素
- **普通按钮**: `Color(0.08, 0.12, 0.22)` - `#141e38`
- **悬停按钮**: `Color(0.12, 0.2, 0.35)` - `#1e3359`
- **按下按钮**: `Color(0.15, 0.25, 0.4)` - `#264066`
- **推荐边框**: `Color(1.0, 0.85, 0.3)` - 金色

---

## 文件结构

```
scenes/
├── Main.tscn           # 旧主菜单 (保留兼容)
├── Main_new.tscn       # 美化版主菜单 ⭐
├── Game.tscn           # 游戏场景 (已更新引用)
└── ui/
    ├── HUD.tscn        # 旧HUD (保留兼容)
    ├── HUD_new.tscn    # 美化版HUD ⭐
    ├── UpgradePanel.tscn       # 旧升级面板 (保留兼容)
    ├── UpgradePanel_new.tscn   # 美化版升级面板 ⭐
    ├── PausePanel.tscn         # 美化版暂停面板 ⭐
    ├── ResultPanel.tscn        # 美化版结果面板 ⭐
    └── DamageNumber.tscn

scripts/
├── core/
│   ├── Main.gd         # 已更新支持动态背景和信号
│   └── UpgradeSystem.gd # 已更新使用新面板
└── ui/
    ├── HUD.gd          # 已更新支持新布局
    ├── NotificationSystem.gd  # 新增通知系统 ⭐
    ├── PausePanel.gd         # 新增暂停面板控制 ⭐
    ├── ResultPanel.gd        # 新增结果面板控制 ⭐
    └── ...

assets/
├── shaders/
│   ├── menu_bg.gdshader      # 新增菜单背景 ⭐
│   ├── glow_border.gdshader  # 新增发光边框 ⭐
│   ├── vignette_overlay.gdshader  # 新增暗角效果 ⭐
│   └── hp_bar.gdshader       # 血条着色器
└── themes/
    └── cyber_theme.tres      # 赛博主题

project.godot        # 已更新主场景为 Main_new.tscn
```

---

## 向后兼容性

所有 `*_new.tscn` 文件为新的美化版本，原有文件保留以便回退：
- `HUD.tscn` ↔ `HUD_new.tscn`
- `UpgradePanel.tscn` ↔ `UpgradePanel_new.tscn`
- `Main.tscn` ↔ `Main_new.tscn`

如需回退：
1. 修改 `project.godot` 中的 `run/main_scene`
2. 修改 `UpgradeSystem.gd` 中的 `panel_scene` 路径
3. 修改 `Game.tscn` 中的 HUD 引用

---

## 性能考虑

- Shader使用GPU加速，对性能影响较小
- 通知系统使用队列，避免同时显示过多动画
- 主菜单背景Shader已优化粒子数量
- 可通过调整Shader参数平衡画质和性能

---

## 未来改进方向

1. 添加更多动画效果 (按钮弹性、卡片翻转等)
2. 添加音效反馈
3. 添加更多通知类型
4. 支持自定义主题颜色
5. 添加设置选项控制UI动画开关
