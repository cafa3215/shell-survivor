extends SceneTree

const RUNS := 2
const TARGET_ELAPSED_SEC := 16.0 * 60.0
const SAMPLE_STEP_SEC := 1.0
const BURST_DIRECTOR_TH := 1.24
const BURST_OCCUPANCY_TH := 0.90
const RECOVERY_START_SEC := 9.0 * 60.0
const RECOVERY_END_SEC := 11.0 * 60.0
const RECOVERY_DIRECTOR_TH := 1.10
const RECOVERY_RELIEF_TH := 0.15
const RECOVERY_OCCUPANCY_TH := 0.88
const OUT_PATH := "res://tmp/midgame_probe_result.json"

func _init() -> void:
	call_deferred("_boot")


func _boot() -> void:
	Engine.time_scale = 8.0
	var results: Array[Dictionary] = []
	for i in RUNS:
		var run_no := i + 1
		var r := await _run_once(run_no)
		results.append(r)
	# 输出汇总，便于终端直接读取
	print("midgame_probe: completed %d runs" % results.size())
	for r in results:
		print("midgame_probe: run=%d elapsed=%.1fs ended=%s max_burst=%ds recovery_9_11=%ds" % [
			int(r.get("run", 0)),
			float(r.get("elapsed_sec", 0.0)),
			str(bool(r.get("ended", false))),
			int(r.get("max_consecutive_burst_sec", 0)),
			int(r.get("max_recovery_window_sec_9_11", 0)),
		])
	_write_results(results)
	quit(0)


func _run_once(run_no: int) -> Dictionary:
	var packed := ResourceLoader.load("res://scenes/Main_new.tscn")
	if packed == null or not (packed is PackedScene):
		push_error("midgame_probe: Main_new load failed")
		return {"run": run_no, "error": "load_failed"}
	var main := (packed as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var start_btn := main.get_node_or_null("MenuLayer/Root/Panel/Margin/VBox/StartButton") as Button
	if start_btn == null:
		push_error("midgame_probe: StartButton missing")
		main.queue_free()
		await process_frame
		return {"run": run_no, "error": "start_button_missing"}
	start_btn.pressed.emit()

	var game: Node = null
	var sample_next_sec := 0.0
	var elapsed := 0.0
	var burst_consec := 0
	var burst_max := 0
	var recovery_consec := 0
	var recovery_max := 0
	var safety_frames := 0
	var death_hook_detached := false
	var event_bus := root.get_node_or_null("/root/EventBus")

	while true:
		await process_frame
		safety_frames += 1
		if safety_frames > 600000:
			break
		if game == null:
			game = main.get("_game") as Node
			if game == null:
				continue
		if not death_hook_detached:
			var death_cb := Callable(game, "_on_player_died")
			if event_bus and event_bus.player_died.is_connected(death_cb):
				event_bus.player_died.disconnect(death_cb)
			death_hook_detached = true
		var pl := game.get_node_or_null("Player")
		if pl != null:
			# 压测用保活：确保能走到 8~16 分钟窗口做节奏观测。
			pl.set("max_hp", 99999.0)
			pl.set("hp", 99999.0)
		elapsed = float(game.get("elapsed"))
		var ended := bool(game.get("_ended"))
		if elapsed >= sample_next_sec:
			sample_next_sec += SAMPLE_STEP_SEC
			var director := float(game.get("_director_mul"))
			var relief := float(game.call("pressure_relief_ratio"))
			var target := maxi(1, int(game.call("_target_enemy_count")))
			var enemy_mgr := game.get_node_or_null("EnemyManager")
			var enemy_alive := int(enemy_mgr.call("alive_count")) if enemy_mgr else 0
			var occ := float(enemy_alive) / float(target)
			var is_burst := director >= BURST_DIRECTOR_TH and occ >= BURST_OCCUPANCY_TH
			if is_burst:
				burst_consec += 1
				burst_max = maxi(burst_max, burst_consec)
			else:
				burst_consec = 0

			if elapsed >= RECOVERY_START_SEC and elapsed <= RECOVERY_END_SEC:
				var in_recovery := (director <= RECOVERY_DIRECTOR_TH) or (relief >= RECOVERY_RELIEF_TH) or (occ <= RECOVERY_OCCUPANCY_TH)
				if in_recovery:
					recovery_consec += 1
					recovery_max = maxi(recovery_max, recovery_consec)
				else:
					recovery_consec = 0
		if elapsed >= TARGET_ELAPSED_SEC:
			var out := {
				"run": run_no,
				"elapsed_sec": elapsed,
				"ended": ended,
				"max_consecutive_burst_sec": burst_max,
				"max_recovery_window_sec_9_11": recovery_max,
			}
			main.queue_free()
			await process_frame
			return out
	main.queue_free()
	await process_frame
	return {
		"run": run_no,
		"elapsed_sec": elapsed,
		"ended": true,
		"max_consecutive_burst_sec": burst_max,
		"max_recovery_window_sec_9_11": recovery_max,
		"error": "safety_break",
	}


func _write_results(results: Array[Dictionary]) -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("midgame_probe: cannot write result file")
		return
	var payload := {
		"runs": results,
		"config": {
			"burst_director_th": BURST_DIRECTOR_TH,
			"burst_occupancy_th": BURST_OCCUPANCY_TH,
			"recovery_window_sec": [RECOVERY_START_SEC, RECOVERY_END_SEC],
		}
	}
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
