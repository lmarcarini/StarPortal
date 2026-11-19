class_name BaseLayout
extends RefCounted
## The Base station's regions at 1920 x 1080 (docs/reference/layout.json, interface-reference.md
## section 8). A wider window moves the room panel right by the extra width and widens the
## table; nothing else moves.
## Bible: docs/content/interface-reference.md sections 1 and 8

const REGIONS: Dictionary[StringName, Rect2] = {
	&"base_levels": Rect2(408, 300, 64, 240),
	&"base_dig": Rect2(408, 552, 64, 88),
	&"base_table": Rect2(484, 96, 1040, 768),
	&"base_glass": Rect2(508, 120, 992, 720),
	&"base_console_modes": Rect2(668, 908, 120, 144),
	&"base_console_tray": Rect2(800, 908, 692, 144),
	&"room_panel": Rect2(1536, 92, 368, 772),
}


## Region [param id] for a view [param width] wide.
static func region(id: StringName, width: float) -> Rect2:
	var r: Rect2 = REGIONS[id]
	var extra: float = maxf(0.0, width - FrameLayout.WIDTH)
	if id == &"room_panel":
		r.position.x += extra
	elif id == &"base_table" or id == &"base_glass":
		r.size.x += extra
	return r


## Puts [param control] on region [param id] in a view [param width] wide.
static func place(control: Control, id: StringName, width: float) -> void:
	var r: Rect2 = region(id, width)
	control.position = r.position
	control.size = r.size
