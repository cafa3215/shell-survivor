# 项目状态（单人 · 唯一可信源）

> 每周只维护这一页 + `CHANGELOG.md`。其它计划文档均指向此处，避免漂移。  
> 自动化会更新「本周链接」区块；其余字段由你在周五复盘时手填。

**项目：** Shell Survivor / 弹壳幸存者  
**版本：** v2.2.1（见 `CHANGELOG.md`）  
**负责人：** 本人（单人）  
**最后更新：** 2026-05-27

---

## 1. 本周焦点

- **容量：** 25h（70% 玩法 / 20% 流程 / 10% 实验）
- **焦点句：** P1 mid-game readability
- **周看板：** `docs/automation/weekly/WEEK_2026-05-25.md`
- **周报告：** `docs/automation/reports/REPORT_2026-05-25.md`

---

## 2. 门禁快照（改代码后必跑）

| 检查 | 命令 | 状态 |
|------|------|------|
| 快速门禁 | `python verify_project.py` | 待测 |
| 完整门禁 | `python verify_project.py --full` | 待测 |
| 自动化产物 | `python tools/advance_project.py validate-auto` | 待测 |

> 通过后将「待测」改为 `PASS` 并写上日期。

---

## 3. 优先级队列（与指挥中枢同步）

来源：`docs/TAKEOVER_COMMAND_CENTER.md`

### P0 — 已完成

- 运行流水线与自动化产物一致性
- Boss / 主动技能 / 结算奖励链门禁
- 文档与已交付状态对齐（本轮修复死链与状态页）

### P1 — 进行中

1. [ ] 中盘可读性（预警 + HUD 噪声）
2. [ ] 8–14 分钟与 20+ 分钟难度节奏
3. [ ] 死亡后推荐与复盘一致性

### P2 — 排队

1. [ ] 外部模块集成节奏模板
2. [ ] 分析采样策略（周对比稳定）

---

## 4. 试玩指标（每周五必填）

| 指标 | 本周值 | 备注 |
|------|--------|------|
| 10 分钟存活率 | | 试玩 1–3 局取体感或记录 |
| 首次死亡时间（中位数） | | 分钟 |
| 升级犹豫热点 | | 哪类武器/被动 |

详细采集见 `docs/gameplay/balance_dashboard.md`（HUD 效率榜 + F6 快照）。

---

## 5. 开放风险（Top 5）

登记册：`docs/RISK_REGISTER.md`

| ID | 风险 | 状态 |
|----|------|------|
| R1 | 文档与 README 链接不一致 | 缓解中 |
| R2 | 玩法改动未跑 `--full` | 监控 |
| R3 | 外部插件深度耦合主链路 | 监控 |
| R4 | Godot 小版本升级破坏 headless | 接受 |
| R5 | 周报复盘指标长期空白 | 缓解中 |

---

## 6. 本周交付（周五勾选）

- [ ] 至少 1 项 P1 可验收切片
- [ ] `CHANGELOG.md` 已更新
- [ ] 上表指标已填写
- [ ] `docs/RISK_REGISTER.md` 复查 1 次

---

## 7. 快速导航

| 用途 | 文档 |
|------|------|
| 执行规则 | `docs/TAKEOVER_COMMAND_CENTER.md` |
| 25h 排程 | `docs/WEEKLY_25H_PLAYBOOK.md` |
| 风险登记 | `docs/RISK_REGISTER.md` |
| 发布自检 | `README.md` → 发布前自检 |
| 可玩版本 | `docs/FIRST_PLAYABLE_RELEASE_CHECKLIST.md` |
| 经验沉淀 | `docs/LESSONS_LEARNED.md` |
