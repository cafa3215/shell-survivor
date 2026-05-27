extends RefCounted
class_name UIMotion

const MOTION_FAST := 0.10
const MOTION_NORMAL := 0.20
const MOTION_SLOW := 0.35

const EASE_OUT := Tween.EASE_OUT
const EASE_IN_OUT := Tween.EASE_IN_OUT
const EASE_SNAP := Tween.EASE_OUT

const TRANS_ENTRANCE := Tween.TRANS_BACK
const TRANS_GENERAL := Tween.TRANS_SINE
const TRANS_SNAP := Tween.TRANS_QUAD

const MOTION_PANEL := MOTION_SLOW
const MOTION_UI_TRANSITION := MOTION_NORMAL
const MOTION_UI_FEEDBACK := MOTION_FAST

const MOTION_AMBIENT_LONG := MOTION_SLOW * 6.0
const MOTION_AMBIENT_MEDIUM := MOTION_SLOW * 4.0

static func quantize_duration(duration: float) -> float:
	if duration <= MOTION_FAST:
		return MOTION_FAST
	if duration <= MOTION_NORMAL:
		return MOTION_NORMAL
	return MOTION_SLOW
