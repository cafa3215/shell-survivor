extends SceneTree

const SCENES: PackedStringArray = [
	"res://scenes/Main_new.tscn",
	"res://scenes/Game.tscn",
	"res://scenes/Player.tscn",
	"res://scenes/modules/vfx/VFXDemo.tscn",
	"res://scenes/modules/sfx/SFXDemo.tscn",
	"res://scenes/modules/ui/UIDemo.tscn",
	"res://scenes/modules/art/ArtDemo.tscn",
	"res://scenes/modules/skills/SkillsDemo.tscn",
	"res://scenes/modules/animation/AnimationDemo.tscn",
	"res://scenes/modules/modeling/ModelingDemo.tscn",
	"res://scenes/modules/rigging/RiggingDemo.tscn",
	"res://scenes/modules/level/LevelDemo.tscn",
	"res://scenes/modules/programming/ProgrammingDemo.tscn",
	"res://scenes/ui/DamageNumber.tscn",
	"res://scenes/ui/HUD_new.tscn",
	"res://scenes/ui/PausePanel.tscn",
	"res://scenes/ui/ResultPanel.tscn",
	"res://scenes/ui/UpgradePanel_new.tscn",
	"res://scenes/ui/RunRelicPickPanel.tscn",
]

func _init() -> void:
	var failed: String = ""
	for p in SCENES:
		var res: Resource = ResourceLoader.load(p)
		if res == null:
			failed = p
			break
	if failed != "":
		push_error("validate_load: failed to load " + failed)
		quit(1)
		return
	print("validate_load: OK %d scenes" % SCENES.size())
	quit(0)
