extends SceneTree

## 模块自检：逐个加载并实例化模块 Demo 场景，跑少量帧确保脚本/资源可用。

const DEMO_SCENES: PackedStringArray = [
	"res://scenes/modules/vfx/VFXDemo.tscn",
	"res://scenes/modules/sfx/SFXDemo.tscn",
	"res://scenes/modules/ui/UIDemo.tscn",
	"res://scenes/modules/art/ArtDemo.tscn",
	"res://scenes/modules/skills/SkillsDemo.tscn",
	"res://scenes/modules/skills/SkillsWhitebox.tscn",
	"res://scenes/modules/animation/AnimationDemo.tscn",
	"res://scenes/modules/modeling/ModelingDemo.tscn",
	"res://scenes/modules/rigging/RiggingDemo.tscn",
	"res://scenes/modules/level/LevelDemo.tscn",
	"res://scenes/modules/programming/ProgrammingDemo.tscn",
]

const FRAMES_PER_DEMO := 12
const UI_THEME_PATH := "res://assets/themes/cyber_theme.tres"
const REQUIRED_AUTOLOADS: PackedStringArray = [
	"EventBus",
	"GameDB",
	"Settings",
	"RunStats",
	"CombatFeedback",
	"MetaProgress",
	"AudioManager",
	"InputManager",
	"ActiveSkillManager",
]

func _init() -> void:
	call_deferred("_run")

func _has_zh(text: String) -> bool:
	# Godot 的正则不支持 \uXXXX；这里直接按 Unicode 范围判断。
	for i in text.length():
		var c := text.unicode_at(i)
		if c >= 0x4E00 and c <= 0x9FFF:
			return true
	return false

func _has_long_en(text: String) -> bool:
	var re := RegEx.new()
	re.compile("[A-Za-z]{2,}")
	return re.search(text) != null

func _validate_ui_demo(inst: Node) -> bool:
	# 1) 主题资源必须能加载（项目默认主题就是它）
	var theme_res := ResourceLoader.load(UI_THEME_PATH)
	if theme_res == null:
		push_error("validate_modules: UI 主题加载失败 " + UI_THEME_PATH)
		return false

	# 2) 关键节点存在
	var title := inst.get_node_or_null("Center/Panel/VBox/Title") as Label
	var desc := inst.get_node_or_null("Center/Panel/VBox/Desc") as Label
	var ok_btn := inst.get_node_or_null("Center/Panel/VBox/ButtonRow/Primary") as Button
	var note_info := inst.get_node_or_null("Center/Panel/VBox/Notifications/NoteRow/Info/Label") as Label
	var note_warn := inst.get_node_or_null("Center/Panel/VBox/Notifications/NoteRow/Warn/Label") as Label
	var note_ok := inst.get_node_or_null("Center/Panel/VBox/Notifications/NoteRow/Ok/Label") as Label
	if title == null or desc == null or ok_btn == null or note_info == null or note_warn == null or note_ok == null:
		push_error("validate_modules: 界面演示关键节点缺失")
		return false

	# 3) 玩家可见文案：必须含中文，且不出现连续英文（缩写/资源路径除外，此处严格一点防回归）
	var texts := [
		title.text,
		desc.text,
		ok_btn.text,
		note_info.text,
		note_warn.text,
		note_ok.text,
	]
	for t in texts:
		if not _has_zh(t):
			push_error("validate_modules: 文案缺少中文：" + t)
			return false
		if _has_long_en(t):
			push_error("validate_modules: 文案含连续英文：" + t)
			return false
	return true

