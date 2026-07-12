extends Node

@export var sfx_volume_db: float = -6.0
@export var music_volume_db: float = -12.0
@export var max_sfx_players: int = 16
@export var verbose_missing_audio: bool = false

var _sfx_players: Array[AudioStreamPlayer] = []
var _cursor: int = 0
var _music_player: AudioStreamPlayer
var _sfx_library: Dictionary = {}
var _sfx_variants: Dictionary = {}  # name -> Array[AudioStream]
var _music_library: Dictionary = {}
var _sfx_cooldowns: Dictionary = {}  # name -> remaining cooldown
var _sfx_cooldown_time: float = 0.08  # 同一音效最短间隔（秒）
## 暂停/结算时压低背景音乐，恢复后由 Settings 总线音量还原
var _pause_music_ducked: bool = false
const _PAUSE_MUSIC_LINEAR_MUL := 0.38
var _last_variant_by_key: Dictionary = {}  # 避免同一来源连续命中同一层叠方案
var _last_sfx_variant_idx: Dictionary = {}  # name -> last index

# 音效文件名（实际路径：优先 res://assets/game_pack/sfx/，否则回退 res://assets/sfx/）
const _SFX_FILENAMES := {
	"weapon_fire": "weapon_fire.mp3",
	"explosion": "explosion.mp3",
	"lightning": "lightning.mp3",
	"hit": "hit.mp3",
	"enemy_death": "enemy_death.wav",
	"level_up": "level_up.wav",
	"upgrade_pick": "upgrade_pick.wav",
	"boss_warning": "boss_warning.wav",
	"player_damage": "player_damage.wav",
	"victory": "victory.wav",
	"defeat": "defeat.wav"
}

const _MUSIC_FILENAMES := {
	"bgm_main": "bgm_main.wav",
	"bgm_boss": "bgm_boss.wav"
}

