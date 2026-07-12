extends SceneTree

## 若 vendor 缺失则从 GitHub 拉取 KayKit（需网络）。Windows 推荐 tools/download_kaykit_assets.ps1

const VENDOR_ADV := "res://assets/vendor/kaykit/adventurers/Characters/gltf/Rogue.glb"
const REPOS: Array = [
	{
		"zip_url": "https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventurers-1.0/archive/refs/heads/main.zip",
		"folder_hint": "Adventurers",
		"dest": "res://assets/vendor/kaykit/adventurers",
	},
	{
		"zip_url": "https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0/archive/refs/heads/main.zip",
		"folder_hint": "Skeletons",
		"dest": "res://assets/vendor/kaykit/skeletons",
	},
]


func _init() -> void:
	if FileAccess.file_exists(ProjectSettings.globalize_path(VENDOR_ADV)):
		print("download_kaykit_assets: vendor already present")
		quit(0)
		return
	push_error("download_kaykit_assets: vendor missing — run tools/download_kaykit_assets.ps1 on Windows")
	quit(1)
