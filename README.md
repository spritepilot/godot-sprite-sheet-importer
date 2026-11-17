# SpritePilot Importer for Godot

Setting up an AnimatedSprite2D by hand gets old fast. You make a SpriteFrames, slice the sheet, drag frames into each animation, then fix the timing. If you already have the sheet and a JSON file describing it, that's busywork.

This add-on does it for you. Right click the JSON in the FileSystem dock, pick **Create SpriteFrames (SpritePilot)**, and you get a `.tres` file you can drop straight into an AnimatedSprite2D.

We built it for sheets exported from [SpritePilot](https://spritepilot.com), our free sprite sheet tools, but it reads the common formats other tools write too:

* SpritePilot's Godot JSON (`sprite-sheet.godot.json`)
* TexturePacker JSON, hash or array (`sprite-sheet.json`, `sprite-sheet.phaser.json`)
* Aseprite JSON, hash or array (`sprite-sheet.aseprite.json`)

It needs Godot 4.4 or newer. We test it on 4.7.

## Installing

Copy `addons/spritepilot_importer` into your project's `addons` folder, then turn it on under Project > Project Settings > Plugins.

## Using it

Keep the sheet and its JSON in the same folder, say `res://characters/hero.png` and `res://characters/hero.json`. Right click `hero.json`, choose Create SpriteFrames, and `hero.tres` shows up next to it. That's it.

You can also select a few JSON files and run Project > Tools > Create SpriteFrames from selected JSON to do them all at once.

## What ends up in the file

Every frame points at your sheet as an AtlasTexture, so the sheet stays one image with its own import settings. Nothing gets copied or cut up.

If your frames were trimmed (the transparent edges cropped off to save space), each one gets the margin it needs to go back to its original size. Without that the sprite wobbles around from frame to frame.

Each animation tag becomes its own animation with the same name. Reverse tags play backwards, and ping-pong tags go there and back without doubling up the end frames. No tags? You get a single `default` animation with every frame in it.

Aseprite JSON carries a duration for each frame, and those come through. A frame you held for 300 ms stays three times longer than a 100 ms one. The other formats don't store timing, so every frame gets the same length and you can adjust it in the SpriteFrames panel.

Re-exported your sheet? Just convert again. Any loop or speed changes you made in the SpriteFrames panel are kept.

The add-on looks for the sheet using the file name written in the JSON first. If that's not there, it tries a PNG, WebP or JPG with the same name as the JSON, and finally `sprite-sheet.png` in that folder.

## Making the sheet in SpritePilot

If you don't have a sheet yet, [SpritePilot](https://spritepilot.com) runs in the browser with nothing to install and no account. You can cut an existing sheet into frames, pack loose images into one, or turn a GIF or video into a sheet. In Export & Download pick one of the JSON formats and add an Animation Tag for each animation (idle, run, attack and so on).

## Known limits

Rotated frames, a TexturePacker packing option, aren't supported, so export without rotation. Multi page atlases aren't supported either; it's one sheet per JSON.

## Running the tests

With Godot on your PATH, run `tests/run.sh` (or `GODOT=/path/to/godot tests/run.sh`). The test sheets are real exports from spritepilot.com, and every frame is checked against the `.tres` file SpritePilot writes for the same sheet.

Found a bug or a format we don't read? Open an issue.

## Licence

MIT, see [LICENSE](LICENSE). Use it in anything, commercial or not.
