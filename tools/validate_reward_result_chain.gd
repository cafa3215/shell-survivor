extends SceneTree

## 奖励/结算持久化链路守卫：
## - Main_new 结果层节点可实例化
## - RunStats / MetaProgress autoload 存在且关键方法存在
## - Main.gd 保持关键串联调用（finalize -> meta record -> result panel）
## - RunStats.gd / MetaProgress.gd 存在持久化关键 token

const REQUIRED_MAIN_NODES: PackedStringArray = [
	"MenuLayer",
	"ResultLayer",
	"ResultLayer/ResultPanel",
]

const REQUIRED_RUNSTATS_METHODS: PackedStringArray = [
	"finalize_latest_run",
	"menu_next_run_hint",
]

const REQUIRED_METAPROGRESS_METHODS: PackedStringArray = [
	"record_run_ended",
	"summary_line",
	"try_purchase_meta_upgrade",
	"is_run_relic_unlocked_for_pool",
]

const REQUIRED_MAIN_CHAIN_TOKENS: PackedStringArray = [
	"RunStats.finalize_latest_run(",
	"MetaProgress.record_run_ended(",
	"result_panel.show_result(",
	"RunStats.menu_next_run_hint()",
]

const REQUIRED_RUNSTATS_PERSIST_TOKENS: PackedStringArray = [
	"SAVE_PATH := \"user://run_stats.cfg\"",
	"_save_history()",
	"_load_history()",
]

const REQUIRED_META_PERSIST_TOKENS: PackedStringArray = [
	"SAVE_PATH := \"user://meta_progress.cfg\"",
	"_save()",
	"_load()",
]


func _init() -> void:
	call_deferred("_boot")


func _boot() -> void:
	var packed: Resource = ResourceLoader.load("res://scenes/Main_new.tscn")
	if packed == null or not (packed is PackedScene):
		push_error("validate_reward_result_chain: failed to load scenes/Main_new.tscn")
		quit(1)
		return
	var main := (packed as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	for path in REQUIRED_MAIN_NODES:
		if main.get_node_or_null(path) == null:
			push_error("validate_reward_result_chain: missing Main node " + path)
			quit(1)
			return

	var rs := root.get_node_or_null("/root/RunStats")
	if rs == null:
		push_error("validate_reward_result_chain: RunStats autoload missing")
		quit(1)
		return
	for method_name in REQUIRED_RUNSTATS_METHODS:
		if not rs.has_method(method_name):
			push_error("validate_reward_result_chain: RunStats method missing " + method_name)
			quit(1)
			return

	var mp := root.get_node_or_null("/root/MetaProgress")
	if mp == null:
		push_error("validate_reward_result_chain: MetaProgress autoload missing")
		quit(1)
		return
	for method_name in REQUIRED_METAPROGRESS_METHODS:
		if not mp.has_method(method_name):
			push_error("validate_reward_result_chain: MetaProgress method missing " + method_name)
			quit(1)
			return

	if not _has_tokens("res://scripts/core/Main.gd", REQUIRED_MAIN_CHAIN_TOKENS, "Main.gd"):
		return
	if not _has_tokens("res://scripts/autoload/RunStats.gd", REQUIRED_RUNSTATS_PERSIST_TOKENS, "RunStats.gd"):
		return
	if not _has_tokens("res://scripts/autoload/MetaProgress.gd", REQUIRED_META_PERSIST_TOKENS, "MetaProgress.gd"):
		return

	print("validate_reward_result_chain: OK")
	quit(0)


func _has_tokens(path: String, tokens: PackedStringArray, label: String) -> bool:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("validate_reward_result_chain: cannot read " + label)
		quit(1)
		return false
	for token in tokens:
		if text.find(token) == -1:
			push_error("validate_reward_result_chain: missing token in " + label + " => " + token)
			quit(1)
			return false
	return true
