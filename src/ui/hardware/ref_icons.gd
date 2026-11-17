class_name RefIcons
extends RefCounted
## The line icons of the interface reference (3 px stroke), drawn as
## tools/reference/render_ref.py draws them. An id this set does not have falls back to
## HardwareIcons.
## Bible: docs/content/interface-reference.md section 3 (Icons)

## Stroke width, in pixels.
const STROKE: float = 3.0
## Ids drawn here; wire action ids map onto them.
const ALIASES: Dictionary[StringName, StringName] = {
	&"hire": &"check",
	&"accept": &"check",
	&"answer": &"check",
	&"pass": &"cross",
	&"decline": &"cross",
	&"ignore": &"cross",
	&"dismiss": &"cross",
	&"go_to": &"arrow",
	&"tree": &"arrow",
	&"log": &"list",
	&"people": &"person",
}

static var _drawers: Dictionary[StringName, Callable] = {}


## Draws icon [param id] in the square [param box] on [param item] in [param ink].
static func draw(item: CanvasItem, id: StringName, box: Rect2, ink: Color) -> void:
	if _drawers.is_empty():
		_drawers = RefIconShapes.drawers()
	var shape: StringName = ALIASES.get(id, id)
	if not _drawers.has(shape):
		HardwareIcons.draw(item, id, box, ink)
		return
	var pen: RefPen = RefPen.new()
	pen.item = item
	pen.c = box.get_center()
	pen.r = box.size.x * 0.5
	pen.ink = ink
	_drawers[shape].call(pen)


## Whether [param id] is drawn by this set (after its alias).
static func has(id: StringName) -> bool:
	if _drawers.is_empty():
		_drawers = RefIconShapes.drawers()
	return _drawers.has(ALIASES.get(id, id))
