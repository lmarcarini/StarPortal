class_name HardwareIcons
extends RefCounted
## Code-drawn line icons for the hardware kit, drawn into any rect on any CanvasItem, so no
## icon waits for art. Each is a few strokes on a unit square.
## Bible: docs/content/interface-rethink.md sections 2 and 7

## Every icon id.
const IDS: Array[StringName] = [
	&"gate",
	&"base",
	&"lab",
	&"office",
	&"camera",
	&"canister",
	&"moth",
	&"team",
	&"hail",
	&"shutter",
	&"probed",
	&"surveyed",
	&"people",
	&"threat",
	&"injured",
	&"clock",
	&"charge",
	&"close",
	&"new",
	&"prev",
	&"next",
	&"pencil",
]


## Draws icon [param id] in [param rect] with [param colour] on [param ci]. Unknown ids draw a
## question mark box. Returns false for an unknown id.
static func draw(ci: CanvasItem, id: StringName, rect: Rect2, colour: Color) -> bool:
	var pen: _Pen = _Pen.new(ci, rect, colour)
	var known: bool = IDS.has(id)
	if not known:
		pen.box(0.2, 0.2, 0.8, 0.8)
		return false
	var script: Script = load("res://src/ui/hardware/hardware_icons.gd")
	script.call("_icon_" + String(id), pen)
	return true


static func _icon_gate(p: _Pen) -> void:
	p.ring(0.5, 0.5, 0.42)
	p.ring(0.5, 0.5, 0.3)
	for i: int in 8:
		var a: float = TAU * i / 8.0
		p.line(0.5 + 0.3 * cos(a), 0.5 + 0.3 * sin(a), 0.5 + 0.42 * cos(a), 0.5 + 0.42 * sin(a))


static func _icon_base(p: _Pen) -> void:
	p.box(0.15, 0.15, 0.85, 0.85)
	p.line(0.15, 0.5, 0.85, 0.5)
	p.line(0.5, 0.15, 0.5, 0.85)


static func _icon_lab(p: _Pen) -> void:
	p.poly([0.4, 0.15, 0.4, 0.45, 0.2, 0.85, 0.8, 0.85, 0.6, 0.45, 0.6, 0.15])
	p.line(0.33, 0.15, 0.67, 0.15)


static func _icon_office(p: _Pen) -> void:
	p.box(0.2, 0.15, 0.8, 0.85)
	for y: float in [0.35, 0.5, 0.65]:
		p.line(0.32, y, 0.68, y)


static func _icon_camera(p: _Pen) -> void:
	p.box(0.12, 0.32, 0.72, 0.72)
	p.poly([0.72, 0.45, 0.9, 0.35, 0.9, 0.7, 0.72, 0.6])
	p.ring(0.42, 0.52, 0.12)


static func _icon_canister(p: _Pen) -> void:
	p.box(0.3, 0.2, 0.7, 0.85)
	p.line(0.38, 0.12, 0.62, 0.12)
	p.line(0.3, 0.4, 0.7, 0.4)


static func _icon_moth(p: _Pen) -> void:
	p.poly([0.5, 0.3, 0.12, 0.2, 0.2, 0.6, 0.5, 0.5, 0.8, 0.6, 0.88, 0.2, 0.5, 0.3])
	p.line(0.5, 0.3, 0.5, 0.8)


static func _icon_team(p: _Pen) -> void:
	for x: float in [0.3, 0.7]:
		p.ring(x, 0.32, 0.1)
		p.poly([x - 0.16, 0.85, x - 0.16, 0.6, x + 0.16, 0.6, x + 0.16, 0.85])
	p.ring(0.5, 0.42, 0.1)


static func _icon_hail(p: _Pen) -> void:
	p.poly(
		[0.2, 0.3, 0.35, 0.2, 0.45, 0.35, 0.38, 0.45, 0.55, 0.62, 0.65, 0.55, 0.8, 0.65, 0.7, 0.8]
	)
	p.line(0.7, 0.8, 0.2, 0.3)


static func _icon_shutter(p: _Pen) -> void:
	p.ring(0.5, 0.5, 0.4)
	for i: int in 6:
		var a: float = TAU * i / 6.0
		p.line(0.5, 0.5, 0.5 + 0.4 * cos(a), 0.5 + 0.4 * sin(a))


