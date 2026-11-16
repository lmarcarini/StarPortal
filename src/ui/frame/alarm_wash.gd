class_name AlarmWash
extends Control
## The alarm look over the whole screen (M4c-11): a faint red wash and red rules at the
## edges. Drawn on top, ignores the mouse, changes no layout.
## Bible: docs/content/m4c-incursions.md section 7

const _WASH: Color = Color(0.9, 0.2, 0.15, 0.06)
const _RULE_WIDTH: float = 4.0


func _init() -> void:
	name = &"AlarmWash"
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100


func _process(_delta: float) -> void:
	if visible and size != get_viewport_rect().size:
		position = Vector2.ZERO
		size = get_viewport_rect().size
		queue_redraw()


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, _WASH)
	draw_rect(area.grow(-_RULE_WIDTH * 0.5), UiPalette.ALARM, false, _RULE_WIDTH)
