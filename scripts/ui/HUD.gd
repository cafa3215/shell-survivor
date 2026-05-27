extends CanvasLayer
class_name HUD

# HUD_new.tscn 节点引用（canonical 布局）
@onready var hp_label: Label = $Root/TopBar/VBox/Row1/HpLabel
@onready var lv_label: Label = $Root/TopBar/VBox/Row1/LevelLabel
@onready var time_label: Label = $Root/TopBar/VBox/Row1/TimeLabel
@onready var fps_label: Label = $Root/TopBar/VBox/Row1/FpsLabel
@onready var enemy_icon: Label = $Root/TopBar/VBox/Row3/EnemyIcon
@onready var enemy_label: Label = $Root/TopBar/VBox/Row3/EnemyLabel
@onready var xp_label: Label = $Root/TopBar/VBox/Row3/XpLabel
@onready var joy_root: Control = $Root/JoystickRoot
@onready var joy_knob: Panel = $Root/JoystickRoot/Knob
@onready var aim_zone: Control = $Root/AimZone
@onready var boss_warn: Panel = $Root/BossWarn
@onready var damage_flash: Panel = $Root/DamageFlash
@onready var equip_btn: Button = $Root/EquipButton
@onready var dash_btn: Button = $Root/DashButton
@onready var pause_btn: Button = $Root/PauseButton
@onready var endless_badge: PanelContainer = $Root/EndlessBadge
@onready var extraction_alert: PanelContainer = $Root/ExtractionAlert
@onready var extraction_label: Label = $Root/ExtractionAlert/Label
@onready var active_skill_panel: PanelContainer = $Root/ActiveSkillPanel
@onready var active_skill_cd: ProgressBar = $Root/ActiveSkillPanel/VBox/CooldownBar
@onready var active_skill_hint: Label = $Root/ActiveSkillPanel/VBox/HintLabel
@onready var boss_container: PanelContainer = $Root/BossContainer
@onready var boss_label: Label = $Root/BossContainer/VBox/BossTitle/BossLabel
@onready var boss_phase: Label = $Root/BossContainer/VBox/BossTitle/BossPhase
@onready var boss_hp_percent: Label = $Root/BossContainer/VBox/BossTitle/BossHpPercent
@onready var boss_bar_bg: ProgressBar = $Root/BossContainer/VBox/BossBarBg
@onready var boss_bar_fill: ProgressBar = $Root/BossContainer/VBox/BossBarFill
@onready var boss_icon: Label = $Root/BossContainer/VBox/BossTitle/BossIcon
@onready var xp_bar_bg: ProgressBar = $Root/TopBar/VBox/Row3/XpBarBg
@onready var xp_bar_fill: ProgressBar = $Root/TopBar/VBox/Row3/XpBarFill
@onready var threat_edge: Control = $Root/ThreatEdge
@onready var relic_row: Control = $Root/TopBar/VBox/RelicRow
@onready var relic_label: Label = $Root/TopBar/VBox/RelicRow/RelicLabel
var _archetype_label: Label = null

@onready var perf_label: Label = $Root/PerfLabel

var _hp_flash := 0.0

var _touch_id := -1
var _aim_touch_id := -1
var _joy_radius := 68.0
const _JOY_DEADZONE_RATIO := 0.18
var _aim_vec := Vector2.ZERO
var _aim_deadzone := 0.16
var _aim_snap_strength := 0.35
var _aim_release_damp := 0.85
var _director_mul := 1.0
var _xp_mul := 1.0
var _pressure_relief_ratio := 0.0
var _boss_alive := false
var _boss_ratio := 0.0
var _boss_phase := 0
var _hp_ratio := 1.0
var _equip_panel_open := false
var _hud_perf_tick := 0
var _vfx_profile_tip: Label = null
var _vfx_tip_tween: Tween = null
var _damage_toggle_btn: Button = null
var _damage_panel: PanelContainer = null
var _damage_body: VBoxContainer = null
var _damage_title: Label = null
var _damage_main_label: Label = null
var _damage_total_label: Label = null
var _damage_rows: Array[Label] = []
var _skill_eff_title: Label = null
var _skill_eff_rows: Array[Label] = []
var _skill_eff_hint: Label = null
var _skill_eff_hotkey_hint: Label = null
var _skill_eff_snapshot_status: Label = null
var _damage_panel_expanded := true
var _damage_refresh_tick := 0.0
var _damage_mode := 0 # 0=总伤害, 1=首领伤害
var _damage_mode_btn: Button = null
var _damage_trend_samples: Array[Dictionary] = []
var _combat_evt_label: Label = null
var _combat_last_skill_id: String = "-"
var _combat_last_cast_seq := 0
var _combat_last_hit_count := 0
var _combat_last_evt: String = "-"
var _combat_last_evt_ts := 0
var _combat_evt_history: Array[String] = []
var _combat_filter_current_cast := true
var _combat_focus_cast_seq := 0
var _combat_cast_start_ts := 0
var _combat_cast_hit_count := 0
var _skill_eff_recent_mode := false
var _skill_eff_mode_btn: Button = null
var _skill_eff_sort_mode := "casts"
var _skill_eff_sort_btn: Button = null
var _skill_eff_min_casts := 3
var _skill_eff_min_casts_btn: Button = null
var _skill_eff_preset_btn: Button = null
var _skill_eff_new_batch_btn: Button = null
var _skill_eff_batch_only := false
var _skill_eff_batch_btn: Button = null
var _skill_eff_export_btn: Button = null
var _skill_eff_compare_btn: Button = null
var _skill_eff_clear_btn: Button = null
var _last_eff_snapshot: Dictionary = {}
var _prev_eff_snapshot: Dictionary = {}
var _balance_batch_id := ""
var _balance_batch_start_ms := 0
var _balance_batch_start_unix := 0
const _HUD_SKILL_EFF_CONFIG_PATH := "res://assets/config/hud_skill_efficiency.json"
const _HUD_SKILL_EFF_DEFAULT_CFG := {
	"overpower_efficiency_ratio": 1.8,
	"default_min_casts": 3
}
var _hud_skill_eff_cfg: Dictionary = {}
const _HUD_DAMAGE_PANEL_CONFIG_PATH := "res://assets/config/hud_damage_panel.json"
const _WEAPON_CARRIER_CONFIG_PATH := "res://assets/config/weapon_carrier_cards.json"
const _HUD_DAMAGE_PANEL_DEFAULT_CFG := {
	"trend_up_delta": 120.0,
	"trend_down_delta": 35.0,
	"trend_window_sec": 10.0,
	"trend_keep_sec": 12.0,
	"color_up": [0.56, 1.0, 0.72, 1.0],
	"color_flat": [1.0, 0.84, 0.44, 1.0],
	"color_down": [1.0, 0.46, 0.46, 1.0]
}
var _hud_damage_cfg: Dictionary = {}
var _relic_hud_tick := 0
var _weapon_carrier_defs: Dictionary = {}
var _weapon_carrier_panel: PanelContainer = null
var _weapon_carrier_grid: GridContainer = null
var _weapon_card_items: Array[Dictionary] = []
var _weapon_card_fx_t := 0.0

func _process(delta: float) -> void:
	_update_damage_panel(delta)
	_update_weapon_carrier_fx(delta)
	_hud_perf_tick += 1
	_relic_hud_tick += 1
	if _relic_hud_tick % 8 == 0:
		_refresh_relic_hud_line()
	var dbg := Settings.debug_hud
	if fps_label:
		fps_label.visible = dbg
	if perf_label:
		perf_label.visible = dbg
	if dbg and fps_label and _hud_perf_tick % 10 == 0:
		fps_label.text = "帧率: %d" % Engine.get_frames_per_second()
	if _aim_touch_id == -1:
		_aim_vec *= _aim_release_damp
		if _aim_vec.length() < 0.02:
			_aim_vec = Vector2.ZERO
			InputManager.set_aim_vector(Vector2.ZERO, false, 0.0)
		else:
			InputManager.set_aim_vector(_aim_vec, true, clampf(_aim_vec.length(), 0.0, 1.0))
	var game := get_parent()
	if dbg and perf_label and _hud_perf_tick % 15 == 0 and game != null and game.has_node("EnemyManager"):
		var em := game.get_node("EnemyManager")
		perf_label.text = "活跃:%d  桶:%d  池:%d  方向:%.2f  经验:%.2f" % [
			int(em.debug_active_count()),
			int(em.debug_bucket_count()),
			int(em.debug_pool_used()),
			_director_mul,
			_xp_mul
		]
	if _boss_alive:
		if boss_container and boss_phase and boss_hp_percent and boss_bar_fill:
			if boss_label:
				boss_label.text = "首领"
			boss_phase.text = "阶段 %d" % _boss_phase
			boss_hp_percent.text = "%d%%" % int(round(_boss_ratio * 100.0))
			boss_bar_fill.value = _boss_ratio * 100.0
			boss_container.visible = true
	else:
		if boss_container:
			boss_container.visible = false
	# 低血量红晕（压低上限，避免挡视野；成品 UI 更偏「提示」而非「糊屏」）
	var low_hp_alpha := clampf((0.35 - _hp_ratio) * 0.32, 0.0, 0.1)
	damage_flash.visible = low_hp_alpha > 0.0
	if threat_edge:
		threat_edge.visible = (not dbg) and Settings.high_contrast_targets
	if _combat_evt_label:
		_combat_evt_label.visible = dbg

