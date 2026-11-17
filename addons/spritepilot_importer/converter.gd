@tool
extends RefCounted
## Builds a Godot SpriteFrames resource from sprite sheet data.
##
## Reads every JSON format SpritePilot exports (Godot JSON, TexturePacker JSON
## hash, Phaser JSON array, Aseprite JSON) and the same formats written by
## other tools. Frames become AtlasTextures on the sheet, so the sheet stays one
## texture. Trimmed frames get a margin that restores their original size, tags
## become named animations (reverse and ping-pong included) and per-frame
## durations are kept.

## Base speed of every animation. Frame durations are relative to it, so a
## 100 ms frame at 12 FPS has a duration of 1.2.
const DEFAULT_FPS := 12.0

## Converts the JSON file at [param json_path] and saves the SpriteFrames next
## to it. Returns a Dictionary: ok (bool), error (String), output_path (String),
## frames (SpriteFrames), warnings (PackedStringArray).
static func convert_file(json_path: String, fps: float = DEFAULT_FPS) -> Dictionary:
	var parsed := parse_file(json_path)
	if not parsed.ok:
		return parsed
	var texture_path := find_texture(json_path, parsed.image)
	if texture_path.is_empty():
		return _fail("Could not find the sprite sheet image%s next to %s." % [
			(" \"%s\"" % parsed.image) if not parsed.image.is_empty() else "", json_path.get_file()])
	var texture: Texture2D = load(texture_path)
	if texture == null:
		return _fail("Could not load the sprite sheet image %s." % texture_path)
	var output_path := output_path_for(json_path)
	var previous: SpriteFrames = null
	if ResourceLoader.exists(output_path):
		previous = load(output_path) as SpriteFrames
	var frames := build(parsed, texture, fps, previous)
	var err := ResourceSaver.save(frames, output_path)
	if err != OK:
		return _fail("Could not save %s (error %d)." % [output_path, err])
	return {
		"ok": true, "error": "", "output_path": output_path,
		"frames": frames, "warnings": parsed.warnings,
	}