func _validate_sfx_demo(inst: Node) -> bool:
	var title := inst.get_node_or_null("Center/Panel/VBox/Title") as Label
	var desc := inst.get_node_or_null("Center/Panel/VBox/Desc") as Label
	var slider := inst.get_node_or_null("Center/Panel/VBox/VolumeRow/Volume") as HSlider
	var btn := inst.get_node_or_null("Center/Panel/VBox/Buttons/BtnHit") as Button
	if title == null or desc == null or slider == null or btn == null:
		push_error("validate_modules: 音效演示关键节点缺失")
		return false
	if not _has_zh(title.text) or not _has_zh(desc.text) or _has_long_en(title.text):
		push_error("validate_modules: 音效演示文案不符合中文规范")
		return false
	if inst.has_method("module_self_test"):
		var ok := bool(inst.call("module_self_test"))
		if not ok:
			push_error("validate_modules: 音效演示自检失败")
			return false
	return true

func _validate_vfx_demo(inst: Node) -> bool:
	var title := inst.get_node_or_null("CanvasLayer/Center/Panel/VBox/Title") as Label
	var desc := inst.get_node_or_null("CanvasLayer/Center/Panel/VBox/Desc") as Label
	var amount := inst.get_node_or_null("CanvasLayer/Center/Panel/VBox/RowAmount/Amount") as HSlider
	var reduce := inst.get_node_or_null("CanvasLayer/Center/Panel/VBox/RowToggles/Reduce") as CheckBox
	var profile := inst.get_node_or_null("CanvasLayer/Center/Panel/VBox/RowProfile/Profile") as OptionButton
	if title == null or desc == null or amount == null or reduce == null or profile == null:
		push_error("validate_modules: 特效演示关键节点缺失")
		return false
	if not _has_zh(title.text) or not _has_zh(desc.text) or _has_long_en(title.text):
		push_error("validate_modules: 特效演示文案不符合中文规范")
		return false
	if inst.has_method("module_self_test"):
		var ok := bool(inst.call("module_self_test"))
		if not ok:
			push_error("validate_modules: 特效演示自检失败")
			return false
	return true

func _validate_programming_demo(inst: Node) -> bool:
	var title := inst.get_node_or_null("CanvasLayer/Panel/VBox/Label") as Label
	if title == null:
		push_error("validate_modules: 程序演示关键节点缺失（标题）")
		return false
	if not _has_zh(title.text) or _has_long_en(title.text):
		push_error("validate_modules: 程序演示标题文案不符合中文规范")
		return false
	if inst.has_method("module_self_test"):
		var ok := bool(inst.call("module_self_test"))
		if not ok:
			push_error("validate_modules: 程序演示自检失败")
			return false
	return true

func _validate_skills_demo_pre(inst: Node) -> bool:
	var title := inst.get_node_or_null("CanvasLayer/Panel/VBox/Title") as Label
	var desc := inst.get_node_or_null("CanvasLayer/Panel/VBox/Desc") as Label
	if title == null or desc == null:
		push_error("validate_modules: 技能演示关键节点缺失")
		return false
	# 等待 _ready 把文案写进去：这里仍然要求最终文本是中文
	if not _has_zh(title.text) or not _has_zh(desc.text) or _has_long_en(title.text):
		push_error("validate_modules: 技能演示标题/描述不符合中文规范")
		return false
	if inst.has_method("module_self_test"):
		var ok := bool(inst.call("module_self_test"))
		if not ok:
			push_error("validate_modules: 技能演示自检失败")
			return false
	return true

func _validate_skills_demo_post() -> bool:
	# 多帧后检查：与正式战斗同路径 `Main/Game/Player` 应存在
	var pl := root.get_node_or_null("Main/Game/Player")
	if pl == null:
		push_error("validate_modules: 技能演示未正确创建 Main/Game/Player 路径")
		return false
	var am := root.get_node_or_null("/root/ActiveSkillManager")
	if am == null or not am.has_method("get_cooldown_ratio"):
		push_error("validate_modules: ActiveSkillManager 不可用或缺少 get_cooldown_ratio")
		return false
	var rr: float = float(am.call("get_cooldown_ratio"))
	rr = clampf(rr, 0.0, 1.0)
	if rr < 0.0 or rr > 1.0:
		push_error("validate_modules: 主动技能冷却比越界")
		return false
	return true

