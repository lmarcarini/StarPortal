extends Node
## Writes a sheet of 20 portraits drawn by the Godot painter, laid out like the reference
## (docs/reference/portraits_sheet.png): 3× scale, five columns (Military, Office, Science,
## Engineering, Medicine), 12 px gaps. Records are AppearanceRules.roll_seeded("sheet-<n>").
## With a third argument "bodies" it writes the body sheet instead (body_sheet()).
## Run: godot --headless --path . res://tools/portraits/sheet.tscn -- [out.png] [first seed]
## [bodies]
## Bible: docs/content/portraits.md ("Reference")

const FIELDS: Array[String] = ["military", "office", "science", "engineering", "medicine"]
const COUNT: int = 20
const COLUMNS: int = 5
const SCALE: int = 3
const PAD: int = 12
const DEFAULT_PATH: String = "user://portraits_sheet.png"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else DEFAULT_PATH
	var first: int = int(args[1]) if args.size() > 1 else 100
	var bodies: bool = args.size() > 2 and args[2] == "bodies"
	var error: Error = (body_sheet(first) if bodies else sheet(first)).save_png(path)
	print("sheet: %s (%s)" % [path, error_string(error)])
	get_tree().quit(0 if error == OK else 1)


## The sheet of [constant COUNT] portraits with seeds from [param first].
static func sheet(first: int) -> Image:
	var cell: int = PortraitPainter.SIZE * SCALE
	var rows: int = ceili(COUNT / float(COLUMNS))
	var width: int = COLUMNS * (cell + PAD) + PAD
	var out := Image.create_empty(width, rows * (cell + PAD) + PAD, false, Image.FORMAT_RGB8)
	out.fill(Color.html("#0a0e16"))
	for i: int in COUNT:
		var record: Dictionary = AppearanceRules.roll_seeded(
			"sheet-%d" % (first + i), FIELDS[i % COLUMNS]
		)
		var portrait: Image = PortraitPainter.paint(record)
		portrait.resize(cell, cell, Image.INTERPOLATE_NEAREST)
		var at := Vector2i(PAD + (i % COLUMNS) * (cell + PAD), PAD + (i / COLUMNS) * (cell + PAD))
		out.blit_rect(portrait, Rect2i(0, 0, cell, cell), at)
	return out


## One row per field (seeds from [param first], as sheet()): the portrait, then every frame
## of every pose × direction of the full-body sprite, at 2× on the sheet background.
static func body_sheet(first: int) -> Image:
	var scale: int = 2
	var cell := Vector2i(BodyPainter.W * scale, BodyPainter.H * scale)
	var frames: int = 0
	for pose: String in BodyFrames.poses():
		frames += BodyFrames.frame_count(pose) * BodyFrames.DIRECTIONS.size()
	var head: int = PortraitPainter.SIZE * scale
	var width: int = PAD + head + PAD + frames * (cell.x + 4) + PAD
	var row_h: int = cell.y + PAD
	var out := Image.create_empty(width, COLUMNS * row_h + PAD, false, Image.FORMAT_RGBA8)
	out.fill(Color.html("#0e1420"))
	for i: int in COLUMNS:
		var record: Dictionary = AppearanceRules.roll_seeded("sheet-%d" % (first + i), FIELDS[i])
		var y: int = PAD + i * row_h
		var portrait: Image = PortraitPainter.paint(record)
		portrait.convert(Image.FORMAT_RGBA8)
		portrait.resize(head, head, Image.INTERPOLATE_NEAREST)
		out.blit_rect(portrait, Rect2i(Vector2i.ZERO, Vector2i(head, head)), Vector2i(PAD, y))
		var x: int = PAD * 2 + head
		for view: String in BodyFrames.DIRECTIONS:
			for pose: String in BodyFrames.poses():
				for f: int in BodyFrames.frame_count(pose):
					var body: Image = BodyPainter.paint(record, pose, view, f)
					body.resize(cell.x, cell.y, Image.INTERPOLATE_NEAREST)
					out.blend_rect(body, Rect2i(Vector2i.ZERO, cell), Vector2i(x, y))
					x += cell.x + 4
	return out
