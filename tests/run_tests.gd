extends SceneTree
## Run from the repository root:
##   godot --headless --path . --import
##   godot --headless --path . --script res://tests/run_tests.gd
## The fixtures are real exports from spritepilot.com: a 6 frame trimmed sheet
## with three tags (walk 3-5 forward, hit 0-2 ping-pong, back 0-5 reverse) and
## frame times of 100, 100, 300, 100, 100, 200 ms.

const Converter := preload("res://addons/spritepilot_importer/converter.gd")
const FIXTURES := "res://tests/fixtures"
const FORMATS := ["texturepacker", "phaser", "godot", "aseprite"]
const DELAYS_MS := [100, 100, 300, 100, 100, 200]

var _failures := 0
var _checks := 0


func _init() -> void:
	var site := _site_atlases()
	for format in FORMATS:
		_test_format(format, site)
	_test_keeps_editor_settings()
	_test_errors()
	_test_play_order()
	print("\n%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_format(format: String, site: Array) -> void:
	print("\n== %s" % format)
	var json_path := _json_in(FIXTURES.path_join(format))
	var result := Converter.convert_file(json_path)
	_check(result.ok, "%s converts (%s)" % [format, result.error])
	if not result.ok:
		return
	_check(result.output_path == FIXTURES.path_join(format).path_join("sprite-sheet.tres"), "saved as sprite-sheet.tres")
	var frames: SpriteFrames = ResourceLoader.load(result.output_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(frames != null, "saved file loads as SpriteFrames")
	if frames == null:
		return
	var names := Array(frames.get_animation_names())
	names.sort()
	_check(names == ["back", "hit", "walk"], "animations are the three tags (got %s)" % [names])

	var expected_order := {"walk": [3, 4, 5], "hit": [0, 1, 2, 1], "back": [5, 4, 3, 2, 1, 0]}
	var timed := format == "aseprite"
	for anim in expected_order:
		var order: Array = expected_order[anim]
		_check(frames.get_frame_count(anim) == order.size(), "%s has %d frames" % [anim, order.size()])
		_check(frames.get_animation_speed(anim) == 12.0, "%s plays at 12 FPS" % anim)
		_check(frames.get_animation_loop(anim), "%s loops" % anim)
		for k in mini(order.size(), frames.get_frame_count(anim)):
			var i: int = order[k]
			var tex: AtlasTexture = frames.get_frame_texture(anim, k)
			_check(tex.region == site[i].region, "%s frame %d region %s matches the site's .tres %s" % [anim, k, tex.region, site[i].region])
			_check(tex.margin == site[i].margin, "%s frame %d margin %s matches the site's .tres %s" % [anim, k, tex.margin, site[i].margin])
			_check(tex.get_size() == Vector2(24, 24), "%s frame %d keeps its untrimmed 24x24 size" % [anim, k])
			_check(tex.atlas.resource_path == FIXTURES.path_join(format).path_join("sprite-sheet.png"), "frame uses the sheet next to the JSON")
			var want: float = DELAYS_MS[i] * 12.0 / 1000.0 if timed else 1.0
			_check(is_equal_approx(frames.get_frame_duration(anim, k), want), "%s frame %d duration %s (want %s)" % [anim, k, frames.get_frame_duration(anim, k), want])


func _test_keeps_editor_settings() -> void:
	print("\n== converting again keeps loop and speed set in the editor")
	var json_path := _json_in(FIXTURES.path_join("aseprite"))
	var first := Converter.convert_file(json_path)
	var frames: SpriteFrames = first.frames
	frames.set_animation_loop(&"hit", false)
	frames.set_animation_speed(&"hit", 8.0)
	ResourceSaver.save(frames, first.output_path)
	var again := Converter.convert_file(json_path)
	var reloaded: SpriteFrames = ResourceLoader.load(again.output_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(reloaded.get_animation_loop(&"hit") == false, "hit stays non-looping")
	_check(reloaded.get_animation_speed(&"hit") == 8.0, "hit keeps 8 FPS")
	_check(is_equal_approx(reloaded.get_frame_duration(&"hit", 2), 300 * 8.0 / 1000.0), "durations follow the kept speed")
	_check(reloaded.get_animation_loop(&"walk") == true, "other animations unchanged")


func _test_errors() -> void:
	print("\n== errors")
	var dir := "res://tests/fixtures/errors"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_write(dir.path_join("broken.json"), "{ not json")
	_write(dir.path_join("settings.json"), "{\"volume\": 3}")
	_write(dir.path_join("nosheet.json"), "{\"frames\": {\"a.png\": {\"frame\": {\"x\":0,\"y\":0,\"w\":4,\"h\":4}}}, \"meta\": {\"image\": \"missing.png\"}}")
	_write(dir.path_join("rotated.json"), "{\"frames\": [{\"filename\": \"a\", \"rotated\": true, \"frame\": {\"x\":0,\"y\":0,\"w\":4,\"h\":4}}]}")
	for case in [["broken", "not valid JSON"], ["settings", "no sprite frames"], ["nosheet", "Could not find the sprite sheet image"], ["rotated", "Rotated frames"]]:
		var r := Converter.convert_file(dir.path_join(case[0] + ".json"))
		_check(not r.ok and r.error.contains(case[1]), "%s.json fails with a clear message (%s)" % [case[0], r.error])


func _test_play_order() -> void:
	print("\n== play order")
	_check(Converter.play_order(0, 0, "pingpong") == [0], "one frame ping-pong")
	_check(Converter.play_order(0, 1, "pingpong") == [0, 1], "two frame ping-pong")
	_check(Converter.play_order(2, 4, "pingpong_reverse") == [4, 3, 2, 3], "Aseprite pingpong_reverse")


## Regions and margins from the .tres file spritepilot.com wrote for the same sheet.
func _site_atlases() -> Array:
	var text := FileAccess.get_file_as_string(FIXTURES.path_join("site-spriteframes/sprite-frames.tres.txt"))
	var out := []
	var rx := RegEx.create_from_string("region = Rect2\\(([^)]*)\\)(?:\\nmargin = Rect2\\(([^)]*)\\))?")
	for m in rx.search_all(text):
		var r := m.get_string(1).split(",")
		var entry := {"region": Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])), "margin": Rect2()}
		if not m.get_string(2).is_empty():
			var g := m.get_string(2).split(",")
			entry.margin = Rect2(float(g[0]), float(g[1]), float(g[2]), float(g[3]))
		out.append(entry)
	_check(out.size() == 6, "site .tres has 6 frames")
	return out


func _json_in(dir: String) -> String:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			return dir.path_join(f)
	return ""


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("  FAIL ", what)
