# 经验教训（单人 · 持续追加）

> 每条 3–5 行即可；重大集成后必写 1 条。

---

## 模板

```markdown
### YYYY-MM-DD · 标题
- **背景：**
- **做法：**
- **结果：**
- **下次：**
```

---

## 2026-04 · Beehave 隔离试用

- **背景：** 行为树插件若直接进主场景，回滚成本高。
- **做法：** `tmp/integrations/beehave_trial` + 7 天清单 + `rollback_beehave_trial.ps1`。
- **结果：** 主链路零改动下可对比 FPS/状态迁移；决策文档在 `docs/integrations/`。
- **下次：** 任何「高风险」插件复制此模式，见 `EXTERNAL_INTEGRATION_POLICY.md`。

---

## 2026-05 · 文档唯一可信源

- **背景：** README 链到多份不存在文档，计划与代码漂移。
- **做法：** 新增 `PROJECT_STATUS.md` + `RISK_REGISTER.md`，修复死链。
- **结果：** 单人只需维护状态页 + CHANGELOG。
- **下次：** 新增文档必须链回 `PROJECT_STATUS` 或删 README 入口。

---

## 待写

- （本周试玩 / 集成结束后在此追加）