func _validate_rigging_demo_pre(inst: Node) -> bool:
	var title := inst.get_node_or_null("CanvasLayer/Panel/VBox/Title") as Label
	var desc := inst.get_node_or_null("CanvasLayer/Panel/VBox/Desc") as Label
	if title == null or desc == null:
		push_error("validate_modules: 骨骼演示关键节点缺失")
		return false
	if not _has_zh(title.text) or not _has_zh(desc.text) or _has_long_en(title.text):
		push_error("validate_modules: 骨骼演示标题/描述不符合中文规范")
		return false
	return true

func _validate_rigging_demo_post(inst: Node) -> bool:
	if inst.has_method("module_self_test"):
		var ok := bool(inst.call("module_self_test"))
		if not ok:
			push_error("validate_modules: 骨骼演示自检失败")
			return false
	return true

func _validate_animation_demo_pre(inst: Node) -> bool:
	var title := inst.get_node_or_null("CanvasLayer/Panel/VBox/Title") as Label
	var desc := inst.get_node_or_null("CanvasLayer/Panel/VBox/Desc") as Label
	if title == null or desc == null:
		push_error("validate_modules: 动作演示关键节点缺失")
		return false
	if not _has_zh(title.text) or not _has_zh(desc.text) or _has_long_en(title.text):
		push_error("validate_modules: 动作演示标题/描述不符合中文规范")
		return false
	return true

func _validate_animation_demo_post(inst: Node) -> bool:
	if inst.has_method("module_self_test"):
		var ok := bool(inst.call("module_self_test"))
		if not ok:
			push_error("validate_modules: 动作演示自检失败")
			return false
	return true

func _validate_level_demo_pre(inst: Node) -> bool:
	var title := inst.get_node_or_null("CanvasLayer/Panel/VBox/Title") as Label
	var desc := inst.get_node_or_null("CanvasLayer/Panel/VBox/Desc") as Label
	if title == null or desc == null:
		push_error("validate_modules: 地编演示关键节点缺失")
		return false
	if not _has_zh(title.text) or not _has_zh(desc.text) or _has_long_en(title.text):
		push_error("validate_modules: 地编演示标题/描述不符合中文规范")
		return false
	return true


func _validate_art_demo_pre(inst: Node) -> bool:
	var title := inst.get_node_or_null("CanvasLayer/Panel/VBox/Title") as Label
	var desc := inst.get_node_or_null("CanvasLayer/Panel/VBox/Desc") as Label
	if title == null or desc == null:
		push_error("validate_modules: 原画演示关键节点缺失")
		return false
	if not _has_zh(title.text) or not _has_zh(desc.text) or _has_long_en(title.text):
		push_error("validate_modules: 原画演示标题/描述不符合中文规范")
		return false
	if inst.has_method("module_self_test"):
		var ok := bool(inst.call("module_self_test"))
		if not ok:
			push_error("validate_modules: 原画演示自检失败")
			return false
	return true


func _validate_modeling_demo_pre(inst: Node) -> bool:
	var title := inst.get_node_or_null("CanvasLayer/Panel/VBox/Title") as Label
	var desc := inst.get_node_or_null("CanvasLayer/Panel/VBox/Desc") as Label
	if title == null or desc == null:
		push_error("validate_modules: 建模演示关键节点缺失")
		return false
	if not _has_zh(title.text) or not _has_zh(desc.text) or _has_long_en(title.text):
		push_error("validate_modules: 建模演示标题/描述不符合中文规范")
		return false
	if inst.has_method("module_self_test"):
		var ok := bool(inst.call("module_self_test"))
		if not ok:
			push_error("validate_modules: 建模演示自检失败")
			return false
	return true

func _validate_level_demo_post(inst: Node) -> bool:
	if inst.has_method("module_self_test"):
		var ok := bool(inst.call("module_self_test"))
		if not ok:
			push_error("validate_modules: 地编演示自检失败")
			return false
	return true