func set_hp(hp: float, max_hp: float) -> void:
	if hp_label:
		hp_label.text = "%d / %d" % [int(hp), int(max_hp)]
	_hp_ratio = clampf(hp / max(max_hp, 1.0), 0.0, 1.0)
	
	# 更新新版血条 (TopBar内的结构)
	var root_top_bar = $Root/TopBar
	if root_top_bar:
		var hp_bar_row = root_top_bar.get_node_or_null("VBox/HpBarRow")
		if hp_bar_row:
			var fill = hp_bar_row.get_node_or_null("HpBarFill") as ProgressBar
			var inner = hp_bar_row.get_node_or_null("HpBarInner") as ProgressBar
			if fill:
				fill.value = _hp_ratio * 100.0
				fill.theme_type_variation = _hp_bar_variation(_hp_ratio)
				hp_bar_row.theme_type_variation = _hp_bar_variation(_hp_ratio)
			if inner:
				inner.value = _hp_ratio * 100.0

func set_level(lv: int) -> void:
	if lv_label:
		lv_label.text = "等级%d" % lv

func set_runtime(sec: int) -> void:
	var m := sec / 60
	var s := sec % 60
	if time_label:
		time_label.text = "%02d:%02d" % [m, s]
		# 添加工具提示显示完整时间
		time_label.tooltip_text = "游戏时间: %d分%d秒" % [m, s]

func set_enemy_count(n: int) -> void:
	if enemy_label:
		enemy_label.text = "%d" % n

func set_director_info(director_mul: float, xp_mul: float, elapsed_sec: float = 0.0, boss_alive: bool = false, relief_ratio: float = 0.0) -> void:
	_director_mul = director_mul
	_xp_mul = xp_mul
	_pressure_relief_ratio = clampf(relief_ratio, 0.0, 1.0)
	# R4：非调试时隐藏「敌数」微信息，减压；高压或 BOSS 时再显示
	var show_counts := Settings.debug_hud or boss_alive or elapsed_sec > 80.0 or director_mul > 1.1
	# 回稳时进一步降噪：非高压且非BOSS时收起敌数
	if _pressure_relief_ratio > 0.45 and not boss_alive and director_mul < 1.32:
		show_counts = false
	if enemy_icon:
		enemy_icon.visible = show_counts
	if enemy_label:
		enemy_label.visible = show_counts

func set_boss_info(alive: bool, hp_ratio: float, phase: int) -> void:
	_boss_alive = alive
	_boss_ratio = hp_ratio
	_boss_phase = phase

func set_xp(current_xp: int, needed: int) -> void:
	if xp_label:
		xp_label.text = "%d / %d" % [current_xp, needed]
	
	# 更新新版XP条
	var root_top_bar = $Root/TopBar
	if root_top_bar:
		var row3 = root_top_bar.get_node_or_null("VBox/Row3")
		if row3:
			var fill = row3.get_node_or_null("XpBarFill") as ProgressBar
			if fill:
				var ratio = float(current_xp) / maxf(float(needed), 1.0)
				fill.value = ratio * 100.0

func set_endless(endless: bool) -> void:
	if endless_badge:
		endless_badge.visible = endless

## 撤离前警报：remaining_sec 为剩余秒数（1–60）；≤0 或 >60 时隐藏
func set_extraction_countdown(remaining_sec: int) -> void:
	if extraction_alert == null or extraction_label == null:
		return
	if remaining_sec <= 0 or remaining_sec > GameDB.EXTRACTION_ALERT_BEFORE_SEC:
		extraction_alert.visible = false
		_apply_time_state(false)
		return
	extraction_alert.visible = true
	var m: int = remaining_sec / 60
	var s: int = remaining_sec % 60
	extraction_label.text = "撤离信号  %02d:%02d" % [m, s]
	_apply_time_state(true)


func _refresh_relic_hud_line() -> void:
	if relic_label == null:
		return
	_ensure_archetype_label()
	var g := get_parent()
	if g != null and g.has_method("get_hud_relic_line_text"):
		var archetype_text := ""
		if g.has_method("get_hud_archetype_line_text"):
			archetype_text = String(g.call("get_hud_archetype_line_text"))
		_refresh_archetype_hud_line(archetype_text)
		var t := ""
		var relic_text: String = String(g.call("get_hud_relic_line_text"))
		if not relic_text.is_empty():
			t = relic_text
		if g.has_method("get_curse_hud_hint"):
			var ch := String(g.call("get_curse_hud_hint"))
			if not ch.is_empty():
				t = t + ("\n" + ch) if not t.is_empty() else ch
		relic_label.text = t
		if relic_row:
			var show_archetype := _archetype_label != null and not _archetype_label.text.is_empty()
			relic_row.visible = show_archetype or not t.is_empty()
	elif relic_row:
		_refresh_archetype_hud_line("")
		relic_row.visible = false


func _ensure_archetype_label() -> void:
	if relic_row == null or _archetype_label != null:
		return
	_archetype_label = Label.new()
	_archetype_label.name = "ArchetypeLabelRuntime"
	_archetype_label.theme_type_variation = &"LabelMeta"
	_archetype_label.visible = false
	relic_row.add_child(_archetype_label)
	relic_row.move_child(_archetype_label, 0)


func _refresh_archetype_hud_line(archetype_text: String) -> void:
	if _archetype_label == null:
		return
	_archetype_label.text = archetype_text
	_archetype_label.visible = not archetype_text.is_empty()
	if archetype_text.begins_with("专精：突击"):
		_archetype_label.modulate = Color(0.35, 0.94, 1.0, 1.0)
	elif archetype_text.begins_with("专精：守护"):
		_archetype_label.modulate = Color(0.45, 0.72, 1.0, 1.0)
	elif archetype_text.begins_with("专精：猎杀"):
		_archetype_label.modulate = Color(1.0, 0.48, 0.48, 1.0)
	else:
		_archetype_label.modulate = Color(0.86, 0.9, 0.95, 1.0)

func _ready() -> void:
	InputManager.set_hud_move_joystick_owner(true)
	InputManager.set_aim_mode(InputManager.AimMode.AUTO)
	InputManager.auto_fire = true
	InputManager.set_move_joystick_anchor_follow(0.32)
	EventBus.boss_warning.connect(_on_boss_warning)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.vfx_profile_changed.connect(_show_vfx_profile_tip)
	EventBus.extreme_perf_guard_changed.connect(_show_extreme_perf_guard_tip)
	EventBus.skill_cast_start.connect(_on_skill_cast_start)
	EventBus.skill_active.connect(_on_skill_active)
	EventBus.skill_hit.connect(_on_skill_hit)
	EventBus.skill_end.connect(_on_skill_end)
	if joy_root:
		joy_root.resized.connect(_sync_move_joystick_zone)
	var vp := get_viewport()
	if vp:
		vp.size_changed.connect(_sync_move_joystick_zone)
	call_deferred("_sync_move_joystick_zone")
	call_deferred("_apply_safe_area_margins")
	if fps_label:
		fps_label.theme_type_variation = &"Label.Meta"
		fps_label.visible = Settings.debug_hud
	if perf_label:
		perf_label.visible = Settings.debug_hud
		perf_label.tooltip_text = GameDB.PERF_STRESS_HINT
	# 装备面板按钮
	if equip_btn:
		equip_btn.pressed.connect(_toggle_equip_panel)
	if dash_btn:
		dash_btn.pressed.connect(func() -> void:
			EventBus.dash_requested.emit()
		)
	if pause_btn:
		pause_btn.pressed.connect(func() -> void:
			EventBus.toggle_pause_requested.emit()
		)
	_setup_vfx_profile_tip()
	_setup_damage_panel()
	_setup_weapon_carrier_panel()
	_setup_combat_event_debug_label()
	_update_mobile_action_buttons()
	var asm := get_node_or_null("/root/ActiveSkillManager")
	if asm and asm.has_signal("cooldown_visual_changed") and not asm.cooldown_visual_changed.is_connected(_on_active_skill_hud):
		asm.cooldown_visual_changed.connect(_on_active_skill_hud)
	call_deferred("_refresh_relic_hud_line")


func _on_active_skill_hud(remaining_sec: float, total_sec: float, aiming: bool) -> void:
	if active_skill_cd:
		var t := maxf(0.001, total_sec)
		var ready_ratio := 1.0 - clampf(remaining_sec / t, 0.0, 1.0)
		active_skill_cd.value = ready_ratio * 100.0
	if active_skill_hint:
		if remaining_sec > 0.05:
			active_skill_hint.text = "主动 %.1f秒" % remaining_sec
		else:
			active_skill_hint.text = "主动 就绪" if not aiming else "主动 照射中…"
	if active_skill_panel:
		active_skill_panel.visible = true
		if aiming and active_skill_cd:
			active_skill_cd.modulate = Color(0.75, 1.0, 1.0, 1.0)
		elif active_skill_cd:
			active_skill_cd.modulate = Color.WHITE

func _setup_combat_event_debug_label() -> void:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	_combat_evt_label = Label.new()
	_combat_evt_label.name = "CombatEventDebug"
	_combat_evt_label.text = ""
	_combat_evt_label.theme_type_variation = &"Label.Meta"
	_combat_evt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combat_evt_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_combat_evt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_evt_label.visible = false
	_combat_evt_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_combat_evt_label.offset_left = -520.0
	_combat_evt_label.offset_top = 272.0
	_combat_evt_label.offset_right = -20.0
	_combat_evt_label.offset_bottom = 338.0
	root.add_child(_combat_evt_label)
	_refresh_combat_event_debug_label()