# 每个武器来源的独立音效配置（可继续扩展为外部配置文件）。
# 说明：
# - base: 主体样本（现阶段复用已有库）
# - pitch_min/max: 音高随机范围
# - vol_db: 主体音量
# - cooldown: 该来源最小触发间隔
# - layer: 次层（可选），按概率叠加，增强层次与刺激感
const _WEAPON_SFX_PROFILE := {
	"kunai_hit": {"base": "weapon_fire", "pitch_min": 0.94, "pitch_max": 1.06, "vol_db": -7.2, "cooldown": 0.028, "layer": {"name": "hit", "chance": 0.18, "pitch_min": 0.88, "pitch_max": 0.98, "vol_db": -18.0}},
	"kunai_pierce": {"base": "weapon_fire", "pitch_min": 1.02, "pitch_max": 1.16, "vol_db": -5.8, "cooldown": 0.018, "layer": {"name": "hit", "chance": 0.3, "pitch_min": 1.04, "pitch_max": 1.16, "vol_db": -15.6}},
	"kunai_finish": {"base": "hit", "pitch_min": 0.96, "pitch_max": 1.1, "vol_db": -3.8, "cooldown": 0.024, "layer": {"name": "weapon_fire", "chance": 0.44, "pitch_min": 0.92, "pitch_max": 1.06, "vol_db": -13.8}},
	"lightning_strike": {"base": "lightning", "pitch_min": 0.84, "pitch_max": 1.14, "vol_db": -2.6, "cooldown": 0.024, "layer": {"name": "hit", "chance": 0.64, "pitch_min": 0.88, "pitch_max": 1.12, "vol_db": -11.4}},
	"lightning_jump": {"base": "lightning", "pitch_min": 1.06, "pitch_max": 1.24, "vol_db": -7.8, "cooldown": 0.02, "layer": {"name": "hit", "chance": 0.34, "pitch_min": 1.04, "pitch_max": 1.18, "vol_db": -16.2}},
	"lightning_hex": {"base": "lightning", "pitch_min": 0.92, "pitch_max": 1.22, "vol_db": -8.2, "cooldown": 0.02, "layer": {"name": "hit", "chance": 0.38, "pitch_min": 1.02, "pitch_max": 1.22, "vol_db": -16.4}},
	"rocket_explode": {"base": "explosion", "pitch_min": 0.78, "pitch_max": 0.98, "vol_db": -0.8, "cooldown": 0.039, "layer": {"name": "hit", "chance": 0.8, "pitch_min": 0.78, "pitch_max": 0.96, "vol_db": -9.2}},
	"rocket_secondary": {"base": "explosion", "pitch_min": 0.86, "pitch_max": 1.04, "vol_db": -4.1, "cooldown": 0.042, "layer": {"name": "hit", "chance": 0.48, "pitch_min": 0.88, "pitch_max": 1.04, "vol_db": -12.4}},
	"rocket_cone": {"base": "hit", "pitch_min": 0.88, "pitch_max": 1.02, "vol_db": -8.0, "cooldown": 0.028, "layer": {"name": "explosion", "chance": 0.28, "pitch_min": 1.06, "pitch_max": 1.18, "vol_db": -17.2}},
	"quantum_burst": {"base": "hit", "pitch_min": 0.86, "pitch_max": 0.98, "vol_db": -4.0, "cooldown": 0.05, "layer": {"name": "lightning", "chance": 0.38, "pitch_min": 0.92, "pitch_max": 1.06, "vol_db": -13.0}},
	"quantum_bounce": {"base": "hit", "pitch_min": 0.94, "pitch_max": 1.1, "vol_db": -8.2, "cooldown": 0.026, "layer": {"name": "lightning", "chance": 0.24, "pitch_min": 1.05, "pitch_max": 1.2, "vol_db": -17.2}},
	"quantum_holy": {"base": "lightning", "pitch_min": 0.86, "pitch_max": 1.0, "vol_db": -3.8, "cooldown": 0.06, "layer": {"name": "explosion", "chance": 0.3, "pitch_min": 0.94, "pitch_max": 1.04, "vol_db": -13.8}},
	"molotov_impact": {"base": "explosion", "pitch_min": 0.92, "pitch_max": 1.04, "vol_db": -5.5, "cooldown": 0.04, "layer": {"name": "hit", "chance": 0.36, "pitch_min": 0.92, "pitch_max": 1.04, "vol_db": -13.2}},
	"molotov_burn": {"base": "hit", "pitch_min": 1.08, "pitch_max": 1.24, "vol_db": -11.0, "cooldown": 0.06, "layer": {"name": "explosion", "chance": 0.12, "pitch_min": 1.18, "pitch_max": 1.3, "vol_db": -19.0}},
	"molotov_cone": {"base": "hit", "pitch_min": 0.9, "pitch_max": 1.02, "vol_db": -8.8, "cooldown": 0.03, "layer": {"name": "explosion", "chance": 0.2, "pitch_min": 1.08, "pitch_max": 1.18, "vol_db": -18.0}},
	"drone_attack": {"base": "weapon_fire", "pitch_min": 0.9, "pitch_max": 1.02, "vol_db": -6.2, "cooldown": 0.028, "layer": {"name": "hit", "chance": 0.34, "pitch_min": 0.94, "pitch_max": 1.06, "vol_db": -15.6}},
	"drone_pulse": {"base": "hit", "pitch_min": 1.0, "pitch_max": 1.16, "vol_db": -9.6, "cooldown": 0.045, "layer": {"name": "weapon_fire", "chance": 0.2, "pitch_min": 0.94, "pitch_max": 1.04, "vol_db": -18.0}},
	"drone_sweep": {"base": "hit", "pitch_min": 0.92, "pitch_max": 1.06, "vol_db": -8.0, "cooldown": 0.032, "layer": {"name": "weapon_fire", "chance": 0.18, "pitch_min": 0.96, "pitch_max": 1.06, "vol_db": -19.0}},
	"guardian_spin": {"base": "hit", "pitch_min": 0.88, "pitch_max": 1.0, "vol_db": -7.4, "cooldown": 0.05, "layer": {"name": "weapon_fire", "chance": 0.2, "pitch_min": 0.92, "pitch_max": 1.0, "vol_db": -18.0}},
	"guardian_tick": {"base": "hit", "pitch_min": 1.12, "pitch_max": 1.26, "vol_db": -12.0, "cooldown": 0.08},
	"guardian_slice": {"base": "hit", "pitch_min": 0.94, "pitch_max": 1.08, "vol_db": -8.8, "cooldown": 0.035, "layer": {"name": "weapon_fire", "chance": 0.18, "pitch_min": 0.96, "pitch_max": 1.08, "vol_db": -18.6}},
	"boomerang_out": {"base": "weapon_fire", "pitch_min": 0.98, "pitch_max": 1.1, "vol_db": -7.2, "cooldown": 0.035, "layer": {"name": "hit", "chance": 0.24, "pitch_min": 1.0, "pitch_max": 1.12, "vol_db": -16.8}},
	"boomerang_return": {"base": "weapon_fire", "pitch_min": 0.94, "pitch_max": 1.08, "vol_db": -7.6, "cooldown": 0.035, "layer": {"name": "hit", "chance": 0.22, "pitch_min": 0.98, "pitch_max": 1.1, "vol_db": -17.0}},
	"boomerang_orbit": {"base": "hit", "pitch_min": 1.02, "pitch_max": 1.16, "vol_db": -9.5, "cooldown": 0.04, "layer": {"name": "weapon_fire", "chance": 0.16, "pitch_min": 1.04, "pitch_max": 1.18, "vol_db": -19.0}},
	"boomerang_crescent": {"base": "hit", "pitch_min": 0.96, "pitch_max": 1.1, "vol_db": -9.0, "cooldown": 0.03, "layer": {"name": "weapon_fire", "chance": 0.2, "pitch_min": 1.02, "pitch_max": 1.12, "vol_db": -18.8}},
	"mine_explosion": {"base": "explosion", "pitch_min": 0.86, "pitch_max": 1.0, "vol_db": -4.6, "cooldown": 0.05, "layer": {"name": "hit", "chance": 0.42, "pitch_min": 0.86, "pitch_max": 1.0, "vol_db": -13.8}},
	"mine_wave": {"base": "hit", "pitch_min": 0.9, "pitch_max": 1.02, "vol_db": -9.2, "cooldown": 0.04, "layer": {"name": "lightning", "chance": 0.2, "pitch_min": 1.06, "pitch_max": 1.18, "vol_db": -18.4}},
	"frost_wave": {"base": "hit", "pitch_min": 1.06, "pitch_max": 1.18, "vol_db": -10.0, "cooldown": 0.045, "layer": {"name": "lightning", "chance": 0.1, "pitch_min": 1.14, "pitch_max": 1.28, "vol_db": -20.0}},
	"heal_wave": {"base": "hit", "pitch_min": 1.14, "pitch_max": 1.28, "vol_db": -10.8, "cooldown": 0.05, "layer": {"name": "lightning", "chance": 0.12, "pitch_min": 1.22, "pitch_max": 1.36, "vol_db": -20.0}}
}

