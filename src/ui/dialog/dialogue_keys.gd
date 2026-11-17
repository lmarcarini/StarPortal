class_name DialogueKeys
extends RefCounted
## The answer keys of the dialogue screen in the reference's key material: a raised steel
## key on a dark base, lighter under the mouse, ringed in amber when focused, dim when off;
## Barlow Condensed SemiBold in the text colour.
## Bible: docs/content/interface-reference.md section 3 (Key)


## Styles [param button] as a steel key.
static func style(button: Button) -> void:
	button.add_theme_stylebox_override(&"normal", _box(Color8(62, 63, 55), RefPaint.EDGE))
	button.add_theme_stylebox_override(&"hover", _box(Color8(78, 79, 69), RefPaint.EDGE))
	button.add_theme_stylebox_override(&"pressed", _box(Color8(90, 70, 36), RefPaint.AMBER))
	button.add_theme_stylebox_override(&"focus", _ring())
	button.add_theme_stylebox_override(&"disabled", _box(Color8(36, 37, 32), RefPaint.EDGE))
	button.add_theme_font_override(
		&"font", RefText.make(RefText.LABEL, 0, RefPaint.TEXT, 1.0).get_font()
	)
	for colour: StringName in [&"font_color", &"font_hover_color", &"font_focus_color"]:
		button.add_theme_color_override(colour, RefPaint.TEXT)
	button.add_theme_color_override(&"font_pressed_color", RefPaint.AMBER_HI)
	button.add_theme_color_override(&"font_disabled_color", Color8(110, 110, 98))


static func _box(face: Color, edge: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = face
	box.border_color = edge
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.shadow_color = Color8(8, 8, 7)
	box.shadow_size = 1
	box.shadow_offset = Vector2(0, 4)
	box.set_content_margin_all(14.0)
	box.anti_aliasing = true
	return box


static func _ring() -> StyleBoxFlat:
	var ring: StyleBoxFlat = StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = RefPaint.AMBER_HI
	ring.set_border_width_all(2)
	ring.set_corner_radius_all(8)
	ring.set_expand_margin_all(3.0)
	return ring
