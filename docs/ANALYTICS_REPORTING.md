# 埋点周报导出（草案 · 单人）

> 在 `ANALYTICS_EVENTS.md` 落地前，**周报指标以手填为准**。

---

## 当前做法（推荐）

1. 试玩 1–3 局，填 `docs/PROJECT_STATUS.md` §4  
2. 或用 HUD `伤害统计` → F6 导出效率快照（见 `balance_dashboard.md`）  
3. 周五写入 `docs/automation/reports/REPORT_*.md` 的 Metrics Snapshot

---

## 未来自动化（31–60 天）

- 每周导出 1 份 JSON/CSV 到 `docs/automation/reports/`
- 字段对齐 `ANALYTICS_EVENTS.md`
- `advance_project.py weekly-report` 可追加读取导出路径（待实现）

---

## 完成标准（启用埋点后）

- [ ] 能回答：本周 10 分钟存活率相对上周升/降
- [ ] 能指出 1 个升级犹豫热点
