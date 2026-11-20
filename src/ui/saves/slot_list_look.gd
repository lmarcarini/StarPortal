class_name SlotListLook
extends RefCounted
## The save slot list's pieces in the interface reference's style (M6-08): steel keys, a
## recessed name field with amber mono text, and the note in light stencil letters.
## Bible: docs/content/interface-reference.md sections 3 and 4


## Makes [param key] a steel key labelled [param label], [param width] px wide.
static func key(key: RefKey, label: StringName, width: float) -> void:
	key.label = TranslationServer.translate(label).to_upper()
	key.label_size = 18
	key.custom_minimum_size = Vector2(width, 52)


## A recessed well for [param field].
static func field(field: LineEdit) -> void:
	for box_name: StringName in [&"normal", &"focus", &"read_only"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color8(16, 17, 15)
		box.border_color = RefPaint.AMBER_HI if box_name == &"focus" else RefPaint.EDGE
		box.set_border_width_all(2)
		box.set_corner_radius_all(4)
		box.content_margin_left = 14
		box.content_margin_right = 14
		field.add_theme_stylebox_override(box_name, box)
	field.custom_minimum_size.y = 52
	field.add_theme_font_override(
		&"font", RefText.make(RefText.MONO_BOLD, 0, RefPaint.AMBER).get_font()
	)
	field.add_theme_font_size_override(&"font_size", 18)
	field.add_theme_color_override(&"font_color", RefPaint.AMBER)
	field.add_theme_color_override(&"font_placeholder_color", RefPaint.DIM)


## The hint or confirm line.
static func note(label: Label) -> void:
	label.add_theme_font_override(
		&"font", RefText.make(RefText.LABEL, 0, RefPaint.TEXT, 1.0).get_font()
	)
	label.add_theme_font_size_override(&"font_size", 18)
	label.add_theme_color_override(&"font_color", RefPaint.TEXT)


## A recessed well behind [param scroll]'s rows.
static func well(scroll: ScrollContainer) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color8(16, 17, 15)
	box.border_color = RefPaint.EDGE
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(8)
	scroll.add_theme_stylebox_override(&"panel", box)
