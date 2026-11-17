class_name FrameBand
extends Control
## The frame's two bands (interface-reference.md section 4): the dark band under the top
## plates (76 px) and the bottom bar (200 px, full width): steel with a hazard-patterned lip
## on top. Draws behind the frame's plates and keys; never takes the mouse.
## Bible: docs/content/interface-reference.md section 4

## Heights at 1920 x 1080, in pixels.
const TOP: float = 76.0
const BOTTOM: float = 200.0


func _init() -> void:
	name = &"FrameBand"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	var top: Rect2 = Rect2(0, 0, size.x, TOP)
	RefPaint.gradient(self, top, 0.0, [Color8(24, 25, 22), Color8(14, 15, 13)])
	draw_line(Vector2(0, TOP - 1), Vector2(size.x, TOP - 1), RefPaint.EDGE, 2.0)
	var y: float = size.y - BOTTOM
	var bar: Rect2 = Rect2(0, y, size.x, BOTTOM)
	RefPaint.gradient(self, bar, 0.0, [Color8(40, 41, 36), Color8(18, 19, 16)])
	RefPaint.grain(self, bar, 1.0)
	draw_rect(Rect2(0, y, size.x, 7), Color8(64, 65, 57))
	draw_line(Vector2(0, y + 1), Vector2(size.x, y + 1), RefPaint.EDGE, 3.0)
	var k: float = 0.0
	while k < size.x:
		var lip: PackedVector2Array = [
			Vector2(k, y + 6),
			Vector2(k + 17, y + 6),
			Vector2(k + 23, y + 12),
			Vector2(k + 6, y + 12)
		]
		draw_colored_polygon(lip, Color8(48, 44, 30))
		k += RefHazard.PERIOD