const _SFX_SOURCE_FALLBACK := {
	"kunai_hit": "weapon_fire",
	"kunai_pierce": "weapon_fire",
	"kunai_finish": "hit",
	"lightning_strike": "lightning",
	"lightning_jump": "lightning",
	"lightning_hex": "lightning",
	"rocket_explode": "explosion",
	"rocket_secondary": "explosion",
	"rocket_cone": "hit",
	"quantum_burst": "hit",
	"quantum_bounce": "hit",
	"quantum_holy": "hit",
	"quantum_hex": "lightning",
	"molotov_impact": "explosion",
	"molotov_burn": "explosion",
	"molotov_cone": "hit",
	"drone_attack": "weapon_fire",
	"drone_pulse": "weapon_fire",
	"drone_sweep": "hit",
	"guardian_spin": "hit",
	"guardian_tick": "hit",
	"guardian_slice": "hit",
	"boomerang_out": "hit",
	"boomerang_return": "hit",
	"boomerang_orbit": "hit",
	"boomerang_crescent": "hit",
	"mine_explosion": "explosion",
	"mine_wave": "hit",
	"frost_wave": "hit",
	"heal_wave": "hit"
}

## 运行时卡片：在手工精调表基础上，自动补齐同家族 source，降低双端维护成本。
var _weapon_sfx_profile_runtime: Dictionary = {}
var _sfx_source_fallback_runtime: Dictionary = {}
const _WEAPON_AUDIO_CARD_CONFIG_PATH := "res://assets/config/weapon_audio_card.json"

