extends "res://scripts/modules/ModuleDemoBase.gd"

@onready var _slider := $Center/Panel/VBox/VolumeRow/Volume as HSlider
@onready var _status := $Center/Panel/VBox/Status as Label
@onready var _btn_hit := $Center/Panel/VBox/Buttons/BtnHit as Button
@onready var _btn_upgrade := $Center/Panel/VBox/Buttons/BtnUpgrade as Button
@onready var _btn_warning := $Center/Panel/VBox/Buttons/BtnWarning as Button
@onready var _btn_fallback := $Center/Panel/VBox/Buttons/BtnFallback as Button

func _ready() -> void:
	demo_name = "音效模块"
	super._ready()
	_slider.value = clampf(Settings.sfx_volume * 100.0, 0.0, 100.0)
	_slider.value_changed.connect(_on_sfx_volume_changed)
	_btn_hit.pressed.connect(func() -> void: _play_named_or_fallback("hit", "命中"))
	_btn_upgrade.pressed.connect(func() -> void: _play_named_or_fallback("level_up", "升级"))
	_btn_warning.pressed.connect(func() -> void: _play_named_or_fallback("boss_warning", "首领警告"))
	_btn_fallback.pressed.connect(func() -> void: _play_fallback_beep())
	_status.text = "状态：已就绪（可调音量并触发音效）"

func module_self_test() -> bool:
	# 无头门禁用：确保 AudioManager/Settings 可用，且可以播放回退音（不依赖外部资源）。
	if get_node_or_null("/root/AudioManager") == null:
		return false
	if get_node_or_null("/root/Settings") == null:
		return false
	_play_fallback_beep()
	return true

func _on_sfx_volume_changed(v: float) -> void:
	Settings.set_sfx_volume(v / 100.0)
	_status.text = "状态：音效音量已设置为 %d%%" % int(v)

func _play_named_or_fallback(key: String, label: String) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am == null:
		_status.text = "状态：AudioManager 缺失，已播放回退哔声（仅用于验证）"
		_play_fallback_beep()
		return
	# 走项目统一事件：AudioManager 在内部监听 EventBus.play_sfx。
	EventBus.play_sfx.emit(StringName(key), Vector2.ZERO)
	_status.text = "状态：已触发音效事件（%s）" % label

func _play_fallback_beep() -> void:
	var am := get_node_or_null("/root/AudioManager")
	var beep := _make_beep_stream()
	if am != null and am.has_method("play_sfx"):
		am.play_sfx(beep, 1.0, -6.0)
		_status.text = "状态：已播放回退哔声（通过 AudioManager）"
		return
	# 极端情况下（AudioManager 不存在），不报错即可；此 Demo 的核心是“可合并的接口”。
	_status.text = "状态：AudioManager 缺失，跳过播放（门禁会拦截）"

func _make_beep_stream() -> AudioStreamWAV:
	# 纯脚本生成一个短促“哔”声，避免依赖外部音频资源。
	var rate := 44100
	var duration := 0.18
	var freq := 880.0
	var samples := int(rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2) # 16-bit mono
	for i in samples:
		var t := float(i) / float(rate)
		var env := 1.0 - (float(i) / float(samples))
		var s := sin(TAU * freq * t) * env
		var v := int(clamp(s, -1.0, 1.0) * 32767.0)
		var idx := i * 2
		data[idx] = v & 0xFF
		data[idx + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

