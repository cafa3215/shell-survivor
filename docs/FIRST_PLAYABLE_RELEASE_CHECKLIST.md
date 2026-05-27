# 首个可玩版本清单（单人发布前）

> 「可玩」= 陌生人 10 分钟能懂规则且无明显阻断 bug，不要求内容完整。

---

## A. 核心循环

- [ ] 开局 → 升级 → 死亡/胜利 → 再开一局 无崩溃
- [ ] 武器自动射击 + 移动输入 PC/移动至少各测 1 次
- [ ] 升级三选一可完成整局
- [ ] BOSS 或等价终局事件可触发（22 分钟线）

## B. 可读性

- [ ] 高压时仍能分辨：自身位置、主要威胁方向、血量
- [ ] 伤害/击杀关键威胁有反馈且不过载
- [ ] 暂停与结果面板文字可读（中文门禁可选跑）

## C. 技术门禁

```bash
python verify_project.py
python verify_project.py --full
```

- [ ] 两项均 PASS
- [ ] `CHANGELOG.md` 版本号与游戏内展示一致（如有）

## D. 构建（按需）

- [ ] Godot 导出预设正确
- [ ] 本机解压/运行导出包 1 次
- [ ] 存档/设置（若有）重启后保留

## E. 文档

- [ ] `README.md` 快速开始仍准确
- [ ] `docs/PROJECT_STATUS.md` 门禁表已标 PASS

---

## 通过后

在 `CHANGELOG.md` 写版本条目，并在 `PROJECT_STATUS.md` 勾选「本周交付」。

流水线细节：`docs/PLAYABLE_RELEASE_PIPELINE.md`
