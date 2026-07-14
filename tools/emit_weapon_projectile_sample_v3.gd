extends SceneTree

const ArtSample = preload("res://scripts/weapon_presentation/WeaponProjectileArtSample.gd")

## 导出弹体小样 Energy Trail v3 — 未合入实机

const OUT_DIR := "res://assets/previews/weapon_projectiles/sample_v3"
const COMBAT: PackedStringArray = ["kunai", "quantum_ball", "lightning", "rocket", "boomerang", "drone_ab"]
const WEAPONS: Array[Dictionary] = [
	{"id": "kunai", "name": "苦无", "color": Color(0.45, 0.92, 1.0), "tag": "STL宽刃·青蓝丝带尾迹"},
	{"id": "quantum_ball", "name": "量子球", "color": Color(0.55, 1.0, 0.55), "tag": "能量球·轨道丝"},
	{"id": "lightning", "name": "雷电", "color": Color(0.55, 0.85, 1.0), "tag": "锯齿束·电丝尾迹"},
	{"id": "rocket", "name": "火箭", "color": Color(1.0, 0.55, 0.25), "tag": "弹体·橙焰条带"},
	{"id": "boomerang", "name": "回旋镖", "color": Color(1.0, 0.82, 0.35), "tag": "V翼·弧光尾迹"},
	{"id": "drone_ab", "name": "无人机", "color": Color(0.65, 0.88, 1.0), "tag": "机体·旋翼光迹"},
	{"id": "molotov", "name": "燃烧瓶", "color": Color(1.0, 0.5, 0.2), "tag": "瓶身·火丝"},
	{"id": "guardian", "name": "守卫者", "color": Color(1.0, 0.86, 0.42), "tag": "盾形·金环脉冲"},
	{"id": "frost_aura", "name": "冰霜", "color": Color(0.55, 0.88, 1.0), "tag": "雪花·冷雾丝"},
	{"id": "heal_aura", "name": "治疗", "color": Color(0.45, 1.0, 0.62), "tag": "十字·绿环"},
	{"id": "stun_mine", "name": "地雷", "color": Color(0.88, 0.55, 1.0), "tag": "刺六角·紫核"},
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var sprites: Dictionary = {}
	for w in WEAPONS:
		var kind: String = w["id"]
		var img := ArtSample.render_kind(kind, 0)
		img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, kind]))
		sprites[kind] = img
		for f in range(4):
			ArtSample.render_kind(kind, f).save_png(ProjectSettings.globalize_path("%s/%s_f%d.png" % [OUT_DIR, kind, f]))
	var sheet := _make_sheet(sprites)
	sheet.save_png(ProjectSettings.globalize_path("%s/preview_sheet.png" % OUT_DIR))
	_make_combat_demo().save_png(ProjectSettings.globalize_path("%s/combat_volley_demo.png" % OUT_DIR))
	_write_html()
	print("sample_v3 [%s] -> %s" % [ArtSample.style_id(), ProjectSettings.globalize_path(OUT_DIR)])
	quit(0)


func _make_sheet(sprites: Dictionary) -> Image:
	var cols := 4
	var rows := int(ceil(float(WEAPONS.size()) / float(cols)))
	var cell_w := 320
	var cell_h := 260
	var pad := 28
	var header := 56
	var w := cols * cell_w + pad * 2
	var h := header + rows * cell_h + pad * 2
	var sheet := Image.create(w, h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.03, 0.04, 0.07, 1.0))
	for i in range(WEAPONS.size()):
		var info: Dictionary = WEAPONS[i]
		var col := i % cols
		var row := int(i / cols)
		var ox := pad + col * cell_w
		var oy := header + pad + row * cell_h
		var bar: Color = info["color"]
		_fill_rect(sheet, ox + 10, oy + 10, cell_w - 20, cell_h - 20, Color(0.06, 0.07, 0.11, 1.0))
		_fill_rect(sheet, ox + 10, oy + 10, cell_w - 20, 4, bar)
		var spr: Image = sprites[info["id"]]
		var solo := spr.duplicate()
		solo.resize(172, 172, Image.INTERPOLATE_LANCZOS)
		_blit(sheet, solo, ox + 20, oy + 32)
		for v in range(3):
			var mini := ArtSample.render_kind(info["id"], v + 1).duplicate()
			mini.resize(76, 76, Image.INTERPOLATE_LANCZOS)
			_blit(sheet, mini, ox + 182 + v * 44, oy + 48 + v * 12)
	return sheet


func _make_combat_demo() -> Image:
	var w := 960
	var h := 340
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.02, 0.03, 0.06, 1.0))
	for i in range(COMBAT.size()):
		var kind := COMBAT[i]
		var ox := 36 + i * 152
		var oy := 88
		for j in range(5):
			var p := ArtSample.render_kind(kind, j).duplicate()
			p.resize(58, 58, Image.INTERPOLATE_LANCZOS)
			_blit(img, p, ox + j * 24, oy + j * 10)
		for k in range(48):
			_fill_rect(img, ox + (k * 13) % 128, oy + 100 + (k * 9) % 150, 7, 7, Color(0.15, 0.2, 0.32, 0.5))
	return img


