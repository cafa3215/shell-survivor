# 贡献说明（单人自用）

本项目仅由本人维护，无外部 PR 流程。本文档是**给自己的操作约定**，避免一周后忘记门禁。

---

## 改代码前

1. 看当前优先级：`docs/PROJECT_STATUS.md`
2. 涉及战斗 / 关卡 / 场景链 → 心理备注要跑 `--full`

---

## 改代码后（必做）

```bash
# 默认
python verify_project.py

# 战斗、关卡、技能、BOSS、结算、主场景链
python verify_project.py --full
```

UI 中文文案/theme 变更时（可选）：

```bash
python tools/audit_ui_cn_strings.py
```

---

## 合并到主玩法前

- [ ] 门禁 PASS（写在 `PROJECT_STATUS.md` 表里）
- [ ] `CHANGELOG.md` 一条简要说明
- [ ] 有风险集成时：回滚路径已写明（见 `docs/EXTERNAL_INTEGRATION_POLICY.md`）

---

## 每周五（约 30 分钟）

1. `python tools/advance_project.py run-auto`（或 `bootstrap-week` + `weekly-report`）
2. 填写 `docs/automation/reports/REPORT_*.md` 的指标与交付
3. 更新 `docs/PROJECT_STATUS.md` 第 4、6 节
4. 扫一眼 `docs/RISK_REGISTER.md`

---

## 文档权威顺序

1. `docs/PROJECT_STATUS.md` — 当前做什么  
2. `docs/TAKEOVER_COMMAND_CENTER.md` — P0/P1/P2 队列  
3. `CHANGELOG.md` — 已发布变更  
4. `README.md` — 对外机制说明  
