extends Node

## Web/桌面统一 UI 字体：浏览器无法使用系统字体，必须在运行时注入主题。

const FONT_PATH := "res://assets/fonts/simhei.ttf"
const WARMUP_TEXT := "弹壳幸存者预热测试"

var _font: Font


func _ready() -> void:
	_font = _load_ui_font()
	if _font == null:
		push_error("UiFont: failed to load " + FONT_PATH)
		return
	_warmup_font(_font)
	_apply_to_project_theme()
	call_deferred("_deferred_patch")


func get_font() -> Font:
	return _font


func _load_ui_font() -> Font:
	var loaded: Resource = load(FONT_PATH)
	if loaded == null:
		return null
	if loaded is FontFile:
		var file := (loaded as FontFile).duplicate() as FontFile
		file.allow_system_fallback = true
		return file
	if loaded is Font:
		return (loaded as Font).duplicate()
	return null


func _warmup_font(font: Font) -> void:
	font.get_string_size(WARMUP_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)


func _deferred_patch() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	patch_control_tree(tree.root)


func _apply_to_project_theme() -> void:
	var default_theme: Theme = ThemeDB.get_default_theme()
	if default_theme:
		_set_theme_fonts(default_theme)
	var theme: Theme = load("res://assets/themes/cyber_theme.tres") as Theme
	if theme:
		_set_theme_fonts(theme)


func _set_theme_fonts(theme: Theme) -> void:
	theme.default_font = _font
	theme.default_font_size = 16
	for tname in ["Button", "Label", "OptionButton", "PopupMenu", "CheckBox", "RichTextLabel", "Window", "AcceptDialog"]:
		theme.set_font("font", tname, _font)


func patch_control_tree(root: Node) -> void:
	if _font == null or root == null:
		return
	if root is Label:
		var lab := root as Label
		lab.label_settings = null
		lab.add_theme_font_override("font", _font)
	elif root is OptionButton:
		_patch_option_button(root as OptionButton)
	elif root is Button:
		(root as Button).add_theme_font_override("font", _font)
	elif root is Control:
		(root as Control).add_theme_font_override("font", _font)
	for child in root.get_children():
		patch_control_tree(child)


func _patch_option_button(ob: OptionButton) -> void:
	ob.add_theme_font_override("font", _font)
	var popup := ob.get_popup()
	if popup:
		popup.add_theme_font_override("font", _font)
