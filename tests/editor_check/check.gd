@tool
extends EditorPlugin
## Test-only: drives the context menu code path in a running editor.

func _enter_tree() -> void:
	await get_tree().create_timer(2.0).timeout
	var out := "res://demo/hero.tres"
	if FileAccess.file_exists(out):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(out))
	var spritepilot: EditorPlugin = load("res://addons/spritepilot_importer/plugin.gd").new()
	var menu = load("res://addons/spritepilot_importer/context_menu.gd").new()
	menu.editor_plugin = spritepilot
	menu._on_create(["res://demo/hero.json"])               # plain Array
	menu._on_create(PackedStringArray(["res://demo/hero.json"]))  # packed
	await get_tree().create_timer(1.0).timeout
	var frames := ResourceLoader.load(out, "", ResourceLoader.CACHE_MODE_IGNORE) as SpriteFrames
	var ok := frames != null and frames.get_animation_names().size() == 3
	print("EDITOR_CHECK ", "PASS" if ok else "FAIL", " ", frames.get_animation_names() if frames else "no file")
	get_tree().quit(0 if ok else 1)
