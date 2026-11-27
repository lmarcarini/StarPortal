extends Node
## Writes a sheet of 20 portraits drawn by the Godot painter, laid out like the reference
## (docs/reference/portraits_sheet.png): 3× scale, five columns (Military, Office, Science,
## Engineering, Medicine), 12 px gaps. Records are AppearanceRules.roll_seeded("sheet-<n>").
## Run: godot --headless --path . res://tools/portraits/sheet.tscn -- [out.png] [first seed]
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
	var error: Error = sheet(first).save_png(path)
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
