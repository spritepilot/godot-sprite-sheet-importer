# SpritePilot Importer for Godot

Turn a sprite sheet and its JSON into a ready **SpriteFrames** resource for `AnimatedSprite2D` with one right click. Trimmed frames keep their original size, animation tags become named animations, and frame timing comes along.

It reads the JSON that [SpritePilot](https://spritepilot.com) exports, and the same formats from other tools:

| Format | File SpritePilot writes | Frame timing |
|---|---|---|
| Godot JSON | `sprite-sheet.godot.json` | no (every frame 1.0) |
| TexturePacker JSON (hash) | `sprite-sheet.json` | no |
| Phaser JSON (array) | `sprite-sheet.phaser.json` | no |
| Aseprite JSON (hash or array) | `sprite-sheet.aseprite.json` | yes |

Free and open source (MIT). Needs Godot 4.4 or newer; tested on Godot 4.7.

## Install

1. Copy the `addons/spritepilot_importer` folder into your project's `addons` folder.
2. Open **Project > Project Settings > Plugins** and turn on **SpritePilot Importer**.

## Use

1. Put the sheet image and its JSON in the same folder of your project, for example `res://characters/hero.png` and `res://characters/hero.json`.
2. In the FileSystem dock, right click the JSON and choose **Create SpriteFrames (SpritePilot)**.
3. `hero.tres` appears next to the JSON. Drop it into an `AnimatedSprite2D`'s **Sprite Frames** property.

The same command is under **Project > Tools** for the JSON files selected in the FileSystem dock. Select several to convert them all at once.

## What you get

* **One texture.** Every frame is an `AtlasTexture` on your sheet, so the sheet stays a single image and keeps its import settings.
* **Trimmed frames stay aligned.** When transparent edges were trimmed, each frame gets a margin that restores its original size, so the sprite doesn't jitter between frames.
* **Tags become animations.** Each tag is a named animation. Reverse tags play backwards and ping-pong tags play there and back without repeating the end frames. With no tags you get one animation, `default`, with every frame.
* **Timing is kept.** With per-frame durations (Aseprite JSON), a 300 ms frame stays three times as long as a 100 ms one. Animations play at 12 FPS and the durations are set to match.
* **Your edits survive.** Convert again after re-exporting the sheet and each animation keeps the loop and speed you set in the SpriteFrames panel.
* **No bleeding.** Frames have `filter_clip` on, so neighbouring frames never show at the edges.

The sheet image is found from the name inside the JSON, then from the JSON's own name (`hero.json` looks for `hero.png`, `.webp` or `.jpg`), then `sprite-sheet.png` in the same folder.

## Making a sheet with SpritePilot

[SpritePilot](https://spritepilot.com) is a set of free browser tools for 2D sprites. Cut an existing sheet into frames, pack images into a sheet, or turn a GIF or video into one, then open **Export & Download**, pick a JSON format, and add an **Animation Tag** for each animation. Nothing to install and no sign up.

## Limits

* Rotated frames (a TexturePacker option) are not supported. Export without rotation.
* One sheet per JSON. Multi-page atlases are not supported.

## Tests

`tests/run.sh` runs every check with Godot on your PATH (or `GODOT=/path/to/godot tests/run.sh`). The fixtures are real exports from spritepilot.com, and the tests compare every frame against the `.tres` file SpritePilot itself writes for the same sheet.

## Licence

MIT. See [LICENSE](LICENSE).
