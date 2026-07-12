extends Node

## KayKit 资产路径（CC0）。见 assets/vendor/kaykit/README.md

const VENDOR_ROOT := "res://assets/vendor/kaykit/"
const HERO_ROGUE := "res://assets/game_pack/models/hero/rogue.glb"
const ENEMY_WARRIOR := "res://assets/game_pack/models/enemies/skeleton_warrior.glb"
const ENEMY_MAGE := "res://assets/game_pack/models/enemies/skeleton_mage.glb"
const ENEMY_ROGUE := "res://assets/game_pack/models/enemies/skeleton_rogue.glb"
const ENEMY_MINION := "res://assets/game_pack/models/enemies/skeleton_minion.glb"
const ACCESSORY_ROOT := "res://assets/game_pack/models/accessories/gltf/"

const WEAPON_ACCESSORY: Dictionary = {
	"kunai": "dagger.gltf",
	"quantum_ball": "spellbook_closed.gltf",
	"lightning": "staff.gltf",
	"rocket": "crossbow_2handed.gltf",
	"molotov": "mug_full.gltf",
	"guardian": "shield_round_color.gltf",
	"drone_ab": "quiver.gltf",
	"boomerang": "axe_1handed.gltf",
	"frost_aura": "wand.gltf",
	"heal_aura": "spellbook_open.gltf",
	"stun_mine": "smokebomb.gltf",
	"active_bolt": "wand.gltf",
}

const IDLE_ANIM_CANDIDATES: PackedStringArray = ["Unarmed_Idle", "Idle", "Idle_A"]
const RUN_ANIM_CANDIDATES: PackedStringArray = ["Running_A", "Running_B", "Walk", "Walking_A"]


static func accessory_path(weapon_id: String) -> String:
	var file: String = String(WEAPON_ACCESSORY.get(weapon_id, "dagger.gltf"))
	return ACCESSORY_ROOT + file


static func resolve_anim(ap: AnimationPlayer, candidates: PackedStringArray) -> StringName:
	if ap == null:
		return &""
	for c in candidates:
		if ap.has_animation(StringName(c)):
			return StringName(c)
	return &""