func _refresh_combat_event_debug_label() -> void:
	if _combat_evt_label == null:
		return
	var filter_mode := "当前序列" if _combat_filter_current_cast else "全部序列"
	var head := "战斗事件[%s]  技能:%s  序列:%d  命中:%d  最近:%s  时间:%d" % [
		filter_mode,
		_combat_last_skill_id,
		_combat_last_cast_seq,
		_combat_last_hit_count,
		_combat_last_evt,
		_combat_last_evt_ts
	]
	var body := ""
	if not _combat_evt_history.is_empty():
		body = "\n" + "\n".join(_combat_evt_history)
	_combat_evt_label.text = head + body


func _push_combat_evt_line(evt: String, skill_id: StringName, cast_seq: int, timestamp_ms: int, extra: String = "") -> void:
	if _combat_filter_current_cast and cast_seq != _combat_focus_cast_seq:
		return
	var line := "[%d] %s  %s#%d" % [timestamp_ms % 100000, evt, String(skill_id), cast_seq]
	if not extra.is_empty():
		line += "  " + extra
	_combat_evt_history.append(line)
	if _combat_evt_history.size() > 10:
		_combat_evt_history.pop_front()


func _on_skill_cast_start(skill_id: StringName, _caster_id: int, cast_seq: int, timestamp_ms: int) -> void:
	_combat_last_skill_id = String(skill_id)
	_combat_last_cast_seq = cast_seq
	_combat_focus_cast_seq = cast_seq
	_combat_last_hit_count = 0
	_combat_cast_hit_count = 0
	_combat_cast_start_ts = timestamp_ms
	_combat_last_evt = "cast_start"
	_combat_last_evt_ts = timestamp_ms
	# 新施法开始时，重置当前序列视图，避免保留上一轮噪声。
	_combat_evt_history.clear()
	_push_combat_evt_line("cast_start", skill_id, cast_seq, timestamp_ms)
	_refresh_combat_event_debug_label()


func _on_skill_active(skill_id: StringName, _caster_id: int, cast_seq: int, _frame_index: int, timestamp_ms: int) -> void:
	_combat_last_skill_id = String(skill_id)
	_combat_last_cast_seq = cast_seq
	_combat_last_evt = "active"
	_combat_last_evt_ts = timestamp_ms
	_push_combat_evt_line("active", skill_id, cast_seq, timestamp_ms)
	_refresh_combat_event_debug_label()


func _on_skill_hit(skill_id: StringName, _caster_id: int, _target_id: int, cast_seq: int, _damage_type: StringName, _final_damage: float, _is_critical: bool, timestamp_ms: int) -> void:
	_combat_last_skill_id = String(skill_id)
	_combat_last_cast_seq = cast_seq
	_combat_last_hit_count += 1
	_combat_cast_hit_count += 1
	_combat_last_evt = "hit"
	_combat_last_evt_ts = timestamp_ms
	_push_combat_evt_line("hit", skill_id, cast_seq, timestamp_ms, "x%d" % _combat_last_hit_count)
	_refresh_combat_event_debug_label()


func _on_skill_end(skill_id: StringName, _caster_id: int, cast_seq: int, _reason: StringName, timestamp_ms: int) -> void:
	_combat_last_skill_id = String(skill_id)
	_combat_last_cast_seq = cast_seq
	_combat_last_evt = "end"
	_combat_last_evt_ts = timestamp_ms
	var duration_ms := maxi(0, timestamp_ms - _combat_cast_start_ts)
	_push_combat_evt_line("end", skill_id, cast_seq, timestamp_ms)
	_push_combat_evt_line("summary", skill_id, cast_seq, timestamp_ms, "hits=%d  dur=%dms" % [_combat_cast_hit_count, duration_ms])
	_refresh_combat_event_debug_label()


func _toggle_combat_evt_filter_mode() -> void:
	_combat_filter_current_cast = not _combat_filter_current_cast
	_combat_evt_history.clear()
	_refresh_combat_event_debug_label()

func _setup_vfx_profile_tip() -> void:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	_vfx_profile_tip = Label.new()
	_vfx_profile_tip.name = "VfxProfileTip"
	_vfx_profile_tip.text = ""
	_vfx_profile_tip.theme_type_variation = &"Label.Meta"
	_vfx_profile_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_vfx_profile_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vfx_profile_tip.visible = false
	_vfx_profile_tip.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_vfx_profile_tip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_vfx_profile_tip.offset_left = -280.0
	_vfx_profile_tip.offset_top = 56.0
	_vfx_profile_tip.offset_right = -20.0
	_vfx_profile_tip.offset_bottom = 82.0
	root.add_child(_vfx_profile_tip)

func _show_vfx_profile_tip(profile: int) -> void:
	var label := "平衡默认"
	match profile:
		Settings.VfxProfile.COMPETITIVE:
			label = "竞技清晰"
		Settings.VfxProfile.CINEMATIC:
			label = "电影爽感"
		_:
			label = "平衡默认"
	_show_hud_tip("特效风格: %s" % label)

func _show_extreme_perf_guard_tip(enabled: bool) -> void:
	_show_hud_tip("高压性能保护: %s" % ("开" if enabled else "关"))

func _show_hud_tip(text: String) -> void:
	if _vfx_profile_tip == null:
		return
	_vfx_profile_tip.text = text
	_vfx_profile_tip.visible = true
	_vfx_profile_tip.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if _vfx_tip_tween != null and _vfx_tip_tween.is_valid():
		_vfx_tip_tween.kill()
	_vfx_tip_tween = create_tween().set_parallel(false)
	_vfx_tip_tween.tween_property(_vfx_profile_tip, "modulate:a", 1.0, 0.16)
	_vfx_tip_tween.tween_interval(1.7)
	_vfx_tip_tween.tween_property(_vfx_profile_tip, "modulate:a", 0.0, 0.22)
	_vfx_tip_tween.finished.connect(func() -> void:
		if _vfx_profile_tip:
			_vfx_profile_tip.visible = false
	)

func _apply_safe_area_margins() -> void:
	var tb := get_node_or_null("Root/TopBar") as Control
	if tb == null:
		return
	var safe := DisplayServer.get_display_safe_area()
	var top_inset := float(safe.position.y)
	if top_inset > 0.5:
		tb.offset_top = maxf(12.0, top_inset + 6.0)


func _sync_move_joystick_zone() -> void:
	if joy_root == null:
		return
	var vp := get_viewport()
	if vp:
		var screen_size := vp.get_visible_rect().size
		if InputManager.is_mobile() or DisplayServer.is_touchscreen_available():
			var joy_w := screen_size.x * 0.4
			var joy_h := screen_size.y * 0.4
			joy_root.offset_left = 16.0
			joy_root.offset_top = screen_size.y - joy_h - 16.0
			joy_root.offset_right = 16.0 + joy_w
			joy_root.offset_bottom = screen_size.y - 16.0
			if aim_zone:
				aim_zone.offset_left = screen_size.x * 0.55
				aim_zone.offset_top = screen_size.y * 0.5
				aim_zone.offset_right = screen_size.x - 16.0
				aim_zone.offset_bottom = screen_size.y - 16.0
	InputManager.configure_move_joystick(joy_root.get_global_rect(), _joy_radius)
	var show_joy := InputManager.is_mobile() or DisplayServer.is_touchscreen_available()
	joy_root.visible = show_joy
	if aim_zone:
		aim_zone.visible = show_joy
	if show_joy:
		_refresh_joystick_knob()
	_update_mobile_action_buttons()

func _update_mobile_action_buttons() -> void:
	var touch_ui := InputManager.is_mobile() or DisplayServer.is_touchscreen_available()
	if dash_btn:
		dash_btn.visible = touch_ui
	if pause_btn:
		pause_btn.visible = touch_ui

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_F8:
			_toggle_combat_evt_filter_mode()
			NotificationSystem.notify_message("战斗事件过滤: %s" % ("当前序列" if _combat_filter_current_cast else "全部序列"), 1.2, "info")
			get_viewport().set_input_as_handled()
			return
		if k.pressed and not k.echo and k.keycode == KEY_F7:
			_apply_skill_eff_experiment_preset()
			get_viewport().set_input_as_handled()
			return
		if k.pressed and not k.echo and k.keycode == KEY_F6:
			_export_skill_eff_snapshot()
			get_viewport().set_input_as_handled()
			return
		if k.pressed and not k.echo and k.keycode == KEY_F9:
			_compare_recent_eff_snapshots()
			get_viewport().set_input_as_handled()
			return
		if k.pressed and not k.echo and k.keycode == KEY_F10:
			_clear_balance_snapshots_log()
			get_viewport().set_input_as_handled()
			return
		if k.pressed and not k.echo and k.keycode == KEY_F11:
			_start_new_balance_batch()
			get_viewport().set_input_as_handled()
			return
	if joy_root == null or aim_zone == null:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed and _touch_id == -1 and joy_root.get_global_rect().has_point(e.position):
			_touch_id = e.index
			InputManager.move_joystick_touch_begin(e.position)
			InputManager.move_joystick_touch_drag(e.position, _JOY_DEADZONE_RATIO)
			_refresh_joystick_knob()
			get_viewport().set_input_as_handled()
		elif e.pressed and _aim_touch_id == -1 and aim_zone.get_global_rect().has_point(e.position):
			_aim_touch_id = e.index
			_update_aim(e.position - aim_zone.get_global_rect().get_center(), true)
		elif (not e.pressed) and e.index == _touch_id:
			_touch_id = -1
			InputManager.move_joystick_touch_end()
			_refresh_joystick_knob()
			get_viewport().set_input_as_handled()
		elif (not e.pressed) and e.index == _aim_touch_id:
			_aim_touch_id = -1
			_update_aim(Vector2.ZERO, false)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch_id:
			_update_joystick(d.position)
			get_viewport().set_input_as_handled()
		elif d.index == _aim_touch_id:
			_update_aim(d.position - aim_zone.get_global_rect().get_center(), true)

