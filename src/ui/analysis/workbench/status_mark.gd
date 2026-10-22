class_name StatusMark
extends Control
## The shape that tells a palette glyph's status without relying on colour: a cross for ruled
## out, a filled disc for in the address, nothing for undecided. Colours come from the theme
## (items `ruled_out_color` and `in_address_color` of theme type `StatusMark`), falling back to
## the Label's `font_color`.
## Bible: gate-and-address-spec.md#player-tools,
## game-design.md#difficulty-and-accessibility

## Theme type of this widget's colour items.
const THEME_TYPE: StringName = &"StatusMark"
## Stroke width of the cross, in pixels.
const LINE_WIDTH: float = 2.0
## Share of the control's side the shapes use.
const SHAPE_RATIO: float = 0.4

## The status drawn, a WorkbenchEdits.GlyphStatus.
var status: WorkbenchEdits.GlyphStatus = WorkbenchEdits.GlyphStatus.NEUTRAL:
	set(value):
		status = value
		queue_redraw()


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var reach: float = minf(size.x, size.y) * SHAPE_RATIO
	match status:
		WorkbenchEdits.GlyphStatus.RULED_OUT:
			var color: Color = _color(&"ruled_out_color")
			var offset: Vector2 = Vector2(reach, reach)
			var flipped: Vector2 = Vector2(reach, -reach)
			draw_line(center - offset, center + offset, color, LINE_WIDTH, true)
			draw_line(center - flipped, center + flipped, color, LINE_WIDTH, true)
		WorkbenchEdits.GlyphStatus.IN_ADDRESS:
			draw_circle(center, reach, _color(&"in_address_color"))


func _color(item: StringName) -> Color:
	if has_theme_color(item, THEME_TYPE):
		return get_theme_color(item, THEME_TYPE)
	return get_theme_color(&"font_color", &"Label")