func _write_html() -> void:
	var html := """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="UTF-8"/><title>弹体小样 v3 Energy Trail</title>
<style>
body{margin:0;font-family:"Segoe UI","Microsoft YaHei",sans-serif;background:#06080e;color:#eef1f8;padding:28px}
h1{margin:0 0 6px}.badge{display:inline-block;background:#123a52;color:#5ec8ff;padding:4px 10px;border-radius:6px;font-size:12px;margin-bottom:14px}
.sub{color:#8b93a8;line-height:1.7;font-size:14px;max-width:920px;margin-bottom:20px}
.hero{display:grid;grid-template-columns:1fr 1fr;gap:16px;max-width:1180px;margin-bottom:22px}
.hero img{width:100%;border:1px solid #2a3144;border-radius:10px;background:#04060a}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:14px;max-width:1180px}
.card{background:#0e1118;border:1px solid #2a3144;border-radius:10px;overflow:hidden}
.head{padding:12px 14px 8px;border-bottom:3px solid var(--bar,#5ec8ff)}
.head h2{margin:0;font-size:16px}.head p{margin:4px 0 0;font-size:12px;color:#8b93a8}
.body{display:grid;grid-template-columns:1fr 1fr;gap:10px;padding:14px}
.panel{background:#04060a;border-radius:8px;padding:10px;text-align:center}
.panel img{width:132px;height:132px;filter:drop-shadow(0 0 12px rgba(80,180,255,.35))}
.anim{display:flex;gap:5px;justify-content:center;align-items:center;min-height:132px}
.anim img{width:54px;height:54px}
.note{margin-top:22px;max-width:920px;padding:16px;border:1px dashed #2a3144;border-radius:8px;color:#8b93a8;font-size:13px;line-height:1.75}
</style></head><body>
<h1>弹体小样 v3 · Energy Trail</h1>
<div class="badge">参考苦无 STL + gg-tx 青蓝能量拖尾 · 未合入游戏</div>
<p class="sub">统一语法：柔光晕 + 水平条带尾迹 + 能量丝带 + 前端亮核。每种武器换色但共享同一拖尾语言。</p>
<div class="hero">
<figure><img src="preview_sheet.png" alt="总览"/><figcaption>11 种武器总览</figcaption></figure>
<figure><img src="combat_volley_demo.png" alt="密集"/><figcaption>怪海背景齐射可读性</figcaption></figure>
</div>
<div class="grid" id="g"></div>
<div class="note"><strong>路径：</strong> assets/previews/weapon_projectiles/sample_v3/<br>
确认后回复「同意」才会替换实机弹体。</div>
<script>
const ws=[{id:"kunai",n:"苦无 ★",b:"#5ec8ff",t:"STL宽刃·青蓝丝带"},{id:"quantum_ball",n:"量子球 ★",b:"#7cff7a",t:"能量球·轨道丝"},{id:"lightning",n:"雷电 ★",b:"#7ad4ff",t:"锯齿·电丝"},{id:"rocket",n:"火箭 ★",b:"#ff8a45",t:"弹体·橙焰条带"},{id:"boomerang",n:"回旋镖 ★",b:"#ffd45a",t:"V翼·弧光"},{id:"drone_ab",n:"无人机 ★",b:"#8ec8ff",t:"四旋翼光迹"},{id:"molotov",n:"燃烧瓶",b:"#ff7a35",t:"瓶·火丝"},{id:"guardian",n:"守卫者",b:"#ffd86a",t:"盾·金环"},{id:"frost_aura",n:"冰霜",b:"#7ec8ff",t:"雪花·冷雾"},{id:"heal_aura",n:"治疗",b:"#5cff9a",t:"十字·绿环"},{id:"stun_mine",n:"地雷",b:"#c88aff",t:"刺六角·紫核"}];
const g=document.getElementById("g");
for(const w of ws){const el=document.createElement("article");el.className="card";el.style.setProperty("--bar",w.b);
el.innerHTML=`<div class="head"><h2>${w.n}</h2><p>${w.t}</p></div><div class="body"><div class="panel"><img src="${w.id}.png"/><span style="font-size:11px;color:#8b93a8">主视图</span></div><div class="panel"><div class="anim">${[0,1,2,3].map(f=>`<img src="${w.id}_f${f}.png"/>`).join("")}</div><span style="font-size:11px;color:#8b93a8">4帧</span></div></div>`;g.appendChild(el);}
</script></body></html>"""
	var f := FileAccess.open(ProjectSettings.globalize_path("%s/preview.html" % OUT_DIR), FileAccess.WRITE)
	if f:
		f.store_string(html)
		f.close()


func _blit(dst: Image, src: Image, x: int, y: int) -> void:
	for py in range(src.get_height()):
		for px in range(src.get_width()):
			var c := src.get_pixel(px, py)
			if c.a < 0.04:
				continue
			var dx := x + px
			var dy := y + py
			if dx >= 0 and dy >= 0 and dx < dst.get_width() and dy < dst.get_height():
				var bg := dst.get_pixel(dx, dy)
				var a := c.a + bg.a * (1.0 - c.a)
				if a <= 0.0001:
					continue
				dst.set_pixel(dx, dy, Color(
					(c.r * c.a + bg.r * bg.a * (1.0 - c.a)) / a,
					(c.g * c.a + bg.g * bg.a * (1.0 - c.a)) / a,
					(c.b * c.a + bg.b * bg.a * (1.0 - c.a)) / a, a))


func _fill_rect(img: Image, x: int, y: int, rw: int, rh: int, col: Color) -> void:
	for py in range(y, y + rh):
		for px in range(x, x + rw):
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, col)