func _update_joystick(screen_pos: Vector2) -> void:
	InputManager.update_joystick_base(screen_pos, get_viewport().get_visible_rect().size)
	InputManager.move_joystick_touch_drag(screen_pos, _JOY_DEADZONE_RATIO)
	_refresh_joystick_knob()

func _refresh_joystick_knob() -> void:
	if joy_root == null or joy_knob == null:
		return
	var base_screen := InputManager.get_move_joystick_base_screen_pos()
	var half := joy_root.size * 0.5
	if base_screen != Vector2.ZERO:
		var local_base := joy_root.get_global_rect().position + half
		half += base_screen - local_base
	var off := InputManager.get_joystick_knob_offset_pixels(_joy_radius)
	joy_knob.position = half + off - joy_knob.size * 0.5

func _update_aim(v: Vector2, active: bool) -> void:
	var out := v
	if active:
		var len := out.length()
		if len < _aim_deadzone:
			out = Vector2.ZERO
		else:
			var dir: Vector2 = out / max(len, 0.001)
			var mag := clampf((len - _aim_deadzone) / 160.0, 0.0, 1.0)
			out = dir * mag
		_aim_vec = _aim_vec.lerp(out, _aim_snap_strength)
		if _aim_vec.length() > 0.02:
			InputManager.set_aim_vector(_aim_vec.normalized(), true, clampf(_aim_vec.length(), 0.0, 1.0))
		else:
			InputManager.set_aim_vector(Vector2.ZERO, false, 0.0)
	else:
		_aim_vec = Vector2.ZERO
		InputManager.set_aim_vector(Vector2.ZERO, false, 0.0)

func _on_boss_warning(strength: float, duration: float) -> void:
	boss_warn.visible = strength > 0.0
	boss_warn.theme_type_variation = &"PanelDanger" if strength >= 0.6 else &"PanelWarning"
	await get_tree().create_timer(UIMotion.quantize_duration(duration)).timeout
	boss_warn.visible = false

func _on_player_damaged(amount: float) -> void:
	var _burst := clampf(0.08 + amount * 0.008, 0.08, 0.22)
	damage_flash.visible = true
	damage_flash.theme_type_variation = &"PanelDanger"
	await get_tree().create_timer(UIMotion.MOTION_UI_FEEDBACK).timeout
	damage_flash.visible = false
	# 血条闪白
	_hp_flash = 1.0
	var tw2 := create_tween().set_trans(UIMotion.TRANS_SNAP).set_ease(UIMotion.EASE_SNAP)
	tw2.tween_property(self, "_hp_flash", 0.0, UIMotion.MOTION_UI_FEEDBACK)

func _hp_bar_variation(ratio: float) -> StringName:
	if ratio < 0.3:
		return &"Bar.HpLow"
	return &"Bar.Hp"

func _apply_time_state(is_alert: bool) -> void:
	if time_label == null:
		return
	time_label.theme_type_variation = &"Label.Alert" if is_alert else &"Label.Body"


func _setup_damage_panel() -> void:
	_load_hud_damage_panel_cfg()
	_load_hud_skill_eff_cfg()
	_skill_eff_min_casts = _cfg_int(_hud_skill_eff_cfg, "default_min_casts", 3)
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	_damage_toggle_btn = Button.new()
	_damage_toggle_btn.name = "DamageStatToggle"
	_damage_toggle_btn.text = "伤害统计 ▼"
	_damage_toggle_btn.theme_type_variation = &"ButtonSecondary"
	_damage_toggle_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_damage_toggle_btn.offset_left = -180.0
	_damage_toggle_btn.offset_top = 12.0
	_damage_toggle_btn.offset_right = -20.0
	_damage_toggle_btn.offset_bottom = 44.0
	_damage_toggle_btn.pressed.connect(_toggle_damage_panel)
	root.add_child(_damage_toggle_btn)

	_damage_panel = PanelContainer.new()
	_damage_panel.name = "DamageStatPanel"
	_damage_panel.theme_type_variation = &"PanelCard"
	_damage_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_damage_panel.offset_left = -360.0
	_damage_panel.offset_top = 52.0
	_damage_panel.offset_right = -20.0
	_damage_panel.offset_bottom = 260.0
	root.add_child(_damage_panel)

	var vb := VBoxContainer.new()
	vb.name = "Body"
	_damage_panel.add_child(vb)
	_damage_body = vb

	_damage_title = Label.new()
	_damage_title.text = "技能伤害统计"
	_damage_title.theme_type_variation = &"Label.Value"
	vb.add_child(_damage_title)

	_damage_main_label = Label.new()
	_damage_main_label.text = "主力输出：-"
	_damage_main_label.theme_type_variation = &"Label.Body"
	vb.add_child(_damage_main_label)

	_damage_total_label = Label.new()
	_damage_total_label.text = "总伤害：0"
	_damage_total_label.theme_type_variation = &"Label.Meta"
	vb.add_child(_damage_total_label)

	_damage_mode_btn = Button.new()
	_damage_mode_btn.text = "切换到首领伤害"
	_damage_mode_btn.theme_type_variation = &"ButtonSecondary"
	_damage_mode_btn.pressed.connect(_toggle_damage_mode)
	vb.add_child(_damage_mode_btn)

	_skill_eff_mode_btn = Button.new()
	_skill_eff_mode_btn.text = "效率榜: 总榜"
	_skill_eff_mode_btn.theme_type_variation = &"ButtonSecondary"
	_skill_eff_mode_btn.pressed.connect(_toggle_skill_eff_mode)
	vb.add_child(_skill_eff_mode_btn)

	_skill_eff_sort_btn = Button.new()
	_skill_eff_sort_btn.text = "排序: 施放"
	_skill_eff_sort_btn.theme_type_variation = &"ButtonSecondary"
	_skill_eff_sort_btn.pressed.connect(_toggle_skill_eff_sort_mode)
	vb.add_child(_skill_eff_sort_btn)

	_skill_eff_min_casts_btn = Button.new()
	_skill_eff_min_casts_btn.text = "样本: >=%d" % _skill_eff_min_casts
	_skill_eff_min_casts_btn.theme_type_variation = &"ButtonSecondary"
	_skill_eff_min_casts_btn.pressed.connect(_toggle_skill_eff_min_casts)
	vb.add_child(_skill_eff_min_casts_btn)

	_skill_eff_preset_btn = Button.new()
	_skill_eff_preset_btn.text = "实验模式一键设置"
	_skill_eff_preset_btn.theme_type_variation = &"ButtonSecondary"
	_skill_eff_preset_btn.pressed.connect(_apply_skill_eff_experiment_preset)
	vb.add_child(_skill_eff_preset_btn)

	_skill_eff_new_batch_btn = Button.new()
	_skill_eff_new_batch_btn.text = "开始新实验批次"
	_skill_eff_new_batch_btn.theme_type_variation = &"ButtonSecondary"
	_skill_eff_new_batch_btn.pressed.connect(_start_new_balance_batch)
	vb.add_child(_skill_eff_new_batch_btn)

	_skill_eff_batch_btn = Button.new()
	_skill_eff_batch_btn.text = "批次: 全部"
	_skill_eff_batch_btn.theme_type_variation = &"ButtonSecondary"
	_skill_eff_batch_btn.pressed.connect(_toggle_skill_eff_batch_only)
	vb.add_child(_skill_eff_batch_btn)

	_skill_eff_export_btn = Button.new()
	_skill_eff_export_btn.text = "导出效率快照"
	_skill_eff_export_btn.theme_type_variation = &"ButtonSecondary"
	_skill_eff_export_btn.pressed.connect(_export_skill_eff_snapshot)
	vb.add_child(_skill_eff_export_btn)

	_skill_eff_compare_btn = Button.new()
	_skill_eff_compare_btn.text = "对比最近两次"
	_skill_eff_compare_btn.theme_type_variation = &"ButtonSecondary"
	_skill_eff_compare_btn.pressed.connect(_compare_recent_eff_snapshots)
	vb.add_child(_skill_eff_compare_btn)

	_skill_eff_clear_btn = Button.new()
	_skill_eff_clear_btn.text = "清空快照日志"
	_skill_eff_clear_btn.theme_type_variation = &"ButtonSecondary"
	_skill_eff_clear_btn.pressed.connect(_clear_balance_snapshots_log)
	vb.add_child(_skill_eff_clear_btn)

	for i in range(5):
		var row := Label.new()
		row.text = "%d. -" % (i + 1)
		row.theme_type_variation = &"Label.Body"
		vb.add_child(row)
		_damage_rows.append(row)

	_skill_eff_title = Label.new()
	_skill_eff_title.text = "施法效率榜"
	_skill_eff_title.theme_type_variation = &"Label.Value"
	vb.add_child(_skill_eff_title)

	for i in range(3):
		var row := Label.new()
		row.text = "%d) -" % (i + 1)
		row.theme_type_variation = &"Label.Meta"
		vb.add_child(row)
		_skill_eff_rows.append(row)

	_skill_eff_hint = Label.new()
	_skill_eff_hint.text = "诊断: -"
	_skill_eff_hint.theme_type_variation = &"Label.Meta"
	vb.add_child(_skill_eff_hint)

	_skill_eff_hotkey_hint = Label.new()
	_skill_eff_hotkey_hint.text = "热键 F6导出  F7实验模式  F9对比  F10清空"
	_skill_eff_hotkey_hint.theme_type_variation = &"Label.Meta"
	vb.add_child(_skill_eff_hotkey_hint)

	_skill_eff_snapshot_status = Label.new()
	_skill_eff_snapshot_status.text = "快照状态: 未导出"
	_skill_eff_snapshot_status.theme_type_variation = &"Label.Meta"
	vb.add_child(_skill_eff_snapshot_status)
	_refresh_damage_panel(true)


