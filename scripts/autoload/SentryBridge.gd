extends Node

# Safe no-op bridge used when Sentry SDK is not integrated.
func capture_test_exception() -> void:
	push_warning("SentryBridge.capture_test_exception() called, but no Sentry integration is configured.")
