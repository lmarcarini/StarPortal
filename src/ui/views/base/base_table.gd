class_name BaseTable
extends Control
## The Base station's furniture behind its controls (interface-reference.md section 8): the
## steel ground of the station area, the table plate with its dark glass, and the room panel's
## steel plate. Never takes the mouse.
## Bible: docs/content/interface-reference.md section 8


func _init() -> void:
	name = &"BaseTable"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	RefPaint.gradient(
		self, Rect2(Vector2.ZERO, size), 0.0, [Color8(50, 52, 45), Color8(28, 29, 25)]
	)
	RefPaint.grain(self, Rect2(Vector2.ZERO, size), 1.2)
	RefPaint.steel_plate(self, BaseLayout.region(&"base_table", size.x), false, true)
	var glass: Rect2 = BaseLayout.region(&"base_glass", size.x)
	RefPaint.gradient(self, glass, 6.0, [Color8(16, 22, 22), Color8(10, 14, 14)])
	RefPaint.outline(self, glass, RefPaint.EDGE, 4.0)
	RefPaint.steel_plate(self, BaseLayout.region(&"room_panel", size.x), false, true)
