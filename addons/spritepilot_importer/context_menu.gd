@tool
extends EditorContextMenuPlugin
## Adds "Create SpriteFrames" to the FileSystem dock's right-click menu for
## JSON files. Loaded only on Godot versions that have EditorContextMenuPlugin.

const ICON_PATH := "res://addons/spritepilot_importer/icon.svg"

var editor_plugin: EditorPlugin


func _popup_menu(paths: PackedStringArray) -> void:
	for p in paths:
		if p.get_extension().to_lower() == "json":
			# The icon is loaded lazily: on first install it may not be imported yet.
			var icon: Texture2D = load(ICON_PATH) if ResourceLoader.exists(ICON_PATH) else null
			add_context_menu_item("Create SpriteFrames (SpritePilot)", _on_create, icon)
			return


func _on_create(paths) -> void:
	# Godot passes the selected paths; accept an Array or a PackedStringArray.
	if editor_plugin != null:
		editor_plugin.convert_paths(PackedStringArray(paths))