## Reads and parses a JSON file. See [method parse].
static func parse_file(json_path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(json_path)
	if text.is_empty():
		return _fail("Could not read %s." % json_path)
	var json := JSON.new()
	if json.parse(text) != OK:
		return _fail("%s is not valid JSON (line %d: %s)." % [json_path.get_file(), json.get_error_line(), json.get_error_message()])
	return parse(json.data)

## Turns parsed JSON into a common shape: ok, error, format, image (file name
## of the sheet, may be empty), frames (Array of Dictionaries with name,
## region, margin, duration_ms) and tags (Array of name/from/to/direction).
static func parse(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return _fail("This JSON is not sprite sheet data.")
	var d: Dictionary = data
	var meta: Dictionary = d.get("meta", {}) if typeof(d.get("meta")) == TYPE_DICTIONARY else {}
	var result := {
		"ok": true, "error": "", "format": "", "image": "", "frames": [], "tags": [],
		"warnings": PackedStringArray(),
	}
	var raw_frames: Variant = d.get("frames")
	var raw_tags: Variant = null

	if typeof(raw_frames) == TYPE_ARRAY and d.has("filename") and _first_has(raw_frames, "region"):
		# SpritePilot "Godot JSON"
		result.format = "spritepilot-godot"
		result.image = str(d.filename)
		for f in raw_frames:
			var region := _rect(f.get("region"))
			var source := _size(f.get("sourceSize"), region.size)
			var offset := _vec(f.get("offset"))
			result.frames.append(_frame(str(f.get("name", "")), region,
				bool(f.get("trimmed", false)), offset, source, f.get("duration", -1)))
		raw_tags = d.get("animations")
	elif typeof(raw_frames) == TYPE_ARRAY and _first_has(raw_frames, "frame"):
		# TexturePacker / Phaser "JSON array", Aseprite array
		result.format = "json-array"
		for f in raw_frames:
			var entry := _texturepacker_frame(str(f.get("filename", "")), f, result.warnings)
			if entry.is_empty():
				return _fail("Rotated frames are not supported. Export the sheet without rotation.")
			result.frames.append(entry)
		result.image = str(meta.get("image", ""))
		raw_tags = meta.get("frameTags")
	elif typeof(raw_frames) == TYPE_DICTIONARY:
		# TexturePacker / Aseprite "JSON hash"
		result.format = "json-hash"
		for key in raw_frames:
			var entry := _texturepacker_frame(str(key), raw_frames[key], result.warnings)
			if entry.is_empty():
				return _fail("Rotated frames are not supported. Export the sheet without rotation.")
			result.frames.append(entry)
		result.image = str(meta.get("image", ""))
		raw_tags = meta.get("frameTags")
	elif typeof(d.get("sprites")) == TYPE_ARRAY:
		# SpritePilot "Basic JSON"
		result.format = "spritepilot-basic"
		for s in d.sprites:
			var region := Rect2(s.get("x", 0), s.get("y", 0), s.get("width", 0), s.get("height", 0))
			result.frames.append(_frame(str(s.get("name", "")), region, bool(s.get("trimmed", false)),
				_vec(s.get("offset")), _size(s.get("sourceSize"), region.size), -1))
		raw_tags = d.get("frameTags")
	else:
		return _fail("This JSON has no sprite frames SpritePilot can read.")

	if result.frames.is_empty():
		return _fail("The sprite sheet data has no frames.")
	if typeof(raw_tags) == TYPE_ARRAY:
		for t in raw_tags:
			if typeof(t) != TYPE_DICTIONARY:
				continue
			result.tags.append({
				"name": str(t.get("name", "")).strip_edges(),
				"from": int(t.get("from", 0)), "to": int(t.get("to", 0)),
				"direction": str(t.get("direction", "forward")),
			})
	return result

## Builds the SpriteFrames. When [param previous] is the SpriteFrames made
## last time, each animation keeps the loop and speed set on it in the editor.
static func build(parsed: Dictionary, texture: Texture2D, fps: float = DEFAULT_FPS, previous: SpriteFrames = null) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	var atlases: Array[AtlasTexture] = []
	var timed := false
	for f in parsed.frames:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = f.region
		atlas.margin = f.margin
		atlas.filter_clip = true
		atlases.append(atlas)
		if f.duration_ms > 0:
			timed = true

	var count := atlases.size()
	var animations: Array = []
	for t in parsed.tags:
		var from := clampi(mini(t.from, t.to), 0, count - 1)
		var to := clampi(maxi(t.from, t.to), 0, count - 1)
		animations.append({"name": t.name, "indices": play_order(from, to, t.direction)})
	if animations.is_empty():
		animations.append({"name": "default", "indices": play_order(0, count - 1, "forward")})

	var used := {}
	for anim in animations:
		var name := _unique_name(anim.name if not anim.name.is_empty() else "animation", used)
		var speed := fps
		var loop := true
		if previous != null and previous.has_animation(name):
			speed = previous.get_animation_speed(name)
			loop = previous.get_animation_loop(name)
		frames.add_animation(name)
		frames.set_animation_speed(name, speed)
		frames.set_animation_loop(name, loop)
		for i in anim.indices:
			var ms: float = parsed.frames[i].duration_ms
			var duration := ms * speed / 1000.0 if timed and ms > 0 else 1.0
			frames.add_frame(name, atlases[i], duration)
	return frames

## Frame indices in the order a tag plays them.
static func play_order(from: int, to: int, direction: String) -> Array:
	var forward: Array[int] = []
	for i in range(from, to + 1):
		forward.append(i)
	var backward := forward.duplicate()
	backward.reverse()
	match direction:
		"reverse":
			return backward
		"pingpong":
			# There and back without repeating the end frames.
			var out := forward.duplicate()
			out.append_array(backward.slice(1, maxi(1, backward.size() - 1)))
			return out
		"pingpong_reverse":
			var out := backward.duplicate()
			out.append_array(forward.slice(1, maxi(1, forward.size() - 1)))
			return out
		_:
			return forward

## Where the sheet image is: the file the JSON names, in the JSON's folder;
## else an image with the JSON's base name; else SpritePilot's default
## sprite-sheet image in the same folder.
static func find_texture(json_path: String, image: String) -> String:
	var dir := json_path.get_base_dir()
	var candidates: PackedStringArray = []
	if not image.is_empty():
		candidates.append(dir.path_join(image.get_file()))
	for base in [_base_name(json_path), "sprite-sheet"]:
		for ext in ["png", "webp", "jpg"]:
			candidates.append(dir.path_join("%s.%s" % [base, ext]))
	for c in candidates:
		if ResourceLoader.exists(c):
			return c
	return ""

## sprite-sheet.godot.json -> sprite-sheet.tres, hero.json -> hero.tres
static func output_path_for(json_path: String) -> String:
	return json_path.get_base_dir().path_join(_base_name(json_path) + ".tres")

static func _base_name(json_path: String) -> String:
	var base := json_path.get_file().get_basename()
	for suffix in [".godot", ".phaser", ".aseprite"]:
		if base.ends_with(suffix):
			return base.trim_suffix(suffix)
	return base

static func _texturepacker_frame(name: String, f: Variant, warnings: PackedStringArray) -> Dictionary:
	if typeof(f) != TYPE_DICTIONARY:
		return {}
	if bool(f.get("rotated", false)):
		return {}
	var region := _rect(f.get("frame"))
	var sss: Variant = f.get("spriteSourceSize")
	var offset := Vector2(sss.get("x", 0), sss.get("y", 0)) if typeof(sss) == TYPE_DICTIONARY else Vector2.ZERO
	var source := _size(f.get("sourceSize"), region.size)
	return _frame(name.trim_suffix(".png"), region, bool(f.get("trimmed", false)), offset, source, f.get("duration", -1))

static func _frame(name: String, region: Rect2, trimmed: bool, offset: Vector2, source: Vector2, duration: Variant) -> Dictionary:
	# Godot draws an AtlasTexture at region.size + margin.size, shifted by
	# margin.position, so the margin's size is the total trimmed width and height.
	var margin := Rect2()
	if trimmed:
		margin = Rect2(offset, source - region.size)
	var ms := -1.0
	if typeof(duration) in [TYPE_INT, TYPE_FLOAT]:
		ms = float(duration)
	return {"name": name, "region": region, "margin": margin, "duration_ms": ms}

static func _first_has(arr: Array, key: String) -> bool:
	return not arr.is_empty() and typeof(arr[0]) == TYPE_DICTIONARY and arr[0].has(key)

static func _rect(v: Variant) -> Rect2:
	if typeof(v) != TYPE_DICTIONARY:
		return Rect2()
	return Rect2(v.get("x", 0), v.get("y", 0), v.get("w", 0), v.get("h", 0))

static func _vec(v: Variant) -> Vector2:
	if typeof(v) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(v.get("x", 0), v.get("y", 0))

static func _size(v: Variant, fallback: Vector2) -> Vector2:
	if typeof(v) != TYPE_DICTIONARY:
		return fallback
	return Vector2(v.get("w", fallback.x), v.get("h", fallback.y))

static func _unique_name(name: String, used: Dictionary) -> StringName:
	var candidate := name
	var n := 2
	while used.has(candidate):
		candidate = "%s_%d" % [name, n]
		n += 1
	used[candidate] = true
	return StringName(candidate)

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "output_path": "", "frames": null, "warnings": PackedStringArray()}
