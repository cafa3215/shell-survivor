# 初始任务池（30 条 · 单人）

> 不是每周全做，而是从中按风险/收益挑 5–7 条进周看板。  
> 当前执行优先级以 `docs/PROJECT_STATUS.md` 与 `docs/TAKEOVER_COMMAND_CENTER.md` 为准。

---

## P1 体验（当前重点）

1. [ ] 中盘敌人预警形状/颜色统一（可读性）
2. [ ] HUD 高压时自动降噪（与回稳系统一致）
3. [ ] 8–14 分钟敌种构成换挡试玩 3 局并记笔记
4. [ ] 20+ 分钟压力曲线对比改前改后
5. [ ] 死亡结算「下一局建议」与局内提示对齐
6. [ ] 升级面板犹豫点：统计 3 局截图/文字
7. [ ] 威胁边缘指示器 boss 优先逻辑回归测试

## 玩法 / 平衡

8. [ ] 弱势武器 Soft Pity 体感验证
9. [ ] 融合 ★ 推荐在高压局是否误导
10. [ ] BOSS 狂暴 30% 阶段可读性
11. [ ] 无尽模式 25 分钟+ 帧率采样
12. [ ] 导演系统低血量补偿是否过强
13. [ ] 冲刺 CD 0.8s 与无敌帧手感
14. [ ] 移动端摇杆力度曲线试玩

## 技术 / 质量

15. [ ] 精英+BOSS 同屏帧尖峰优化
16. [ ] `validate_play` 加长场景覆盖一项新机制
17. [ ] 模块 Demo 与 Main 技能接口再对齐一次
18. [ ] 中文 UI 门禁全量扫（`audit_ui_cn_strings`）
19. [ ] 低画质经验球合并边界 case
20. [ ] 伤害统计 HUD 实验模式默认口径固定

## 流程 / 工具

21. [ ] 周报三指标连续 2 周非空
22. [ ] `validate-auto` 纳入周五固定动作
23. [ ] 外部候选评估再跑 1 个（清单见 `GITHUB_PROJECT_EVALUATION_CHECKLIST.md`）
24. [ ] CI：GitHub Actions 跑 `verify_project.py`（见 `DECISION_EXECUTION_SYSTEM` 31–60 天）
25. [ ] 资产许可证台账首版（表格即可）

## 发布 / 收尾

26. [ ] 走一遍 `FIRST_PLAYABLE_RELEASE_CHECKLIST.md`
27. [ ] 导出 Windows 可玩构建并自测安装包
28. [ ] 版本号与 `RunStats` 清洗逻辑再验证
29. [ ] 主菜单「下一局建议」跨重启 3 次测试
30. [ ] `LESSONS_LEARNED.md` 写 1 条本周结论

---

## 与自动化的关系

`tools/advance_project.py` 默认周任务池是上面任务的**子集缩写**；可改 `DEFAULT_BACKLOG` 与本文件保持同步。