func _toggle_damage_panel() -> void:
	_damage_panel_expanded = not _damage_panel_expanded
	if _damage_panel:
		_damage_panel.visible = _damage_panel_expanded
	if _damage_toggle_btn:
		_damage_toggle_btn.text = "伤害统计 ▼" if _damage_panel_expanded else "伤害统计 ▶"
	if _damage_panel_expanded:
		_refresh_damage_panel(true)
		_damage_trend_samples.clear()


func _toggle_damage_mode() -> void:
	_damage_mode = 1 - _damage_mode
	if _damage_mode_btn:
		_damage_mode_btn.text = "切换到总伤害" if _damage_mode == 1 else "切换到首领伤害"
	_damage_trend_samples.clear()
	_refresh_damage_panel(true)


func _toggle_skill_eff_mode() -> void:
	_skill_eff_recent_mode = not _skill_eff_recent_mode
	if _skill_eff_mode_btn:
		_skill_eff_mode_btn.text = "效率榜: 近60秒" if _skill_eff_recent_mode else "效率榜: 总榜"
	_refresh_damage_panel(true)


func _toggle_skill_eff_sort_mode() -> void:
	if _skill_eff_sort_mode == "casts":
		_skill_eff_sort_mode = "efficiency"
	elif _skill_eff_sort_mode == "efficiency":
		_skill_eff_sort_mode = "avg_hits"
	else:
		_skill_eff_sort_mode = "casts"
	if _skill_eff_sort_btn:
		match _skill_eff_sort_mode:
			"efficiency":
				_skill_eff_sort_btn.text = "排序: 效率"
			"avg_hits":
				_skill_eff_sort_btn.text = "排序: 均命中"
			_:
				_skill_eff_sort_btn.text = "排序: 施放"
	_refresh_damage_panel(true)


func _toggle_skill_eff_min_casts() -> void:
	if _skill_eff_min_casts == 1:
		_skill_eff_min_casts = 3
	elif _skill_eff_min_casts == 3:
		_skill_eff_min_casts = 5
	else:
		_skill_eff_min_casts = 1
	if _skill_eff_min_casts_btn:
		_skill_eff_min_casts_btn.text = "样本: >=%d" % _skill_eff_min_casts
	_refresh_damage_panel(true)


func _apply_skill_eff_experiment_preset() -> void:
	_skill_eff_recent_mode = true
	_skill_eff_sort_mode = "efficiency"
	_skill_eff_min_casts = 3
	if _skill_eff_mode_btn:
		_skill_eff_mode_btn.text = "效率榜: 近60秒"
	if _skill_eff_sort_btn:
		_skill_eff_sort_btn.text = "排序: 效率"
	if _skill_eff_min_casts_btn:
		_skill_eff_min_casts_btn.text = "样本: >=3"
	_refresh_damage_panel(true)
	NotificationSystem.notify_message("已切换实验模式：近60秒 / 排序效率 / 样本>=3", 1.8, "success")


func _toggle_skill_eff_batch_only() -> void:
	var want_on := not _skill_eff_batch_only
	if want_on and _balance_batch_id.is_empty():
		NotificationSystem.notify_message("请先开始新实验批次（F11）再启用当前批次筛选", 1.8, "warning")
		return
	_skill_eff_batch_only = want_on
	if _skill_eff_batch_only and _balance_batch_start_ms <= 0:
		_balance_batch_start_ms = Time.get_ticks_msec()
	if _skill_eff_batch_btn:
		_skill_eff_batch_btn.text = "批次: 当前" if _skill_eff_batch_only else "批次: 全部"
	_refresh_damage_panel(true)


func _skill_eff_since_ms_for_current_mode() -> int:
	if not _skill_eff_batch_only:
		return 0
	var since := _balance_batch_start_ms
	if since <= 0:
		since = Time.get_ticks_msec()
		_balance_batch_start_ms = since
	if _skill_eff_recent_mode:
		var now_ms := Time.get_ticks_msec()
		var win_since := now_ms - 60000
		return maxi(since, win_since)
	return since


func _get_skill_eff_top_entries(n: int) -> Array[Dictionary]:
	if _skill_eff_batch_only:
		return RunStats.top_skill_cast_entries_since_ms(n, _skill_eff_since_ms_for_current_mode(), _skill_eff_sort_mode, _skill_eff_min_casts)
	return RunStats.top_skill_cast_entries_recent(n, 60.0, _skill_eff_sort_mode, _skill_eff_min_casts) if _skill_eff_recent_mode else RunStats.top_skill_cast_entries(n, _skill_eff_sort_mode, _skill_eff_min_casts)


func _gen_balance_batch_id() -> String:
	var dt := Time.get_datetime_dict_from_system()
	var y := int(dt.get("year", 0))
	var mo := int(dt.get("month", 0))
	var d := int(dt.get("day", 0))
	var h := int(dt.get("hour", 0))
	var mi := int(dt.get("minute", 0))
	var s := int(dt.get("second", 0))
	var ms_suffix := int(Time.get_ticks_msec()) % 1000
	return "B%04d%02d%02d-%02d%02d%02d-%03d" % [y, mo, d, h, mi, s, ms_suffix]


func _start_new_balance_batch() -> void:
	_balance_batch_id = _gen_balance_batch_id()
	_balance_batch_start_ms = Time.get_ticks_msec()
	_balance_batch_start_unix = int(Time.get_unix_time_from_system())
	_clear_balance_snapshots_log(true)
	_apply_skill_eff_experiment_preset()
	_skill_eff_batch_only = true
	if _skill_eff_batch_btn:
		_skill_eff_batch_btn.text = "批次: 当前"
	_set_skill_eff_snapshot_status("新批次已开始(%s)" % _balance_batch_id)
	NotificationSystem.notify_message("新实验批次已就绪 %s（日志已清空，口径已统一）" % _balance_batch_id, 1.9, "success")


func _export_skill_eff_snapshot() -> void:
	var cast_top: Array[Dictionary] = _get_skill_eff_top_entries(3)
	var scope_label := "近60秒" if _skill_eff_recent_mode else "总榜"
	if _skill_eff_batch_only:
		scope_label = scope_label + "+当前批次"
	var sort_label := "施放"
	if _skill_eff_sort_mode == "efficiency":
		sort_label = "效率"
	elif _skill_eff_sort_mode == "avg_hits":
		sort_label = "均命中"
	var lines: Array[String] = []
	if not _balance_batch_id.is_empty():
		lines.append("batch=%s" % _balance_batch_id)
		if _balance_batch_start_unix > 0:
			lines.append("batch_start_unix=%d" % _balance_batch_start_unix)
		if _balance_batch_start_ms > 0:
			lines.append("batch_start_ms=%d" % _balance_batch_start_ms)
	lines.append("==== Balance Snapshot %d ====" % Time.get_unix_time_from_system())
	lines.append("scope=%s sort=%s min_casts=%d" % [scope_label, sort_label, _skill_eff_min_casts])
	for i in range(cast_top.size()):
		var ce: Dictionary = cast_top[i]
		var sid := String(ce.get("skill_id", ""))
		var skill_name := _humanize_skill_id(sid)
		lines.append("%d) %s casts=%d avg_hits=%.2f avg_dur_ms=%.1f eff=%.3f" % [
			i + 1,
			skill_name,
			int(ce.get("casts", 0)),
			float(ce.get("avg_hits", 0.0)),
			float(ce.get("avg_duration_ms", 0.0)),
			float(ce.get("efficiency", 0.0))
		])
	lines.append(_build_skill_eff_hint(cast_top))
	lines.append("")
	_capture_eff_snapshot(cast_top, scope_label, sort_label)
	if not _append_balance_log(lines):
		NotificationSystem.notify_message("导出失败：无法写入快照", 1.5, "error")
		return
	_set_skill_eff_snapshot_status("已导出 %s (%s)" % [_format_clock_time(Time.get_datetime_dict_from_system()), (_balance_batch_id if not _balance_batch_id.is_empty() else "未分批")])
	NotificationSystem.notify_message("已导出平衡快照到本地日志文件", 1.6, "success")


func _capture_eff_snapshot(cast_top: Array[Dictionary], scope_label: String, sort_label: String) -> void:
	_prev_eff_snapshot = _last_eff_snapshot.duplicate(true)
	_last_eff_snapshot = {
		"timestamp": Time.get_unix_time_from_system(),
		"scope": scope_label,
		"sort": sort_label,
		"min_casts": _skill_eff_min_casts,
		"batch": _balance_batch_id,
		"batch_start_unix": _balance_batch_start_unix,
		"batch_start_ms": _balance_batch_start_ms,
		"hint": _build_skill_eff_hint(cast_top),
		"top": cast_top.duplicate(true)
	}


