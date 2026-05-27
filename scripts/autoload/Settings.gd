extends Node

enum Quality { LOW, MEDIUM, HIGH }
enum VfxProfile { COMPETITIVE, BALANCED, CINEMATIC }
enum EarlyFlowPreset { SOFT, NORMAL, HARDCORE }
enum ReadabilityPreset { LOW, MEDIUM, HIGH }

var quality: Quality = Quality.MEDIUM
var sfx_volume: float = 1.0  # 0.0 ~ 1.0
var music_volume: float = 0.7  # 0.0 ~ 1.0
## 个人版默认关：与商业版「干净 HUD」一致；需要排障时在主菜单打开
var debug_hud: bool = false
## 减轻镜头震动（可访问性常见项）
var reduce_screen_motion: bool = false
## PC 端可选：鼠标指向移动（对标同类里“精确走位”诉求）
var mouse_direct_move: bool = false
## 高优先级敌人高亮（远程/召唤/精英），提高战场可读性
var high_contrast_targets: bool = true
## 战斗噪声分级（对标竞品可读性设置）：跳字/闪屏/粒子
var show_damage_numbers: bool = true
var enable_screen_flash: bool = true
var reduce_particles: bool = false
var vfx_profile: VfxProfile = VfxProfile.BALANCED
var extreme_perf_guard: bool = true
## 首局 0-180 秒吸引力强度档位
var early_flow_preset: EarlyFlowPreset = EarlyFlowPreset.NORMAL
## 人物可见性档位：影响主角标记强度、敌人压暗与飘字避让力度。
var readability_preset: ReadabilityPreset = ReadabilityPreset.MEDIUM
## 主菜单选择的作战地图索引（与 GameDB.MAP_TEMPLATES 对齐；章节化入口的第一步）
var selected_map_index: int = 0
const _SAVE_PATH := "user://settings.cfg"
var _loading := false
var _load_failed_last_time := false

func _ready() -> void:
	load_settings()

func set_quality(v: int) -> void:
	if v < Quality.LOW:
		v = Quality.LOW
	elif v > Quality.HIGH:
		v = Quality.HIGH
	quality = v
	EventBus.graphics_quality_changed.emit(int(quality))
	if not _loading:
		save_settings()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_audio_volumes()
	if not _loading:
		save_settings()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_audio_volumes()
	if not _loading:
		save_settings()


func set_debug_hud(on: bool) -> void:
	debug_hud = on
	if not _loading:
		save_settings()


func set_reduce_screen_motion(on: bool) -> void:
	reduce_screen_motion = on
	if not _loading:
		save_settings()

func set_mouse_direct_move(on: bool) -> void:
	mouse_direct_move = on
	if not _loading:
		save_settings()

func set_high_contrast_targets(on: bool) -> void:
	high_contrast_targets = on
	if not _loading:
		save_settings()

func set_show_damage_numbers(on: bool) -> void:
	show_damage_numbers = on
	if not _loading:
		save_settings()

func set_enable_screen_flash(on: bool) -> void:
	enable_screen_flash = on
	if not _loading:
		save_settings()

func set_reduce_particles(on: bool) -> void:
	reduce_particles = on
	if not _loading:
		save_settings()

func set_vfx_profile(v: int) -> void:
	if v < VfxProfile.COMPETITIVE:
		v = VfxProfile.COMPETITIVE
	elif v > VfxProfile.CINEMATIC:
		v = VfxProfile.CINEMATIC
	if vfx_profile == v:
		return
	vfx_profile = v
	EventBus.vfx_profile_changed.emit(int(vfx_profile))
	if not _loading:
		save_settings()

func set_extreme_perf_guard(on: bool) -> void:
	if extreme_perf_guard == on:
		return
	extreme_perf_guard = on
	EventBus.extreme_perf_guard_changed.emit(extreme_perf_guard)
	if not _loading:
		save_settings()


func set_early_flow_preset(v: int) -> void:
	if v < EarlyFlowPreset.SOFT:
		v = EarlyFlowPreset.SOFT
	elif v > EarlyFlowPreset.HARDCORE:
		v = EarlyFlowPreset.HARDCORE
	early_flow_preset = v
	if not _loading:
		save_settings()

func set_readability_preset(v: int) -> void:
	if v < ReadabilityPreset.LOW:
		v = ReadabilityPreset.LOW
	elif v > ReadabilityPreset.HIGH:
		v = ReadabilityPreset.HIGH
	readability_preset = v
	if not _loading:
		save_settings()


func set_selected_map_index(i: int) -> void:
	var max_i := maxi(0, GameDB.MAP_TEMPLATES.size() - 1)
	selected_map_index = clampi(i, 0, max_i)
	if not _loading:
		save_settings()


