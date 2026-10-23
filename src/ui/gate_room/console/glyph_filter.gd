class_name GlyphFilter
extends GridContainer
## The Address Book's compact glyph filter: the 36 glyphs as small toggle buttons. Pressing one
## reports it; the book decides what is picked. A picked glyph shows pressed and underlined, so
## it reads by shape as well as colour.
## Bible: gate-and-address-spec.md#the-dial-console (search by glyphs),
## game-design.md#difficulty-and-accessibility

## The player pressed glyph [param glyph].
signal glyph_toggled(glyph: int)

## Side of each glyph icon, in pixels.
const ICON_SIZE: Vector2 = Vector2(20, 20)
const _MARK_HEIGHT: float = 3.0

var _buttons: Array[Button] = []


func _ready() -> void:
	for glyph: int in GateAddress.GLYPH_COUNT:
		_buttons.append(_make_button(glyph))


## Shows the glyphs of [param picked] as pressed. [param translate] is the caller's tr.
func show_picked(picked: Array[int], translate: Callable) -> void:
	for glyph: int in _buttons.size():
		var button: Button = _buttons[glyph]
		button.set_pressed_no_signal(picked.has(glyph))
		var glyph_name: String = str(translate.call(PaletteGlyph.name_key_of(glyph)))
		var key: StringName = &"BOOK_FILTER_GLYPH_ON" if picked.has(glyph) else &"BOOK_FILTER_GLYPH"
		button.tooltip_text = str(translate.call(key)).format({"glyph": glyph_name})
		button.queue_redraw()


## Returns the button of [param glyph], 0..35, or null.
func get_button(glyph: int) -> Button:
	if glyph < 0 or glyph >= _buttons.size():
		return null
	return _buttons[glyph]


func _make_button(glyph: int) -> Button:
	var button := Button.new()
	button.name = "Filter%02d" % glyph
	button.toggle_mode = true
	button.custom_minimum_size = ICON_SIZE + Vector2(8, 8)
	var icon := GlyphIcon.new()
	icon.glyph_index = glyph
	icon.custom_minimum_size = ICON_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4.0
	icon.offset_top = 4.0
	icon.offset_right = -4.0
	icon.offset_bottom = -4.0
	button.add_child(icon)
	button.pressed.connect(func() -> void: glyph_toggled.emit(glyph))
	button.draw.connect(func() -> void: _draw_mark(button))
	add_child(button)
	return button


## Underlines a picked glyph's button.
static func _draw_mark(button: Button) -> void:
	if not button.button_pressed:
		return
	var color: Color = button.get_theme_color(&"font_pressed_color", &"Button")
	var bar := Rect2(0.0, button.size.y - _MARK_HEIGHT, button.size.x, _MARK_HEIGHT)
	button.draw_rect(bar, color)