func _compare_recent_eff_snapshots() -> void:
	var prev_info: Dictionary = {}
	var last_info: Dictionary = {}
	var want_batch := _balance_batch_id if _skill_eff_batch_only else ""
	if not _last_eff_snapshot.is_empty() and not _prev_eff_snapshot.is_empty():
		var last_top: Array = _last_eff_snapshot.get("top", [])
		var prev_top: Array = _prev_eff_snapshot.get("top", [])
		if not last_top.is_empty() and not prev_top.is_empty():
			if not want_batch.is_empty():
				var lb := String(_last_eff_snapshot.get("batch", ""))
				var pb := String(_prev_eff_snapshot.get("batch", ""))
				if lb != want_batch or pb != want_batch:
					last_info = {}
					prev_info = {}
				else:
					pass
			var last_lead: Dictionary = last_top[0]
			var prev_lead: Dictionary = prev_top[0]
			last_info = {
				"name": _humanize_skill_id(String(last_lead.get("skill_id", ""))),
				"eff": float(last_lead.get("efficiency", 0.0)),
				"hint": String(_last_eff_snapshot.get("hint", "")),
				"scope": String(_last_eff_snapshot.get("scope", "")),
				"sort": String(_last_eff_snapshot.get("sort", "")),
				"min_casts": int(_last_eff_snapshot.get("min_casts", 0)),
				"batch": String(_last_eff_snapshot.get("batch", ""))
			}
			prev_info = {
				"name": _humanize_skill_id(String(prev_lead.get("skill_id", ""))),
				"eff": float(prev_lead.get("efficiency", 0.0)),
				"hint": String(_prev_eff_snapshot.get("hint", "")),
				"scope": String(_prev_eff_snapshot.get("scope", "")),
				"sort": String(_prev_eff_snapshot.get("sort", "")),
				"min_casts": int(_prev_eff_snapshot.get("min_casts", 0)),
				"batch": String(_prev_eff_snapshot.get("batch", ""))
			}
	if last_info.is_empty() or prev_info.is_empty():
		var disk_pair := _load_last_two_eff_snapshots_from_log(want_batch)
		if disk_pair.size() < 2:
			if not want_batch.is_empty():
				NotificationSystem.notify_message("对比失败：请在当前批次至少导出两次效率快照", 1.7, "warning")
			else:
				NotificationSystem.notify_message("对比失败：请先至少导出两次效率快照", 1.5, "warning")
			return
		prev_info = disk_pair[0]
		last_info = disk_pair[1]
	var last_name := String(last_info.get("name", "-"))
	var prev_name := String(prev_info.get("name", "-"))
	var last_eff := float(last_info.get("eff", 0.0))
	var prev_eff := float(prev_info.get("eff", 0.0))
	var delta := last_eff - prev_eff
	var delta_mark := "+" if delta >= 0.0 else ""
	var hint_changed := String(last_info.get("hint", "")) != String(prev_info.get("hint", ""))
	var last_scope := String(last_info.get("scope", ""))
	var prev_scope := String(prev_info.get("scope", ""))
	var last_sort := String(last_info.get("sort", ""))
	var prev_sort := String(prev_info.get("sort", ""))
	var last_min := int(last_info.get("min_casts", 0))
	var prev_min := int(prev_info.get("min_casts", 0))
	var last_batch := String(last_info.get("batch", ""))
	var prev_batch := String(prev_info.get("batch", ""))
	var mode_mismatch := last_scope != prev_scope or last_sort != prev_sort or last_min != prev_min
	var batch_mismatch := not last_batch.is_empty() and not prev_batch.is_empty() and last_batch != prev_batch
	var msg := "快照对比 Top1 %s(%.2f) vs %s(%.2f) Δ%s%.2f" % [last_name, last_eff, prev_name, prev_eff, delta_mark, delta]
	if batch_mismatch:
		msg += " | 跨批次对比(%s vs %s)" % [prev_batch, last_batch]
	if mode_mismatch:
		msg += " | 口径不一致"
		var tips: Array[String] = []
		if last_scope != prev_scope:
			tips.append("范围统一为%s" % last_scope)
		if last_sort != prev_sort:
			tips.append("排序统一为%s" % last_sort)
		if last_min != prev_min:
			tips.append("样本统一为>=%d" % last_min)
		if not tips.is_empty():
			msg += "（建议:" + "，".join(tips) + "）"
	if hint_changed:
		msg += " | 诊断变化"
	var compare_lines: Array[String] = []
	if not prev_batch.is_empty():
		compare_lines.append("batch_prev=%s" % prev_batch)
	if not last_batch.is_empty():
		compare_lines.append("batch_last=%s" % last_batch)
	if prev_batch.is_empty() and last_batch.is_empty() and not _balance_batch_id.is_empty():
		compare_lines.append("batch=%s" % _balance_batch_id)
	if _balance_batch_start_unix > 0:
		compare_lines.append("batch_start_unix=%d" % _balance_batch_start_unix)
	if _balance_batch_start_ms > 0:
		compare_lines.append("batch_start_ms=%d" % _balance_batch_start_ms)
	compare_lines.append("---- Balance Compare %d ----" % Time.get_unix_time_from_system())
	compare_lines.append(msg)
	compare_lines.append("")
	_append_balance_log(compare_lines)
	NotificationSystem.notify_message(msg, 2.4, "info")


func _load_last_two_eff_snapshots_from_log(batch_filter: String = "") -> Array[Dictionary]:
	var path := "user://balance_snapshots.log"
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var text := f.get_as_text()
	f.close()
	if text.is_empty():
		return []
	var blocks: Array[Array] = []
	var current: Array[String] = []
	var lines := text.split("\n")
	for ln in lines:
		if ln.begins_with("==== Balance Snapshot "):
			if not current.is_empty():
				blocks.append(current)
			current = []
		current.append(ln)
	if not current.is_empty():
		blocks.append(current)
	if blocks.size() < 2:
		return []
	var picked: Array[Dictionary] = []
	for bi in range(blocks.size() - 1, -1, -1):
		var snap := _parse_eff_snapshot_block(blocks[bi])
		if snap.is_empty():
			continue
		if not batch_filter.is_empty() and String(snap.get("batch", "")) != batch_filter:
			continue
		picked.append(snap)
		if picked.size() >= 2:
			break
	if picked.size() < 2:
		return []
	picked.reverse()
	return picked


func _parse_eff_snapshot_block(lines: Array) -> Dictionary:
	var out := {"name": "-", "eff": 0.0, "hint": "", "scope": "", "sort": "", "min_casts": 0, "batch": "", "batch_start_unix": 0, "batch_start_ms": 0}
	for v in lines:
		var ln := String(v).strip_edges()
		if ln.begins_with("batch="):
			out["batch"] = ln.trim_prefix("batch=")
		elif ln.begins_with("batch_start_unix="):
			out["batch_start_unix"] = int(ln.trim_prefix("batch_start_unix="))
		elif ln.begins_with("batch_start_ms="):
			out["batch_start_ms"] = int(ln.trim_prefix("batch_start_ms="))
		if ln.begins_with("scope="):
			var parts := ln.split(" ")
			for p in parts:
				if p.begins_with("scope="):
					out["scope"] = p.trim_prefix("scope=")
				elif p.begins_with("sort="):
					out["sort"] = p.trim_prefix("sort=")
				elif p.begins_with("min_casts="):
					out["min_casts"] = int(p.trim_prefix("min_casts="))
		if ln.begins_with("1) "):
			var start := 3
			var cast_i := ln.find(" casts=")
			if cast_i > start:
				out["name"] = ln.substr(start, cast_i - start)
			var eff_i := ln.find("eff=")
			if eff_i >= 0:
				var eff_txt := ln.substr(eff_i + 4).strip_edges()
				out["eff"] = float(eff_txt)
		elif ln.begins_with("诊断:"):
			out["hint"] = ln
	return out


func _append_balance_log(lines: Array[String]) -> bool:
	var path := "user://balance_snapshots.log"
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		return false
	f.seek_end()
	f.store_string("\n".join(lines) + "\n")
	f.close()
	return true


func write_balance_marker(tag: String, fields: Dictionary = {}) -> bool:
	var lines: Array[String] = []
	if not _balance_batch_id.is_empty():
		lines.append("batch=%s" % _balance_batch_id)
	lines.append("---- Balance Marker %d ----" % Time.get_unix_time_from_system())
	lines.append("tag=%s" % tag)
	for k in fields.keys():
		lines.append("%s=%s" % [String(k), String(fields[k])])
	lines.append("")
	return _append_balance_log(lines)


func get_latest_eff_summary() -> Dictionary:
	if _last_eff_snapshot.is_empty():
		return {}
	var top: Array = _last_eff_snapshot.get("top", [])
	if top.is_empty():
		return {}
	var lead: Dictionary = top[0]
	return {
		"skill_id": String(lead.get("skill_id", "")),
		"skill_name": _humanize_skill_id(String(lead.get("skill_id", ""))),
		"efficiency": float(lead.get("efficiency", 0.0)),
		"casts": int(lead.get("casts", 0)),
		"scope": String(_last_eff_snapshot.get("scope", "")),
		"sort": String(_last_eff_snapshot.get("sort", "")),
		"min_casts": int(_last_eff_snapshot.get("min_casts", 0))
	}


func _clear_balance_snapshots_log(silent: bool = false) -> void:
	var path := "user://balance_snapshots.log"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		if not silent:
			NotificationSystem.notify_message("清空失败：无法写入日志文件", 1.5, "error")
		return
	f.store_string("")
	f.close()
	_prev_eff_snapshot.clear()
	_last_eff_snapshot.clear()
	_set_skill_eff_snapshot_status("已清空")
	if not silent:
		NotificationSystem.notify_message("已清空平衡快照日志", 1.4, "success")


func _set_skill_eff_snapshot_status(text: String) -> void:
	if _skill_eff_snapshot_status:
		_skill_eff_snapshot_status.text = "快照状态: " + text


func _format_clock_time(dt: Dictionary) -> String:
	var h := int(dt.get("hour", 0))
	var m := int(dt.get("minute", 0))
	var s := int(dt.get("second", 0))
	return "%02d:%02d:%02d" % [h, m, s]