static func _icon_probed(p: _Pen) -> void:
	p.ring(0.5, 0.5, 0.35)
	p.ring(0.5, 0.5, 0.08)
	p.line(0.5, 0.05, 0.5, 0.25)


static func _icon_surveyed(p: _Pen) -> void:
	p.poly([0.12, 0.8, 0.38, 0.35, 0.55, 0.6, 0.7, 0.42, 0.88, 0.8, 0.12, 0.8])


static func _icon_people(p: _Pen) -> void:
	p.ring(0.5, 0.3, 0.14)
	p.poly([0.25, 0.85, 0.25, 0.6, 0.75, 0.6, 0.75, 0.85])


static func _icon_threat(p: _Pen) -> void:
	p.poly([0.5, 0.12, 0.9, 0.85, 0.1, 0.85, 0.5, 0.12])
	p.line(0.5, 0.38, 0.5, 0.62)
	p.line(0.5, 0.7, 0.5, 0.75)


static func _icon_injured(p: _Pen) -> void:
	p.poly([0.4, 0.15, 0.6, 0.15, 0.6, 0.4, 0.85, 0.4, 0.85, 0.6, 0.6, 0.6, 0.6, 0.85])
	p.poly([0.6, 0.85, 0.4, 0.85, 0.4, 0.6, 0.15, 0.6, 0.15, 0.4, 0.4, 0.4, 0.4, 0.15])


static func _icon_clock(p: _Pen) -> void:
	p.ring(0.5, 0.5, 0.38)
	p.line(0.5, 0.5, 0.5, 0.25)
	p.line(0.5, 0.5, 0.68, 0.58)


static func _icon_charge(p: _Pen) -> void:
	p.poly([0.58, 0.1, 0.28, 0.55, 0.5, 0.55, 0.42, 0.9, 0.72, 0.45, 0.5, 0.45, 0.58, 0.1])


static func _icon_close(p: _Pen) -> void:
	p.line(0.22, 0.22, 0.78, 0.78)
	p.line(0.78, 0.22, 0.22, 0.78)


static func _icon_new(p: _Pen) -> void:
	p.line(0.5, 0.18, 0.5, 0.82)
	p.line(0.18, 0.5, 0.82, 0.5)


static func _icon_prev(p: _Pen) -> void:
	p.poly([0.65, 0.2, 0.3, 0.5, 0.65, 0.8])


static func _icon_next(p: _Pen) -> void:
	p.poly([0.35, 0.2, 0.7, 0.5, 0.35, 0.8])


static func _icon_pencil(p: _Pen) -> void:
	p.poly([0.2, 0.8, 0.25, 0.62, 0.68, 0.18, 0.82, 0.32, 0.38, 0.75, 0.2, 0.8])
	p.line(0.6, 0.26, 0.74, 0.4)


## Draws strokes in unit coordinates inside a rect.
class _Pen:
	extends RefCounted
	var ci: CanvasItem
	var rect: Rect2
	var colour: Color
	var width: float

	func _init(on: CanvasItem, area: Rect2, ink: Color) -> void:
		ci = on
		rect = area
		colour = ink
		width = maxf(1.5, minf(area.size.x, area.size.y) / 16.0)

	func at(x: float, y: float) -> Vector2:
		return rect.position + Vector2(x, y) * rect.size

	func line(x0: float, y0: float, x1: float, y1: float) -> void:
		ci.draw_line(at(x0, y0), at(x1, y1), colour, width, true)

	func ring(x: float, y: float, r: float) -> void:
		ci.draw_arc(at(x, y), r * minf(rect.size.x, rect.size.y), 0.0, TAU, 40, colour, width, true)

	func box(x0: float, y0: float, x1: float, y1: float) -> void:
		poly([x0, y0, x1, y0, x1, y1, x0, y1, x0, y0])

	func poly(xy: Array[float]) -> void:
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(0, xy.size(), 2):
			pts.append(at(xy[i], xy[i + 1]))
		ci.draw_polyline(pts, colour, width, true)