const _WEAPON_FAMILY_AUDIO_TEMPLATE := {
	"kunai": {"base": "weapon_fire", "pitch_min": 1.0, "pitch_max": 1.16, "vol_db": -6.2, "cooldown": 0.024, "layer_name": "hit", "layer_chance": 0.24, "layer_vol_db": -16.4, "fallback": "weapon_fire"},
	"lightning": {"base": "lightning", "pitch_min": 0.9, "pitch_max": 1.18, "vol_db": -5.0, "cooldown": 0.026, "layer_name": "hit", "layer_chance": 0.32, "layer_vol_db": -14.8, "fallback": "lightning"},
	"rocket": {"base": "explosion", "pitch_min": 0.82, "pitch_max": 1.02, "vol_db": -3.6, "cooldown": 0.04, "layer_name": "hit", "layer_chance": 0.42, "layer_vol_db": -12.8, "fallback": "explosion"},
	"quantum": {"base": "hit", "pitch_min": 0.88, "pitch_max": 1.06, "vol_db": -6.4, "cooldown": 0.034, "layer_name": "lightning", "layer_chance": 0.22, "layer_vol_db": -16.2, "fallback": "hit"},
	"molotov": {"base": "hit", "pitch_min": 0.94, "pitch_max": 1.1, "vol_db": -8.8, "cooldown": 0.04, "layer_name": "explosion", "layer_chance": 0.18, "layer_vol_db": -18.4, "fallback": "hit"},
	"drone": {"base": "weapon_fire", "pitch_min": 0.94, "pitch_max": 1.08, "vol_db": -8.0, "cooldown": 0.034, "layer_name": "hit", "layer_chance": 0.2, "layer_vol_db": -17.8, "fallback": "weapon_fire"},
	"guardian": {"base": "hit", "pitch_min": 0.92, "pitch_max": 1.08, "vol_db": -9.2, "cooldown": 0.048, "layer_name": "weapon_fire", "layer_chance": 0.16, "layer_vol_db": -18.8, "fallback": "hit"},
	"boomerang": {"base": "hit", "pitch_min": 0.94, "pitch_max": 1.1, "vol_db": -8.8, "cooldown": 0.035, "layer_name": "weapon_fire", "layer_chance": 0.2, "layer_vol_db": -18.6, "fallback": "hit"},
	"mine": {"base": "explosion", "pitch_min": 0.86, "pitch_max": 1.02, "vol_db": -6.0, "cooldown": 0.05, "layer_name": "hit", "layer_chance": 0.26, "layer_vol_db": -15.2, "fallback": "explosion"},
	"frost": {"base": "hit", "pitch_min": 1.02, "pitch_max": 1.16, "vol_db": -9.8, "cooldown": 0.046, "layer_name": "lightning", "layer_chance": 0.1, "layer_vol_db": -19.6, "fallback": "hit"},
	"heal": {"base": "hit", "pitch_min": 1.08, "pitch_max": 1.22, "vol_db": -10.4, "cooldown": 0.05, "layer_name": "lightning", "layer_chance": 0.12, "layer_vol_db": -19.8, "fallback": "hit"}
}

func _set_bus_safe(player: AudioStreamPlayer, preferred_bus: String) -> void:
	var idx: int = AudioServer.get_bus_index(preferred_bus)
	if idx != -1:
		player.bus = preferred_bus
	else:
		player.bus = "Master"