func _update_damage_panel(delta: float) -> void:
	if _damage_toggle_btn == null:
		return
	_damage_refresh_tick -= delta
	if _damage_refresh_tick > 0.0:
		return
	_damage_refresh_tick = 0.25
	if _damage_panel_expanded:
		_refresh_damage_panel(false)


func _refresh_damage_panel(force: bool) -> void:
	if _damage_toggle_btn == null:
		return
	if not _damage_panel_expanded and not force:
		return
	var top: Array[Dictionary] = RunStats.top_boss_damage_entries(5) if _damage_mode == 1 else RunStats.top_damage_entries(5)
	var total := float(RunStats.damage_to_boss) if _damage_mode == 1 else float(RunStats.damage_total)
	var mode_name := "首领伤害" if _damage_mode == 1 else "总伤害"
	if _damage_title:
		_damage_title.text = "技能伤害统计（%s）" % mode_name
	if _damage_total_label:
		_damage_total_label.text = "%s：%.0f" % [mode_name, total]
	if _damage_main_label:
		if top.is_empty():
			_damage_main_label.text = "主力输出：-"
		else:
			var lead_src := String(top[0].get("source", ""))
			var lead_name := GameDB.humanize_damage_source(lead_src)
			var lead_ratio := float(top[0].get("ratio", 0.0)) * 100.0
			var trend := _trend_mark(lead_src, float(top[0].get("damage", 0.0)))
			_damage_main_label.text = "主力输出：%s（%.1f%%） %s" % [lead_name, lead_ratio, trend]
			_damage_main_label.modulate = _trend_color_of(trend)
	for i in range(_damage_rows.size()):
		var row := _damage_rows[i]
		if row == null:
			continue
		if i >= top.size():
			row.text = "%d. -" % (i + 1)
			continue
		var e: Dictionary = top[i]
		var src := String(e.get("source", ""))
		var name := GameDB.humanize_damage_source(src)
		var dmg := float(e.get("damage", 0.0))
		var ratio := float(e.get("ratio", 0.0)) * 100.0
		row.text = "%d. %s  %.0f（%.1f%%）" % [i + 1, name, dmg, ratio]

	if _skill_eff_title:
		var rank_label := "施放"
		if _skill_eff_sort_mode == "efficiency":
			rank_label = "效率"
		elif _skill_eff_sort_mode == "avg_hits":
			rank_label = "均命中"
		var scope_label := "近60秒" if _skill_eff_recent_mode else "总榜"
		var batch_label := "当前批次" if _skill_eff_batch_only else "全部"
		var batch_id_label := (" %s" % _balance_batch_id) if (_skill_eff_batch_only and not _balance_batch_id.is_empty()) else ""
		_skill_eff_title.text = "施法效率榜（%s · %s · %s%s · 样本≥%d）" % [scope_label, rank_label, batch_label, batch_id_label, _skill_eff_min_casts]
	var cast_top: Array[Dictionary] = _get_skill_eff_top_entries(3)
	for i in range(_skill_eff_rows.size()):
		var srow := _skill_eff_rows[i]
		if srow == null:
			continue
		if i >= cast_top.size():
			srow.text = "%d) -" % (i + 1)
			continue
		var ce: Dictionary = cast_top[i]
		var sid := String(ce.get("skill_id", ""))
		var casts := int(ce.get("casts", 0))
		var avg_hits := float(ce.get("avg_hits", 0.0))
		var avg_dur := float(ce.get("avg_duration_ms", 0.0))
		var eff := float(ce.get("efficiency", 0.0))
		var skill_name := _humanize_skill_id(sid)
		srow.text = "%d) %s  施放%d  均命中%.1f  均时长%.0fms  效率%.2f" % [i + 1, skill_name, casts, avg_hits, avg_dur, eff]

	if _skill_eff_hint:
		_skill_eff_hint.text = _build_skill_eff_hint(cast_top)


func _trend_mark(source: String, current_damage: float) -> String:
	var trend_window := float(_hud_damage_cfg.get("trend_window_sec", 10.0))
	var trend_keep := float(_hud_damage_cfg.get("trend_keep_sec", 12.0))
	var trend_up := float(_hud_damage_cfg.get("trend_up_delta", 120.0))
	var trend_down := float(_hud_damage_cfg.get("trend_down_delta", 35.0))
	var now := Time.get_ticks_msec() / 1000.0
	_damage_trend_samples.append({
		"t": now,
		"source": source,
		"damage": current_damage
	})
	var keep: Array[Dictionary] = []
	for s in _damage_trend_samples:
		var age := now - float(s.get("t", now))
		if age <= trend_keep:
			keep.append(s)
	_damage_trend_samples = keep
	var baseline := -1.0
	for i in range(_damage_trend_samples.size() - 1, -1, -1):
		var s: Dictionary = _damage_trend_samples[i]
		if String(s.get("source", "")) != source:
			continue
		var age := now - float(s.get("t", now))
		if age >= trend_window * 0.95:
			baseline = float(s.get("damage", 0.0))
			break
	if baseline < 0.0:
		return "→"
	var delta := current_damage - baseline
	if delta > trend_up:
		return "↑"
	if delta < trend_down:
		return "↓"
	return "→"


func _trend_color_of(mark: String) -> Color:
	match mark:
		"↑":
			return _cfg_color("color_up", Color(0.56, 1.0, 0.72, 1.0))
		"↓":
			return _cfg_color("color_down", Color(1.0, 0.46, 0.46, 1.0))
		_:
			return _cfg_color("color_flat", Color(1.0, 0.84, 0.44, 1.0))


func _load_hud_damage_panel_cfg() -> void:
	_hud_damage_cfg = _HUD_DAMAGE_PANEL_DEFAULT_CFG.duplicate(true)
	if not FileAccess.file_exists(_HUD_DAMAGE_PANEL_CONFIG_PATH):
		return
	var f := FileAccess.open(_HUD_DAMAGE_PANEL_CONFIG_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	if txt.is_empty():
		return
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var ext: Dictionary = parsed
	for k in ext.keys():
		_hud_damage_cfg[String(k)] = ext[k]


func _load_hud_skill_eff_cfg() -> void:
	_hud_skill_eff_cfg = _HUD_SKILL_EFF_DEFAULT_CFG.duplicate(true)
	if not FileAccess.file_exists(_HUD_SKILL_EFF_CONFIG_PATH):
		return
	var f := FileAccess.open(_HUD_SKILL_EFF_CONFIG_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	if txt.is_empty():
		return
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var ext: Dictionary = parsed
	for k in ext.keys():
		_hud_skill_eff_cfg[String(k)] = ext[k]


func _cfg_color(key: String, fallback: Color) -> Color:
	var raw: Variant = _hud_damage_cfg.get(key, [])
	if raw is Array and (raw as Array).size() >= 4:
		var a: Array = raw
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	return fallback


func _cfg_float(cfg: Dictionary, key: String, fallback: float) -> float:
	return float(cfg.get(key, fallback))


func _cfg_int(cfg: Dictionary, key: String, fallback: int) -> int:
	return int(cfg.get(key, fallback))

# 装备面板切换
func _toggle_equip_panel() -> void:
	_equip_panel_open = not _equip_panel_open
	if _weapon_carrier_panel == null:
		return
	_weapon_carrier_panel.visible = _equip_panel_open
	if _equip_panel_open:
		_refresh_weapon_carrier_panel()

# 获取装备信息（供面板显示）
func get_equipment_info() -> Dictionary:
	var game := get_parent()
	if game == null:
		return {}
	var ws = game.get_node_or_null("WeaponSystem")
	var ss = game.get_node_or_null("SkillSystem")
	var info := {"weapons": {}, "passives": {}, "mutations": {}}
	if ws:
		for wid in ws.level_map.keys():
			var lv := int(ws.level_map[wid])
			if lv > 0:
				info["weapons"][wid] = {"level": lv, "name": String(GameDB.WEAPONS[wid]["name"])}
	if ss:
		for pid in ss.passive_levels.keys():
			var lv := int(ss.passive_levels[pid])
			if lv > 0:
				info["passives"][pid] = {"level": lv, "name": String(GameDB.PASSIVES[pid]["name"])}
		if ss.get("mutation_levels") != null:
			var mlv: Dictionary = ss.mutation_levels
			for mid in mlv.keys():
				var ml := int(mlv[mid])
				if ml > 0 and GameDB.MUTATIONS.has(mid):
					var md: Dictionary = GameDB.MUTATIONS[mid]
					info["mutations"][mid] = {
						"level": ml,
						"name": String(md["name"]),
						"icon": String(md.get("icon", ""))
					}
	return info


func _humanize_skill_id(skill_id: String) -> String:
	return GameDB.humanize_skill_id(skill_id)


func _build_skill_eff_hint(cast_top: Array[Dictionary]) -> String:
	if cast_top.is_empty():
		return "诊断: 暂无有效样本（降低样本阈值或继续战斗）"
	var lead: Dictionary = cast_top[0]
	var lead_name := _humanize_skill_id(String(lead.get("skill_id", "")))
	var lead_casts := int(lead.get("casts", 0))
	var lead_eff := float(lead.get("efficiency", 0.0))
	if cast_top.size() >= 2:
		var second: Dictionary = cast_top[1]
		var second_eff := float(second.get("efficiency", 0.0))
		var overpower_ratio := _cfg_float(_hud_skill_eff_cfg, "overpower_efficiency_ratio", 1.8)
		if second_eff > 0.001 and lead_casts >= _skill_eff_min_casts and lead_eff / second_eff >= overpower_ratio:
			return "诊断: %s 潜在过强（效率显著领先）" % lead_name
	if lead_casts < _skill_eff_min_casts:
		return "诊断: 样本偏少，建议继续收集施放数据"
	return "诊断: 当前分布健康，优先关注手感与可读性"


func _setup_weapon_carrier_panel() -> void:
	_load_weapon_carrier_defs()
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	_weapon_carrier_panel = PanelContainer.new()
	_weapon_carrier_panel.name = "WeaponCarrierPanel"
	_weapon_carrier_panel.theme_type_variation = &"PanelCard"
	_weapon_carrier_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_weapon_carrier_panel.offset_left = 18.0
	_weapon_carrier_panel.offset_top = 56.0
	_weapon_carrier_panel.offset_right = 678.0
	_weapon_carrier_panel.offset_bottom = 526.0
	_weapon_carrier_panel.visible = false
	root.add_child(_weapon_carrier_panel)

	var shell := VBoxContainer.new()
	shell.name = "CarrierShell"
	_weapon_carrier_panel.add_child(shell)

	var title := Label.new()
	title.text = "武器载体图鉴（发射方式 / 命中特效）"
	title.theme_type_variation = &"Label.Value"
	shell.add_child(title)

	var tip := Label.new()
	tip.text = "点击装备按钮可开关；卡面展示载体形象与战斗语义。"
	tip.theme_type_variation = &"Label.Meta"
	shell.add_child(tip)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 404)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(scroll)

	_weapon_carrier_grid = GridContainer.new()
	_weapon_carrier_grid.columns = 2
	_weapon_carrier_grid.add_theme_constant_override("h_separation", 8)
	_weapon_carrier_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_weapon_carrier_grid)


