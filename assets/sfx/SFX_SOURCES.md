## 音效资源候选（可商用）

目标：用于替换当前基础占位音效，提升武器层次与去重复表现。  
原则：优先 CC0 或明确可商用授权。

### 1) Kenney - Impact Sounds（CC0）
- 页面：https://kenney.nl/assets/impact-sounds
- 许可：CC0
- 适用：`hit`、近战/切割次层、轻中型冲击

### 2) OpenGameArt - 25 CC0 bang / firework SFX
- 页面：http://www.opengameart.org/content/25-cc0-bang-firework-sfx
- 文件：`25-CC0-bang-sfx.zip`
- 许可：CC0
- 适用：`explosion`、火箭主爆、地雷爆、重击尾音

### 3) OpenGameArt - Sound effects Mini Pack 1.5
- 页面：https://opengameart.org/content/sound-effects-mini-pack15
- 许可：CC0（作者注明可选署名）
- 适用：`laser-weapon` 类、`hit` 变体、UI/升级拾取

### 4) OpenGameArt - 80 CC0 RPG SFX
- 页面：http://www.opengameart.org/content/80-cc0-rpg-sfx
- 许可：CC0
- 适用：法术、电系次层、受击与击杀补层

## 替换建议
- 保持现有文件名不变可直接替换：
  - `assets/sfx/weapon_fire.wav`
  - `assets/sfx/hit.wav`
  - `assets/sfx/lightning.wav`
  - `assets/sfx/explosion.wav`
- 若引入多变体，建议追加：
  - `assets/sfx/variants/<weapon>/<type>_00.wav` ...
  - 后续可在 `AudioManager` 中扩展为数组轮换。

## 已落地（国内源，本次替换）

来源站点：CC音效库（`https://yinxiao.cc`，文件分发域名 `files.yinxiao.cc`）  
下载方式：调用站点公开下载接口 `/api/audio/report-download/` 获取 `Preview` 直链后下载。  
说明：本轮为占位迭代，先替换 4 个核心事件；后续可在账号登录后补 `SD/SQ` 版本并二次混音。

### 替换映射
- `assets/sfx/weapon_fire.mp3` <= `激光手枪射击`（audio_id: `289870`）
- `assets/sfx/hit.mp3` <= `延迟撞击`（audio_id: `347472`）
- `assets/sfx/lightning.mp3` <= `科幻枪战能量爆破`（audio_id: `290793`）
- `assets/sfx/explosion.mp3` <= `古老大炮轰鸣`（audio_id: `287049`）

### 变体补充（Preview 占位）
- `assets/sfx/variants/weapon_fire/v03.mp3` <= `激光手枪射击`（`289870`）
- `assets/sfx/variants/weapon_fire/v04.mp3` <= `数字界面哔哔声`（`289760`）
- `assets/sfx/variants/weapon_fire/v05.mp3` <= `按钮点击声`（`346594`）
- `assets/sfx/variants/hit/v03.mp3` <= `延迟撞击`（`347472`）
- `assets/sfx/variants/hit/v04.mp3` <= `剑击碰撞`（`311597`）
- `assets/sfx/variants/hit/v05.mp3` <= `金属撞击过渡`（`321621`）
- `assets/sfx/variants/lightning/v03.mp3` <= `科幻枪战能量爆破`（`290793`）
- `assets/sfx/variants/lightning/v04.mp3` <= `电子音渐变`（`335525`）
- `assets/sfx/variants/lightning/v05.mp3` <= `神秘无人机音效`（`345409`）
- `assets/sfx/variants/explosion/v03.mp3` <= `古老大炮轰鸣`（`287049`）
- `assets/sfx/variants/explosion/v04.mp3` <= `破损扫频失真效果`（`348262`）
- `assets/sfx/variants/explosion/v05.mp3` <= 站点接口限流时临时复用 `assets/sfx/explosion.mp3`（后续替换）