func _ready() -> void:
	for _i in max_sfx_players:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		_set_bus_safe(p, "SFX")
		p.volume_db = sfx_volume_db
		add_child(p)
		_sfx_players.append(p)
	
	_music_player = AudioStreamPlayer.new()
	_set_bus_safe(_music_player, "Music")
	_music_player.volume_db = music_volume_db
	add_child(_music_player)
	
	_load_sfx_library()
	_load_music_library()
	_build_weapon_audio_runtime_cards()
	
	EventBus.play_sfx.connect(_on_play_sfx)
	EventBus.play_music.connect(_on_play_music)
	EventBus.stop_music.connect(_on_stop_music)
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)
	EventBus.weapon_cards_reload_requested.connect(_on_weapon_cards_reload_requested)

func _process(delta: float) -> void:
	for key in _sfx_cooldowns.keys():
		var remaining: float = float(_sfx_cooldowns[key]) - delta
		if remaining <= 0.0:
			_sfx_cooldowns.erase(key)
		else:
			_sfx_cooldowns[key] = remaining

func _resolve_pack_or_legacy_sfx(fname: String) -> String:
	if fname.is_empty():
		return ""
	var pack_p := GameDB.ASSET_PACK_SFX + fname
	if FileAccess.file_exists(pack_p) or ResourceLoader.exists(pack_p):
		return pack_p
	var leg_p := "res://assets/sfx/" + fname
	if FileAccess.file_exists(leg_p) or ResourceLoader.exists(leg_p):
		return leg_p
	return ""


func _resolve_pack_or_legacy_music(fname: String) -> String:
	if fname.is_empty():
		return ""
	var pack_p := GameDB.ASSET_PACK_MUSIC + fname
	if FileAccess.file_exists(pack_p) or ResourceLoader.exists(pack_p):
		return pack_p
	var leg_p := "res://assets/music/" + fname
	if FileAccess.file_exists(leg_p) or ResourceLoader.exists(leg_p):
		return leg_p
	return ""


func _load_sfx_library() -> void:
	for key in _SFX_FILENAMES:
		var fname: String = str(_SFX_FILENAMES[key])
		var path := _resolve_pack_or_legacy_sfx(fname)
		if not path.is_empty():
			_sfx_library[key] = load(path)
	_load_sfx_variants()

func _load_sfx_variants() -> void:
	for key in _SFX_FILENAMES.keys():
		var arr: Array[AudioStream] = []
		for i in range(12):
			var st: AudioStream = _load_variant_stream(String(key), i)
			if st != null:
				arr.append(st)
			else:
				break
		if not arr.is_empty():
			_sfx_variants[key] = arr

func _load_variant_stream(key: String, idx: int) -> AudioStream:
	var bases: Array[String] = [
		"%s%s/v%02d" % [GameDB.ASSET_PACK_SFX_VARIANTS, key, idx],
		"res://assets/sfx/variants/%s/v%02d" % [key, idx]
	]
	for base in bases:
		for ext in ["wav", "mp3", "ogg"]:
			var p: String = "%s.%s" % [base, ext]
			if FileAccess.file_exists(p) or ResourceLoader.exists(p):
				return load(p) as AudioStream
	return null

func _load_music_library() -> void:
	for key in _MUSIC_FILENAMES:
		var fname: String = str(_MUSIC_FILENAMES[key])
		var path := _resolve_pack_or_legacy_music(fname)
		if not path.is_empty():
			_music_library[key] = load(path)

func play_sfx_named(name: String, pitch: float = 1.0, volume_db: float = 0.0, cooldown_override: float = -1.0, cooldown_key: String = "") -> void:
	if not _sfx_library.has(name):
		return
	var key: String = name if cooldown_key.is_empty() else cooldown_key
	var cd: float = _sfx_cooldown_time if cooldown_override < 0.0 else maxf(0.0, cooldown_override)
	# 同一音效节流：避免短时间内重复播放
	if cd > 0.0 and _sfx_cooldowns.has(key) and float(_sfx_cooldowns[key]) > 0.0:
		return
	if cd > 0.0:
		_sfx_cooldowns[key] = cd
	var stream: AudioStream = _pick_sfx_stream(name)
	if stream == null:
		stream = _sfx_library.get(name, null)
	if stream == null:
		return
	play_sfx(stream, pitch, volume_db)