func _load_weapon_carrier_defs() -> void:
	_weapon_carrier_defs.clear()
	if not FileAccess.file_exists(_WEAPON_CARRIER_CONFIG_PATH):
		return
	var f := FileAccess.open(_WEAPON_CARRIER_CONFIG_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	if txt.is_empty():
		return
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var root: Dictionary = parsed
	var defs: Variant = root.get("weapons", {})
	if defs is Dictionary:
		_weapon_carrier_defs = defs


func _refresh_weapon_carrier_panel() -> void:
	if _weapon_carrier_grid == null:
		return
	_weapon_card_items.clear()
	for c in _weapon_carrier_grid.get_children():
		c.queue_free()
	var info := get_equipment_info()
	var levels: Dictionary = info.get("weapons", {})
	for wid in GameDB.WEAPONS.keys():
		var id := String(wid)
		var base_def: Dictionary = _weapon_carrier_defs.get(id, {})
		_weapon_carrier_grid.add_child(_build_weapon_card(id, base_def, int(levels.get(id, {}).get("level", 0))))


func _build_weapon_card(weapon_id: String, card_def: Dictionary, lv: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"PanelCard"
	card.custom_minimum_size = Vector2(308, 186)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.set_meta("hovered", false)
	if lv > 0:
		card.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		card.modulate = Color(0.82, 0.86, 0.93, 0.9)
	card.mouse_entered.connect(func() -> void:
		card.set_meta("hovered", true)
	)
	card.mouse_exited.connect(func() -> void:
		card.set_meta("hovered", false)
	)

	var vb := VBoxContainer.new()
	card.add_child(vb)

	var theme_bar := ColorRect.new()
	theme_bar.custom_minimum_size = Vector2(286, 4)
	theme_bar.color = _carrier_theme_color(String(card_def.get("theme", "neutral")))
	vb.add_child(theme_bar)

	var head := Label.new()
	var wname := String(card_def.get("name", GameDB.WEAPONS.get(weapon_id, {}).get("name", weapon_id)))
	var carrier := String(card_def.get("carrier_name", "载体"))
	var lv_text := ("Lv.%d" % lv) if lv > 0 else "未装备"
	var ex_ready := _is_weapon_ex_ready(weapon_id, lv)
	var ex_text := "  ◇EX就绪" if ex_ready else ""
	head.text = "%s  [%s%s]\n%s" % [wname, lv_text, ex_text, carrier]
	head.theme_type_variation = &"Label.Body"
	vb.add_child(head)
	card.tooltip_text = _weapon_card_tooltip(weapon_id, card_def)

	var tex_path := String(card_def.get("texture", ""))
	if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(286, 86)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = load(tex_path) as Texture2D
		vb.add_child(tr)

	var fire := Label.new()
	fire.text = "发射: %s" % String(card_def.get("fire_mode", "-"))
	fire.theme_type_variation = &"Label.Meta"
	vb.add_child(fire)

	var hit := Label.new()
	hit.text = "命中: %s" % String(card_def.get("hit_fx", "-"))
	hit.theme_type_variation = &"Label.Meta"
	vb.add_child(hit)

	if lv > 0:
		var eq := Label.new()
		eq.text = "已装备"
		eq.theme_type_variation = &"Label.Value"
		eq.modulate = Color(0.62, 1.0, 0.84, 1.0)
		vb.add_child(eq)

	_weapon_card_items.append({
		"card": card,
		"theme_bar": theme_bar,
		"theme_base": theme_bar.color,
		"ex_ready": ex_ready
	})

	return card


func _carrier_theme_color(theme: String) -> Color:
	match theme:
		"electric":
			return Color(0.24, 0.84, 1.0, 0.96)
		"explosive":
			return Color(1.0, 0.46, 0.3, 0.96)
		"frost":
			return Color(0.56, 0.8, 1.0, 0.96)
		"heal":
			return Color(0.36, 0.9, 0.66, 0.96)
		_:
			return Color(0.72, 0.76, 0.84, 0.94)


func _is_weapon_ex_ready(weapon_id: String, lv: int) -> bool:
	if lv < 5:
		return false
	var fusion_id := ""
	for fid in GameDB.FUSIONS.keys():
		var f: Dictionary = GameDB.FUSIONS[fid]
		if String(f.get("weapon", "")) == weapon_id:
			fusion_id = String(fid)
			break
	if fusion_id.is_empty():
		return false
	var req: Dictionary = GameDB.FUSIONS[fusion_id].get("requires", {})
	var game := get_parent()
	if game == null:
		return false
	var ss = game.get_node_or_null("SkillSystem")
	if ss == null:
		return false
	var passive_levels: Dictionary = ss.get("passive_levels")
	for pid in req.keys():
		if int(passive_levels.get(pid, 0)) < int(req[pid]):
			return false
	return true


func _update_weapon_carrier_fx(delta: float) -> void:
	if _weapon_carrier_panel == null or not _weapon_carrier_panel.visible:
		return
	_weapon_card_fx_t += delta
	var breath := 0.88 + 0.12 * sin(_weapon_card_fx_t * 2.0)
	var ex_pulse := 0.75 + 0.25 * sin(_weapon_card_fx_t * 5.6)
	for it in _weapon_card_items:
		var card := it.get("card", null) as PanelContainer
		var bar := it.get("theme_bar", null) as ColorRect
		if card == null or bar == null:
			continue
		var hovered := bool(card.get_meta("hovered", false))
		var target_scale := Vector2.ONE * (1.02 if hovered else 1.0)
		card.scale = card.scale.lerp(target_scale, 0.16)
		var base_col: Color = it.get("theme_base", Color(0.8, 0.8, 0.8, 0.9))
		bar.color = Color(base_col.r * breath, base_col.g * breath, base_col.b * breath, base_col.a)
		if bool(it.get("ex_ready", false)):
			card.modulate.a = 0.9 + 0.1 * ex_pulse


func _weapon_card_tooltip(weapon_id: String, card_def: Dictionary) -> String:
	var fire_mode := String(card_def.get("fire_mode", ""))
	var hit_fx := String(card_def.get("hit_fx", ""))
	var rhythm := String(card_def.get("rhythm", ""))
	var projectile_style := String(card_def.get("projectile_style", ""))
	var role := _weapon_role_hint(fire_mode, hit_fx)
	var recommend := _weapon_recommend_passives(weapon_id)
	return "定位: %s\n发射: %s\n节奏: %s\n弹道: %s\n命中: %s\n推荐被动: %s" % [role, fire_mode, rhythm, projectile_style, hit_fx, recommend]


func _weapon_role_hint(fire_mode: String, hit_fx: String) -> String:
	var s := (fire_mode + " " + hit_fx)
	if s.find("链") >= 0 or s.find("跳电") >= 0:
		return "连锁清线 / 中距压制"
	if s.find("爆") >= 0 or s.find("冲击") >= 0:
		return "爆发AOE / 强破阵"
	if s.find("冻结") >= 0 or s.find("减速") >= 0 or s.find("寒") >= 0:
		return "控场减速 / 稳定生存"
	if s.find("治疗") >= 0 or s.find("净化") >= 0:
		return "续航恢复 / 容错提升"
	if s.find("环绕") >= 0 or s.find("往返") >= 0:
		return "近身防御 / 走位收益"
	return "持续输出 / 构筑核心"


func _weapon_recommend_passives(weapon_id: String) -> String:
	for fid in GameDB.FUSIONS.keys():
		var f: Dictionary = GameDB.FUSIONS[fid]
		if String(f.get("weapon", "")) != weapon_id:
			continue
		var req: Dictionary = f.get("requires", {})
		var names: Array[String] = []
		for pid in req.keys():
			if GameDB.PASSIVES.has(pid):
				var nm := String(GameDB.PASSIVES[pid].get("name", pid))
				names.append("%s%d" % [nm, int(req[pid])])
		if not names.is_empty():
			return " / ".join(names)
	return "攻击提升 / 射速 / 移速"