func _frames_for(path: String) -> int:
	# 主动技能管理器在 game_started 后走 deferred 绑定，给技能演示更多稳定帧
	if path == "res://scenes/modules/skills/SkillsDemo.tscn":
		return 32
	# 白盒试验场：复用正式 Game，允许多帧稳定 HUD/技能绑定
	if path == "res://scenes/modules/skills/SkillsWhitebox.tscn":
		return 40
	# 骨骼演示：deferred 绑定躯体骨架后再自检
	if path == "res://scenes/modules/rigging/RiggingDemo.tscn":
		return 20
	# 动作演示：deferred 绑定躯体骨架后再自检
	if path == "res://scenes/modules/animation/AnimationDemo.tscn":
		return 20
	# 地编：导航烘焙 + 代理路径需要多帧稳定
	if path == "res://scenes/modules/level/LevelDemo.tscn":
		return 45
	return FRAMES_PER_DEMO

func _load_scene(path: String) -> PackedScene:
	var res: Resource = ResourceLoader.load(path)
	if res == null or not (res is PackedScene):
		return null
	return res as PackedScene

func _validate_required_autoloads() -> bool:
	for nm in REQUIRED_AUTOLOADS:
		if root.get_node_or_null("/root/" + nm) == null:
			push_error("validate_modules: 缺少 autoload " + nm)
			return false
	return true

func _run() -> void:
	if not _validate_required_autoloads():
		quit(1)
		return
	for p in DEMO_SCENES:
		var packed := _load_scene(p)
		if packed == null:
			push_error("validate_modules: failed to load " + p)
			quit(1)
			return
		var inst := packed.instantiate()
		root.add_child(inst)
		if p == "res://scenes/modules/vfx/VFXDemo.tscn":
			if not _validate_vfx_demo(inst):
				quit(1)
				return
		if p == "res://scenes/modules/sfx/SFXDemo.tscn":
			if not _validate_sfx_demo(inst):
				quit(1)
				return
		if p == "res://scenes/modules/ui/UIDemo.tscn":
			if not _validate_ui_demo(inst):
				quit(1)
				return
		if p == "res://scenes/modules/art/ArtDemo.tscn":
			if not _validate_art_demo_pre(inst):
				quit(1)
				return
		if p == "res://scenes/modules/programming/ProgrammingDemo.tscn":
			if not _validate_programming_demo(inst):
				quit(1)
				return
		if p == "res://scenes/modules/skills/SkillsDemo.tscn":
			if not _validate_skills_demo_pre(inst):
				quit(1)
				return
		if p == "res://scenes/modules/rigging/RiggingDemo.tscn":
			if not _validate_rigging_demo_pre(inst):
				quit(1)
				return
		if p == "res://scenes/modules/animation/AnimationDemo.tscn":
			if not _validate_animation_demo_pre(inst):
				quit(1)
				return
		if p == "res://scenes/modules/modeling/ModelingDemo.tscn":
			if not _validate_modeling_demo_pre(inst):
				quit(1)
				return
		if p == "res://scenes/modules/level/LevelDemo.tscn":
			if not _validate_level_demo_pre(inst):
				quit(1)
				return
		var frames: int = _frames_for(p)
		for _i in frames:
			await process_frame
		if p == "res://scenes/modules/skills/SkillsDemo.tscn":
			if not _validate_skills_demo_post():
				quit(1)
				return
		if p == "res://scenes/modules/rigging/RiggingDemo.tscn":
			if not _validate_rigging_demo_post(inst):
				quit(1)
				return
		if p == "res://scenes/modules/animation/AnimationDemo.tscn":
			if not _validate_animation_demo_post(inst):
				quit(1)
				return
		if p == "res://scenes/modules/level/LevelDemo.tscn":
			if not _validate_level_demo_post(inst):
				quit(1)
				return
		inst.queue_free()
		await process_frame
	print("validate_modules: OK %d demos" % DEMO_SCENES.size())
	quit(0)