func _pick_sfx_stream(name: String) -> AudioStream:
	if not _sfx_variants.has(name):
		return _sfx_library.get(name, null)
	var arr: Array[AudioStream] = _sfx_variants[name]
	if arr.is_empty():
		return _sfx_library.get(name, null)
	if arr.size() == 1:
		return arr[0]
	var idx: int = randi() % arr.size()
	var lk: String = "pick:" + name
	var last: int = int(_last_sfx_variant_idx.get(lk, -1))
	if idx == last:
		idx = (idx + 1 + (randi() % maxi(1, arr.size() - 1))) % arr.size()
	_last_sfx_variant_idx[lk] = idx
	return arr[idx]

func play_sfx(stream: AudioStream, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var p: AudioStreamPlayer = _sfx_players[_cursor]
	_cursor = (_cursor + 1) % _sfx_players.size()
	p.stop()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = sfx_volume_db + volume_db
	p.play()

func _play_weapon_profile(sn: String) -> bool:
	if not _weapon_sfx_profile_runtime.has(sn):
		return false
	var profile: Dictionary = _weapon_sfx_profile_runtime[sn]
	var base_name: String = String(profile.get("base", "hit"))
	var p_min: float = float(profile.get("pitch_min", 0.95))
	var p_max: float = float(profile.get("pitch_max", 1.05))
	var volume_db: float = float(profile.get("vol_db", 0.0))
	var cooldown: float = float(profile.get("cooldown", 0.03))
	var relief: float = _current_pressure_relief_ratio()
	var pressure: float = _enemy_pressure_ratio()
	if relief > 0.001:
		var width: float = (p_max - p_min) * (1.0 - relief * 0.3)
		var center: float = (p_min + p_max) * 0.5
		p_min = center - width * 0.5
		p_max = center + width * 0.5
		volume_db = lerpf(volume_db, volume_db - 0.8, relief)
		cooldown = lerpf(cooldown, cooldown * 1.22, relief)
	if pressure > 0.001:
		volume_db = lerpf(volume_db, volume_db - 1.6, pressure)
		cooldown = lerpf(cooldown, cooldown * 1.42, pressure)
	play_sfx_named(base_name, randf_range(p_min, p_max), volume_db, cooldown, "src:" + sn)

	var layer: Dictionary = profile.get("layer", {})
	if layer.is_empty():
		return true
	var chance: float = float(layer.get("chance", 0.0))
	if relief > 0.001:
		chance *= (1.0 - relief * 0.4)
	if pressure > 0.001:
		chance *= (1.0 - pressure * 0.35)
	if randf() > chance:
		return true
	var layer_name: String = String(layer.get("name", "hit"))
	var last_key: String = "layer:" + sn
	var last_name: String = String(_last_variant_by_key.get(last_key, ""))
	# 简单防重复：若本次层名与上次相同，则按概率跳过层，避免听感机械。
	if last_name == layer_name and randf() < 0.45:
		return true
	_last_variant_by_key[last_key] = layer_name
	var layer_vol: float = float(layer.get("vol_db", -12.0))
	var layer_cd: float = 0.0
	if layer_name == "hit":
		layer_vol -= 2.5
		layer_cd = 0.09
	play_sfx_named(
		layer_name,
		randf_range(float(layer.get("pitch_min", 0.95)), float(layer.get("pitch_max", 1.05))),
		layer_vol,
		layer_cd,
		"layer:" + layer_name if layer_name == "hit" else ""
	)
	return true


func _current_pressure_relief_ratio() -> float:
	var tree: SceneTree = get_tree()
	if tree == null:
		return 0.0
	var scene: Node = tree.current_scene
	if scene == null:
		return 0.0
	var game: Node = scene.find_child("Game", true, false)
	if game and game.has_method("pressure_relief_ratio"):
		return clampf(float(game.pressure_relief_ratio()), 0.0, 1.0)
	return 0.0

func _enemy_pressure_ratio() -> float:
	var tree: SceneTree = get_tree()
	if tree == null:
		return 0.0
	var scene: Node = tree.current_scene
	if scene == null:
		return 0.0
	var em: Node = scene.find_child("EnemyManager", true, false)
	if em and em.has_method("alive_count"):
		var alive: float = float(em.alive_count())
		return clampf((alive - 600.0) / 1200.0, 0.0, 1.0)
	return 0.0

func play_music(track: String) -> void:
	if _music_library.has(track):
		_music_player.stop()
		_music_player.stream = _music_library[track]
		_music_player.play()
		return
	var fname: String = str(_MUSIC_FILENAMES.get(track, ""))
	var path := _resolve_pack_or_legacy_music(fname)
	if path.is_empty():
		return
	_music_player.stop()
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	_music_library[track] = stream
	_music_player.stream = stream
	_music_player.play()

func stop_music_track() -> void:
	_music_player.stop()

func _on_play_sfx(name: StringName, _pos: Vector2) -> void:
	## 轻微音高抖动：高密度自动战斗时减少「同一采样连播」的廉价感（参考 bullet-heaven 音效实践）
	var sn: String = String(name)
	if _play_weapon_profile(sn):
		return
	if _sfx_source_fallback_runtime.has(sn):
		sn = String(_sfx_source_fallback_runtime[sn])
	var pitch: float = 1.0
	var relief: float = _current_pressure_relief_ratio()
	var pressure: float = _enemy_pressure_ratio()
	match sn:
		"weapon_fire":
			pitch = randf_range(0.90, 1.02)
		"hit":
			pitch = randf_range(0.82, 0.96)
		"enemy_death":
			pitch = randf_range(0.9, 1.11)
		"explosion":
			pitch = randf_range(0.88, 1.12)
		"lightning":
			pitch = randf_range(0.86, 1.14)
		"player_damage":
			pitch = randf_range(0.94, 1.06)
		"upgrade_pick", "level_up":
			pitch = randf_range(0.97, 1.05)
		_:
			pitch = 1.0
	# 战局回稳时让高频“噪声型”SFX更克制：略降音高并收窄抖动
	if relief > 0.001:
		match sn:
			"enemy_death", "hit", "weapon_fire":
				pitch = lerpf(pitch, pitch * 0.96, relief)
				pitch = clampf(pitch, 0.88, 1.08)
			_:
				pass
	var vol_db: float = 0.0
	var cd: float = -1.0
	match sn:
		"hit":
			vol_db = -5.5
			cd = 0.11
		"weapon_fire":
			vol_db = -1.5
			cd = 0.06
	if pressure > 0.001:
		match sn:
			"enemy_death":
				vol_db = lerpf(0.0, -3.2, pressure)
				cd = lerpf(0.08, 0.2, pressure)
			"hit", "weapon_fire":
				vol_db = lerpf(0.0, -1.6, pressure)
				cd = lerpf(0.05, 0.12, pressure)
			_:
				pass
	play_sfx_named(sn, pitch, vol_db, cd)


func _build_weapon_audio_runtime_cards() -> void:
	_weapon_sfx_profile_runtime = _WEAPON_SFX_PROFILE.duplicate(true)
	_sfx_source_fallback_runtime = _SFX_SOURCE_FALLBACK.duplicate(true)
	var known_sources: Dictionary = {}
	for key in _sfx_source_fallback_runtime.keys():
		known_sources[String(key)] = true
	for key in _weapon_sfx_profile_runtime.keys():
		known_sources[String(key)] = true
	for source in known_sources.keys():
		var sn: String = String(source)
		var family: String = _weapon_audio_family_of(sn)
		if family.is_empty():
			continue
		var tpl: Dictionary = _WEAPON_FAMILY_AUDIO_TEMPLATE.get(family, {})
		if tpl.is_empty():
			continue
		if not _sfx_source_fallback_runtime.has(sn):
			_sfx_source_fallback_runtime[sn] = String(tpl.get("fallback", "hit"))
		if _weapon_sfx_profile_runtime.has(sn):
			continue
		_weapon_sfx_profile_runtime[sn] = _make_profile_from_template(tpl)
	_load_external_weapon_audio_cards()


func _weapon_audio_family_of(source: String) -> String:
	if source.begins_with("kunai_"):
		return "kunai"
	if source.begins_with("lightning_"):
		return "lightning"
	if source.begins_with("rocket_"):
		return "rocket"
	if source.begins_with("quantum_"):
		return "quantum"
	if source.begins_with("molotov_"):
		return "molotov"
	if source.begins_with("drone_"):
		return "drone"
	if source.begins_with("guardian_"):
		return "guardian"
	if source.begins_with("boomerang_"):
		return "boomerang"
	if source.begins_with("mine_"):
		return "mine"
	if source.begins_with("frost_"):
		return "frost"
	if source.begins_with("heal_"):
		return "heal"
	return ""


func _make_profile_from_template(tpl: Dictionary) -> Dictionary:
	return {
		"base": String(tpl.get("base", "hit")),
		"pitch_min": float(tpl.get("pitch_min", 0.95)),
		"pitch_max": float(tpl.get("pitch_max", 1.05)),
		"vol_db": float(tpl.get("vol_db", -8.0)),
		"cooldown": float(tpl.get("cooldown", 0.04)),
		"layer": {
			"name": String(tpl.get("layer_name", "hit")),
			"chance": float(tpl.get("layer_chance", 0.2)),
			"pitch_min": 0.98,
			"pitch_max": 1.14,
			"vol_db": float(tpl.get("layer_vol_db", -18.0))
		}
	}


func _load_external_weapon_audio_cards() -> void:
	if not FileAccess.file_exists(_WEAPON_AUDIO_CARD_CONFIG_PATH):
		return
	var f: FileAccess = FileAccess.open(_WEAPON_AUDIO_CARD_CONFIG_PATH, FileAccess.READ)
	if f == null:
		return
	var txt: String = f.get_as_text()
	f.close()
	if txt.is_empty():
		return
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var root: Dictionary = parsed
	var fallback_patch: Dictionary = root.get("fallback", {})
	for key in fallback_patch.keys():
		_sfx_source_fallback_runtime[String(key)] = String(fallback_patch[key])
	var profile_patch: Dictionary = root.get("profile", {})
	for key in profile_patch.keys():
		var sn: String = String(key)
		var patch: Variant = profile_patch[key]
		if typeof(patch) != TYPE_DICTIONARY:
			continue
		var base_profile: Dictionary = _weapon_sfx_profile_runtime.get(sn, {})
		var merged: Dictionary = _merge_audio_profile(base_profile, patch as Dictionary)
		_weapon_sfx_profile_runtime[sn] = merged


func _merge_audio_profile(base_profile: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = base_profile.duplicate(true)
	for k in patch.keys():
		if String(k) == "layer" and typeof(patch[k]) == TYPE_DICTIONARY:
			var base_layer: Dictionary = out.get("layer", {})
			var next_layer: Dictionary = base_layer.duplicate(true)
			for lk in (patch[k] as Dictionary).keys():
				next_layer[lk] = (patch[k] as Dictionary)[lk]
			out["layer"] = next_layer
		else:
			out[k] = patch[k]
	return out


func _on_weapon_cards_reload_requested() -> void:
	_build_weapon_audio_runtime_cards()
	NotificationSystem.notify_message("武器音频配置已热重载", 0.9, "success")

func _on_play_music(track: StringName) -> void:
	play_music(String(track))

func _on_stop_music() -> void:
	stop_music_track()


func _duck_music_for_pause() -> void:
	if _pause_music_ducked:
		return
	var idx: int = AudioServer.get_bus_index("Music")
	if idx < 0:
		return
	_pause_music_ducked = true
	var lin: float = maxf(Settings.music_volume * _PAUSE_MUSIC_LINEAR_MUL, 0.0001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(lin))
	AudioServer.set_bus_mute(idx, Settings.music_volume <= 0.001)


func _restore_music_after_pause() -> void:
	if not _pause_music_ducked:
		return
	_pause_music_ducked = false
	Settings.apply_audio_volumes()


func _on_game_paused() -> void:
	_duck_music_for_pause()


func _on_game_resumed() -> void:
	_restore_music_after_pause()
