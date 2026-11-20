class_name SlotRow
extends Button
## A save slot row in the interface reference's style: a steel key, full width, its slot
## name in stencil letters and, under it, the rest of [member Button.text] (date, game time,
## or why it cannot load) in a dim mono line. Disabled rows draw off. Draws itself.
## Bible: docs/content/interface-reference.md sections 3 and 4

## Height of a row, in pixels.
const HEIGHT: float = 58.0


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	custom_minimum_size.y = HEIGHT
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RefKeyLook.clear_boxes(self)
	for colour: StringName in [
		&"font_color",
		&"font_hover_color",
		&"font_pressed_color",
		&"font_focus_color",
		&"font_disabled_color",
		&"font_hover_pressed_color"
	]:
		add_theme_color_override(colour, Color(0, 0, 0, 0))
	for event: Signal in [focus_entered, focus_exited, mouse_entered, mouse_exited]:
		event.connect(queue_redraw)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var style: RefPaint.KeyStyle = RefPaint.KeyStyle.OFF if disabled else RefPaint.KeyStyle.STEEL
	var ink: Color = RefPaint.key(self, rect, style)
	if is_hovered() and not disabled:
		draw_polygon(RefPaint.rounded(rect, 6.0), [Color(1, 1, 1, 0.06)])
	var parts: PackedStringArray = text.split(" · ", true, 1)
	var head: RefText = RefText.make(RefText.LABEL, 18, ink, 1.5)
	head.draw(self, Vector2(18, 19), parts[0].to_upper(), "lm")
	if parts.size() > 1:
		var dim: Color = RefPaint.DIM if not disabled else Color(RefPaint.DIM, 0.6)
		RefText.make(RefText.MONO, 13, dim).draw(self, Vector2(18, 40), parts[1], "lm")
	if has_focus():
		RefPaint.outline(self, rect.grow(3.0), RefPaint.AMBER_HI, 2.0)
