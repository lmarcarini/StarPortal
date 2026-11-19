class_name RefKey
extends Button
## A key of the interface reference: a raised plate on a 4 px dark base, in one of five
## styles (steel, amber, lit, off, hazard), with an icon over a label, a label alone or an
## icon alone, and an optional red lamp in its top right corner. Disabled keys draw off.
## Hover lightens it, focus rings it in amber. Draws itself: the theme's boxes are cleared.
## Bible: docs/content/interface-reference.md sections 3 and 4

## The style shown while enabled.
var style: RefPaint.KeyStyle = RefPaint.KeyStyle.STEEL:
	set(value):
		style = value
		queue_redraw()
## Icon id (RefIcons, else HardwareIcons); empty for none.
var icon_id: StringName = &"":
	set(value):
		icon_id = value
		queue_redraw()
## Label: a translation key or text; empty for none.
var label: String = "":
	set(value):
		label = value
		queue_redraw()
## Label size, in pixels.
var label_size: int = 22
## Red lamp in the top right corner (something needs the player there).
var lamp: bool = false:
	set(value):
		lamp = value
		queue_redraw()

var _card: HoverCard = null


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	for box: StringName in [
		&"normal", &"hover", &"pressed", &"disabled", &"focus", &"hover_pressed"
	]:
		add_theme_stylebox_override(box, StyleBoxEmpty.new())
	for colour: StringName in [
		&"font_color",
		&"font_hover_color",
		&"font_pressed_color",
		&"font_focus_color",
		&"font_disabled_color",
		&"font_hover_pressed_color"
	]:
		add_theme_color_override(colour, Color(0, 0, 0, 0))
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Sets the hover card's help to translation key [param text_key].
func set_help(text_key: String) -> void:
	if _card == null:
		_card = HoverCard.attach(self, text_key)
		return
	_card.set_text(text_key)


## The style drawn now (off while disabled).
func shown_style() -> RefPaint.KeyStyle:
	return RefPaint.KeyStyle.OFF if disabled else style


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var ink: Color = RefPaint.key(self, rect, shown_style())
	if is_hovered() and not disabled:
		draw_polygon(RefPaint.rounded(rect, 6.0), [Color(1, 1, 1, 0.06)])
	var text: String = tr(label)
	if not icon_id.is_empty():
		var side: float = minf(size.x, size.y) * 0.42
		var cy: float = size.y * 0.40 if not text.is_empty() else size.y * 0.5
		var box: Rect2 = Rect2(
			Vector2(size.x * 0.5, cy) - Vector2(side, side) * 0.5, Vector2(side, side)
		)
		RefIcons.draw(self, icon_id, box, ink)
		RefText.make(RefText.LABEL, label_size, ink, 2.0).draw(
			self, Vector2(size.x * 0.5, size.y - 14), text, "ms"
		)
	else:
		RefText.make(RefText.LABEL, label_size, ink, 3.0).draw(
			self, Vector2(size.x * 0.5, size.y * 0.5 + 2), text, "mm"
		)
	if lamp:
		RefPaint.lamp_on(self, Vector2(size.x - 20, 18), 6.0, RefPaint.RED)
	if has_focus():
		RefPaint.outline(self, rect.grow(3.0), RefPaint.AMBER_HI, 2.0)
