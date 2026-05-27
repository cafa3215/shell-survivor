# 看板配置（单人 · 可选）

无需 GitHub Projects 也能推进。推荐二选一：

---

## 方案 A：本地 Markdown（默认）

| 列 | 对应文件 |
|----|----------|
| Backlog | `docs/INITIAL_BACKLOG_30.md` |
| This Week | `docs/automation/weekly/WEEK_*.md`（`bootstrap-week` 生成） |
| Done | `CHANGELOG.md` + 周报告勾选 |

每周一：`python tools/advance_project.py bootstrap-week --hours 25 --focus "你的焦点"`

---

## 方案 B：GitHub Projects（可选）

若仓库已上 GitHub：

1. 新建 Project（Board），列：`Todo` / `Doing` / `Done`
2. 每周从 `WEEK_*.md` 抄 5–7 条进 `Todo`
3. 完成标准写在卡片描述里（与 `CONTRIBUTING.md` 一致）

**注意：** 看板只是视图；**权威状态仍以 `docs/PROJECT_STATUS.md` 为准**。
