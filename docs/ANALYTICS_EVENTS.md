# 核心埋点事件（草案 · 单人）

> 完整接入排在 31–60 天。此前用 HUD 效率榜 + 周报复盘即可。

---

## 建议首批事件（v1）

| 事件 | 触发时机 | 用途 |
|------|----------|------|
| `run_start` | 开局 | 局数统计 |
| `run_end` | 死亡/胜利 | 时长、原因 |
| `level_up` | 升级 | 选择犹豫分析 |
| `boss_spawn` | BOSS 出现 | 到达率 |
| `boss_kill` | BOSS 击杀 | 终局转化 |

---

## 字段最小集

- `session_id`（本局）
- `build_version`（与 CHANGELOG 一致）
- `survival_sec`
- `death_cause`（枚举）

---

## 实现前

- [ ] 在 `PROJECT_STATUS` 登记是否本周做埋点
- [ ] 导出方式见 `docs/ANALYTICS_REPORTING.md`

本地调试可继续用 `docs/gameplay/balance_dashboard.md` 的 F6 快照。
