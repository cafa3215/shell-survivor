# Changelog

## v2.2.2 (unreleased)

### Fix — Movement / Loadout
- 恢复玩家 `Camera2D` 跟随与原版移动/暂停流程；修复 `RunRelicPickPanel` 场景与脚本节点路径不一致导致遗物三选一空卡、无法开战的问题。
- KayKit 3D 主角默认关闭，保留 2D 骨架立绘；`WeaponProjectileLayer` 由 `WeaponSystem` 运行时按需创建。

### Pacing / Run Length
- **首领 15 分钟**：`BOSS_SPAWN_TIME` 22→15 分；整局 `RUN_TIME` 25→18 分（首领后 3 分钟撤离窗口）。
- **精英事件**：5 / 8 / 12 分钟三档 mini-boss；首波（5 分）加强 HP/伤害、屏幕闪白、震屏、更多经验球与 4:30 预告。
- **HUD 目标**：`🎯 首领 XX:XX` 与里程碑同步新节奏。

### Visual / Weapons (P1)
- 生成 `assets/game_pack/vfx/projectiles/*/frame_*.png` 占位弹体（12 种武器 × 4 帧，带描边配色）。
- `WeaponProjectileLayer` 弹体基础缩放上调，区分苦无/火箭/雷电/领域等轮廓。

### UX / Debug
- 移除战斗调试叠字（活跃事件/性能桶池/F8 过滤）；`perf_label`/`fps_label` 默认隐藏。
- **主动技能**：`RunLoadout` 开局绑定 + `InputMap`/`R`/右键 fallback；HUD 显示「技能未就绪」。

### Attraction / Early Flow
- 首升 ~38s（SOFT 预设）、开局经验球冲刺、HUD `⚡ 首次升级` / 首升 spectacle。
- 死亡结算面板增加下局建议；8 分钟中盘提示保留（蓄力预警说明）。

### Pacing / Onboarding
- Slowed early XP (higher first-level cost, no kickstart level-up, upgrade panel gated until ~55s).
- Reduced early spawn rate and wave size; delayed auto XP orb bursts to 75s+.
- Procedural 4-frame enemy atlas (walker/runner/brute/caster) + stronger per-type colors when no `enemy_atlas.png`.

### Visual / Presentation
- Default VFX profile `CINEMATIC` + readability `HIGH`; stronger bloom/saturation post-process.
- Kill shockwave ring + subtle screen flash; brighter XP orbs, player glow/trail, closer camera (0.84).
- Enemies less desaturated; sky/ground slightly brighter. See `docs/VISUAL_EXPERIENCE.md`.

### Gameplay / Early Retention (P1)
- **前 3 分钟吸引力**：开局经验球 + 半级冲刺、更快首升、前期减刷怪/减压、经验加成；90 秒「进入状态」钩子。
- **提示降噪**：前 2.5 分钟关闭里程碑/导演喊话/升级废话；去掉 8 分钟教学提示。
- **快速重开**：记住上次专精+遗物，下局跳过双面板（`Settings.remember_run_loadout`，默认开）。
- 默认 `early_flow_preset` 改为 SOFT；`early_flow_card.json` 三档参数重写。

### Gameplay / Readability (P1)
- Spitter ranged attacks now use a short windup telegraph (orange tint + ground mark) before dealing damage.
- Charger windup shows the same ground telegraph ring; threat edge arrows prioritize imminent windup targets.
- Mid-run tip at 8:00 explains orange windup = incoming attack.

### Project Management (solo)
- Added single source of truth: `docs/PROJECT_STATUS.md` and `docs/RISK_REGISTER.md`.
- Restored README-linked docs (`CONTRIBUTING.md`, backlog, P0 map, release checklists, analytics stubs).
- `advance_project.py` now syncs week links into `PROJECT_STATUS.md` on `bootstrap-week` / `weekly-report` / `run-auto`.

## v2.2.1

### Pipeline / Reliability
- Added automation artifact guard: `python tools/advance_project.py validate-auto` now checks expected weekly/report/evaluation/log outputs, log-path consistency, and freshness window.
- Hardened Windows automation entry scripts to run generation + validation in sequence:
  - `tools/run_auto_pipeline.ps1`
  - `run_auto_pipeline.bat`
- Pipeline log now includes `generated_at` for stronger traceability.

### Verification Gates
- Added high-risk boss chain guard: `tools/validate_boss_chain.gd`.
- Added active-skill trigger chain guard: `tools/validate_active_skill_chain.gd`.
- Added reward/result persistence chain guard: `tools/validate_reward_result_chain.gd`.
- Wired `validate_boss_chain` into `verify_project.py` default gate stack.
- Wired `validate_active_skill_chain` into `verify_project.py` default gate stack.
- Wired `validate_reward_result_chain` into `verify_project.py` default gate stack.
- Re-ran fast/full verification after integration:
  - `python verify_project.py`
  - `python verify_project.py --full`

## v2.2

### Gameplay / Feel
- Weapon VFX upgraded: unified palette, added impact shockwave layer, and clearer Lv4 “mature” vs evolution visual hierarchy.
- Mid-run pacing improved: explicit director “gear shifts” (enemy composition changes) with short callouts.
- Threat feedback loop: consistent low-noise feedback for hitting/killing high-threat enemies (spitter/summoner/charger/elite).
- “Stabilize the fight” system: clearing threats grants short pressure relief (reduced spawn pressure), with HUD/audio/postprocess calming to make it feel tangible.
- Upgrade decision assist: context hint before upgrade panel (pressure vs relief) to guide safer picks.

### UI / UX
- Threat edge indicators refined: boss/priority-first filtering, cleaner visuals, and automatic de-noise when pressure relief is active.
- Results panel: added a pacing recap line aligning in-run hints with end-of-run feedback.
- Main menu: added “next run hint” one-liner; now persists across restarts.

### Tech / Stability
- RunStats history persistence with save version + sanitization.
- Added release verification tooling: `verify_project.py` and `tools/validate_release.gd`.

