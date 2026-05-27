# 可玩版本流水线（单人）

```text
开发切片 → 门禁 → 试玩 → 状态页/CHANGELOG → （可选）导出构建
```

---

## 1. 开发切片

- 从 `PROJECT_STATUS` 的 P1/P2 取 1 项，写清「完成标准」（一句话）。

## 2. 门禁

```bash
python verify_project.py
# 若动到战斗/关卡/技能/BOSS/结算：
python verify_project.py --full
```

## 3. 试玩（15–30 分钟）

记录到 `docs/automation/reports/REPORT_*.md` 或 `PROJECT_STATUS` §4：

- 10 分钟存活率（体感或计数）
- 首次死亡时间
- 升级犹豫点

## 4. 文档

- `CHANGELOG.md`：玩家可见变更
- `PROJECT_STATUS.md`：门禁 PASS + 指标

## 5. 导出（可选）

- Godot：项目 → 导出 → 目标平台
- 导出后再跑一遍快速门禁（确保资源路径未坏）

---

## 自动化辅助

```bash
python tools/advance_project.py run-auto
python tools/advance_project.py validate-auto
```

## 检查清单

`docs/FIRST_PLAYABLE_RELEASE_CHECKLIST.md`
