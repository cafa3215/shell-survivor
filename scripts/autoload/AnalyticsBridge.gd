extends Node

# Generic no-op analytics bridge to keep call sites stable.
func track_event(event_name: String, params: Dictionary = {}) -> void:
	# Keep signature for future provider integration.
	var _unused: Array = [event_name, params]
