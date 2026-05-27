extends Control
class_name ResultPanel

# 结果面板控制器 - 管理游戏结束后统计数据的显示

signal restart_pressed
signal menu_pressed

@onready var title_icon: Label = $MainPanel/TitleContainer/TitleIcon
@onready var title_label: Label = $MainPanel/TitleContainer/TitleLabel
@onready var time_label: Label = $MainPanel/StatsContainer/LeftStats/TimePanel/TimeLabel
@onready var time_sub_label: Label = $MainPanel/StatsContainer/LeftStats/TimePanel/TimeSubLabel
@onready var kill_label: Label = $MainPanel/StatsContainer/LeftStats/KillPanel/KillLabel
@onready var kill_sub_label: Label = $MainPanel/StatsContainer/LeftStats/KillPanel/KillSubLabel
@onready var damage_label: Label = $MainPanel/StatsContainer/LeftStats/DamagePanel/DamageLabel
@onready var boss_info: Label = $MainPanel/StatsContainer/RightStats/BossInfo
@onready var top_kill: Label = $MainPanel/StatsContainer/RightStats/TopKill
@onready var build_line: Label = $MainPanel/StatsContainer/RightStats/BuildLine
@onready var damage_source: Label = $MainPanel/StatsContainer/RightStats/DamageSource
@onready var fusion_info: Label = $MainPanel/StatsContainer/RightStats/FusionInfo
@onready var diagnosis_line: Label = $MainPanel/StatsContainer/RightStats/DiagnosisLine
@onready var recap_line: Label = $MainPanel/StatsContainer/RightStats/RecapLine
@onready var restart_btn: Button = $MainPanel/ButtonContainer/RestartButton
@onready var menu_btn: Button = $MainPanel/ButtonContainer/MenuButton

var _is_win := false

func _ready() -> void:
	restart_btn.pressed.connect(func(): restart_pressed.emit())
	menu_btn.pressed.connect(func(): menu_pressed.emit())
	visible = false

func show_result(data: Dictionary, is_win: bool) -> void:
	_is_win = is_win
	visible = true
	
	# 设置标题
	if is_win:
		title_icon.text = "🏆"
		title_label.text = "胜利"
		title_label.theme_type_variation = &"Label.Result.Win"
	else:
		title_icon.text = "💀"
		title_label.text = "游戏结束"
		title_label.theme_type_variation = &"Label.Result.Lose"
	
	# 设置统计数据
	var rt: int = int(data.get("runtime_sec", 0))
	var mins: int = rt / 60
	var secs: int = rt % 60
	time_label.text = "%02d:%02d" % [mins, secs]
	time_sub_label.text = "生存时间"
	
	var kills: int = int(data.get("kills", 0))
	var kpm: float = float(data.get("kpm", 0.0))
	kill_label.text = str(kills)
	kill_sub_label.text = "击杀敌人  KPM: %.1f" % kpm
	
	damage_label.text = "%d" % int(data.get("damage_total", 0))
	
	# 右侧详细统计
	boss_info.text = data.get("boss_line", "BOSS: 未出现")
	top_kill.text = data.get("top_line", "击杀最多: -")
	build_line.text = data.get("build_line", "构筑推荐: -")
	damage_source.text = data.get("dmg_line", "伤害来源: -")
	fusion_info.text = "融合次数: %d  融合伤害: %.1f%%" % [
		data.get("fusions", 0),
		data.get("fusion_ratio", 0.0) * 100.0
	]
	diagnosis_line.text = data.get("diagnosis", "诊断: 构筑均衡")
	var recap: String = String(data.get("recap_line", ""))
	var flow_line: String = String(data.get("flow_line", ""))
	var unlock_line: String = String(data.get("unlock_line", ""))
	var scrap_delta: int = int(data.get("scrap_delta", 0))
	var scrap_total: int = int(data.get("scrap_total", 0))
	var relic_line: String = String(data.get("relic_line", ""))
	if recap_line:
		var chunks: Array[String] = []
		if not relic_line.is_empty():
			chunks.append(relic_line)
		if scrap_delta != 0 or scrap_total > 0:
			chunks.append("战备碎片 +%d（持有 %d）" % [scrap_delta, scrap_total])
		if not unlock_line.is_empty():
			chunks.append("解锁 · " + unlock_line)
		if not recap.is_empty():
			chunks.append("复盘 · " + recap)
		if not flow_line.is_empty():
			chunks.append(flow_line)
		if chunks.is_empty():
			recap_line.visible = false
		else:
			recap_line.visible = true
			recap_line.text = "\n".join(chunks)

	# 面板滑入
	var tween := create_tween().set_trans(UIMotion.TRANS_ENTRANCE).set_ease(UIMotion.EASE_OUT)
	var main_panel := $MainPanel
	var orig_pos: Vector2 = main_panel.position
	main_panel.position.y -= 50
	tween.tween_property(main_panel, "position:y", orig_pos.y, UIMotion.MOTION_PANEL)

func hide_result() -> void:
	visible = false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		restart_pressed.emit()
	elif event.is_action_pressed("ui_cancel"):
		menu_pressed.emit()
