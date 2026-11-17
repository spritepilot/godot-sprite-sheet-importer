@tool
extends EditorPlugin
## SpritePilot Importer: right-click a sprite sheet JSON in the FileSystem dock
## and choose "Create SpriteFrames". The same command is under
## Project > Tools for the files selected in the FileSystem dock.

const Converter := preload("res://addons/spritepilot_importer/converter.gd")
const TOOL_ITEM := "Create SpriteFrames from selected JSON (SpritePilot)"

var _context_menu: Object = null


func _enter_tree() -> void:
	add_tool_menu_item(TOOL_ITEM, _convert_selected)
	if ClassDB.class_exists(&"EditorContextMenuPlugin"):
		var script: GDScript = load("res://addons/spritepilot_importer/context_menu.gd")
		_context_menu = script.new()
		_context_menu.set(&"editor_plugin", self)
		var slot := ClassDB.class_get_integer_constant(&"EditorContextMenuPlugin", &"CONTEXT_SLOT_FILESYSTEM")
		call(&"add_context_menu_plugin", slot, _context_menu)


func _exit_tree() -> void:
	remove_tool_menu_item(TOOL_ITEM)
	if _context_menu != null:
		call(&"remove_context_menu_plugin", _context_menu)
		_context_menu = null


func _convert_selected() -> void:
	convert_paths(EditorInterface.get_selected_paths())


## Converts every JSON file in [param paths] and reports the result.
func convert_paths(paths: PackedStringArray) -> void:
	var made: PackedStringArray = []
	var json_paths: PackedStringArray = []
	for p in paths:
		if p.get_extension().to_lower() == "json":
			json_paths.append(p)
	if json_paths.is_empty():
		_toast("Select a sprite sheet JSON file in the FileSystem dock first.", true)
		return
	for p in json_paths:
		var result: Dictionary = Converter.convert_file(p)
		if result.ok:
			made.append(result.output_path)
			for w in result.warnings:
				push_warning("SpritePilot: %s" % w)
		else:
			push_error("SpritePilot: %s" % result.error)
			_toast(result.error, true)
	if made.is_empty():
		return
	var fs := EditorInterface.get_resource_filesystem()
	for out in made:
		fs.update_file(out)
	fs.scan()
	EditorInterface.select_file(made[-1])
	var message := "Created %s" % ", ".join(Array(made).map(func(m): return m.get_file()))
	print("SpritePilot: %s" % message)
	_toast(message, false)


func _toast(message: String, is_error: bool) -> void:
	var toaster := EditorInterface.get_editor_toaster()
	if toaster != null:
		toaster.push_toast(message, EditorToaster.SEVERITY_ERROR if is_error else EditorToaster.SEVERITY_INFO)
