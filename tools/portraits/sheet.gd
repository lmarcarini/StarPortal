extends Node
## Writes a sheet of 20 portraits drawn by the Godot painter, laid out like the reference
## (docs/reference/portraits_sheet.png): 3× scale, five columns (Military, Office, Science,
## Engineering, Medicine), 12 px gaps. Records are AppearanceRules.roll_seeded("sheet-<n>").
## With a third argument "bodies" it writes the body sheet instead (body_sheet()), with
## "close" one person's row at 4×, with "builds" the build and height lineup (builds_sheet()).
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
	var mode: String = args[2] if args.size() > 2 else ""
	var image: Image = sheet(first)
	if mode == "bodies":
		image = body_sheet(first, COLUMNS, SCALE)
	elif mode == "close":
		image = body_sheet(first, 1, 4)
	elif mode == "builds":
		image = builds_sheet(first)
	var error: Error = image.save_png(path)
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


## [param people] rows, one per field (seeds from [param first], as sheet()): the portrait,
## then every frame of every pose × direction of the full-body sprite, at [param scale]×.
static func body_sheet(first: int, people: int, scale: int) -> Image:
	var cell := Vector2i(BodyPainter.W * scale, BodyPainter.H * scale)
	var frames: int = 0
	for pose: String in BodyFrames.poses():
		frames += BodyFrames.frame_count(pose) * BodyFrames.DIRECTIONS.size()
	var head: int = PortraitPainter.SIZE * scale
	var width: int = PAD + head + PAD + frames * (cell.x + 4) + PAD
	var row_h: int = cell.y + PAD
	var out := Image.create_empty(width, people * row_h + PAD, false, Image.FORMAT_RGBA8)
	out.fill(Color.html("#0e1420"))
	for i: int in people:
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


## M8-05 lineup at 3×, idle front, on a baseline: row 1 the same person (seed [param first])
## with only "build" changed (slim, average, broad) and then only "height" changed (-4..+3);
## row 2 ten people (seeds from [param first]) with their rolled build and height.
static func builds_sheet(first: int) -> Image:
	var cell := Vector2i(BodyPainter.W * SCALE, BodyPainter.H * SCALE)
	var looks: Array[Dictionary] = []
	var person: Dictionary = AppearanceRules.roll_seeded("sheet-%d" % first, FIELDS[0])
	for build: String in AppearanceRules.BUILDS:
		looks.append(person.merged({"build": build, "height": 0}, true))
	for h: int in range(AppearanceRules.HEIGHT_MIN, AppearanceRules.HEIGHT_MAX + 1):
		looks.append(person.merged({"height": h}, true))
	for i: int in 11:
		looks.append(AppearanceRules.roll_seeded("sheet-%d" % (first + i), FIELDS[i % COLUMNS]))
	var per_row: int = 11
	var out := Image.create_empty(
		PAD + per_row * (cell.x + 4), 2 * (cell.y + PAD) + PAD, false, Image.FORMAT_RGBA8
	)
	out.fill(Color.html("#0e1420"))
	for i: int in looks.size():
		var at := Vector2i(PAD + (i % per_row) * (cell.x + 4), PAD + (i / per_row) * (cell.y + PAD))
		var body: Image = BodyPainter.paint(looks[i], "idle", "front", 0)
		body.resize(cell.x, cell.y, Image.INTERPOLATE_NEAREST)
		out.blend_rect(body, Rect2i(Vector2i.ZERO, cell), at)
		out.fill_rect(
			Rect2i(at.x, at.y + (BodyPainter.BASELINE + 1) * SCALE, cell.x, 1), Color.GRAY
		)
	return out
