# P0 执行地图（稳定性 · 已完成）

> P0 已全部关闭；**当前工作重心在 P1**。状态总览见 `docs/PROJECT_STATUS.md`。

---

## 目标（历史）

在功能迭代同时，保证主链路可发布、可回滚、可自动验证。

---

## 交付地图

| # | 项 | 验收 | 状态 |
|---|-----|------|------|
| 1 | 自动化周产物 + `validate-auto` | 产物齐全、日志路径一致、新鲜度 | DONE |
| 2 | Boss 生成链门禁 | `validate_boss_chain.gd` 进默认栈 | DONE |
| 3 | 主动技能链门禁 | `validate_active_skill_chain.gd` | DONE |
| 4 | 结算/奖励持久化链 | `validate_reward_result_chain.gd` | DONE |
| 5 | 文档与交付对齐 | `PROJECT_STATUS` + 死链修复 | DONE |

---

## 验证命令（仍适用）

```bash
python verify_project.py
python verify_project.py --full
python tools/advance_project.py validate-auto
```

---

## 下一步（P1）

见 `docs/TAKEOVER_COMMAND_CENTER.md` § P1：中盘可读性 → 节奏 → 死亡复盘。