func apply_audio_volumes() -> void:
	_apply_audio_volumes()


func _apply_audio_volumes() -> void:
	# SFX bus
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_volume))
		AudioServer.set_bus_mute(sfx_idx, sfx_volume <= 0.001)
	# Music bus
	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(music_volume))
		AudioServer.set_bus_mute(music_idx, music_volume <= 0.001)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("gameplay", "quality", int(quality))
	cfg.set_value("gameplay", "debug_hud", debug_hud)
	cfg.set_value("gameplay", "reduce_screen_motion", reduce_screen_motion)
	cfg.set_value("gameplay", "mouse_direct_move", mouse_direct_move)
	cfg.set_value("gameplay", "high_contrast_targets", high_contrast_targets)
	cfg.set_value("gameplay", "show_damage_numbers", show_damage_numbers)
	cfg.set_value("gameplay", "enable_screen_flash", enable_screen_flash)
	cfg.set_value("gameplay", "reduce_particles", reduce_particles)
	cfg.set_value("gameplay", "vfx_profile", int(vfx_profile))
	cfg.set_value("gameplay", "extreme_perf_guard", extreme_perf_guard)
	cfg.set_value("gameplay", "early_flow_preset", int(early_flow_preset))
	cfg.set_value("gameplay", "readability_preset", int(readability_preset))
	cfg.set_value("gameplay", "selected_map_index", selected_map_index)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	var err := cfg.save(_SAVE_PATH)
	if err != OK:
		push_warning("Settings: 存档写入失败 (%d)" % err)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(_SAVE_PATH)
	if err != OK:
		# 首次运行通常不存在配置文件，不视为异常。
		_load_failed_last_time = err != ERR_FILE_NOT_FOUND
		if _load_failed_last_time:
			push_warning("Settings: 配置读取失败，已回退默认设置 (%d)" % err)
		return
	_loading = true
	set_quality(int(cfg.get_value("gameplay", "quality", int(quality))))
	debug_hud = bool(cfg.get_value("gameplay", "debug_hud", debug_hud))
	reduce_screen_motion = bool(cfg.get_value("gameplay", "reduce_screen_motion", reduce_screen_motion))
	mouse_direct_move = bool(cfg.get_value("gameplay", "mouse_direct_move", mouse_direct_move))
	high_contrast_targets = bool(cfg.get_value("gameplay", "high_contrast_targets", high_contrast_targets))
	show_damage_numbers = bool(cfg.get_value("gameplay", "show_damage_numbers", show_damage_numbers))
	enable_screen_flash = bool(cfg.get_value("gameplay", "enable_screen_flash", enable_screen_flash))
	reduce_particles = bool(cfg.get_value("gameplay", "reduce_particles", reduce_particles))
	vfx_profile = int(cfg.get_value("gameplay", "vfx_profile", int(vfx_profile)))
	extreme_perf_guard = bool(cfg.get_value("gameplay", "extreme_perf_guard", extreme_perf_guard))
	early_flow_preset = int(cfg.get_value("gameplay", "early_flow_preset", int(early_flow_preset)))
	readability_preset = int(cfg.get_value("gameplay", "readability_preset", int(readability_preset)))
	var smi := int(cfg.get_value("gameplay", "selected_map_index", selected_map_index))
	var smax := maxi(0, GameDB.MAP_TEMPLATES.size() - 1)
	selected_map_index = clampi(smi, 0, smax)
	if vfx_profile < VfxProfile.COMPETITIVE:
		vfx_profile = VfxProfile.COMPETITIVE
	elif vfx_profile > VfxProfile.CINEMATIC:
		vfx_profile = VfxProfile.CINEMATIC
	if early_flow_preset < EarlyFlowPreset.SOFT:
		early_flow_preset = EarlyFlowPreset.SOFT
	elif early_flow_preset > EarlyFlowPreset.HARDCORE:
		early_flow_preset = EarlyFlowPreset.HARDCORE
	if readability_preset < ReadabilityPreset.LOW:
		readability_preset = ReadabilityPreset.LOW
	elif readability_preset > ReadabilityPreset.HIGH:
		readability_preset = ReadabilityPreset.HIGH
	sfx_volume = float(cfg.get_value("audio", "sfx_volume", sfx_volume))
	music_volume = float(cfg.get_value("audio", "music_volume", music_volume))
	sfx_volume = clampf(sfx_volume, 0.0, 1.0)
	music_volume = clampf(music_volume, 0.0, 1.0)
	_apply_audio_volumes()
	_loading = false
	_load_failed_last_time = false
