class_name GlyphPalette
extends GridContainer
## All 36 glyphs of the dial console, each with its name. Reports clicks; shows which glyphs
## are placed in a slot and which is CAIRN's locked origin. Nothing else: no counts, no
## rule-outs.
## Bible: gate-and-address-spec.md#the-dial-console,
## game-design.md#difficulty-and-accessibility (one-click placing, dragging)

## The player clicked or accepted glyph [param glyph].
signal glyph_chosen(glyph: int)

const _GLYPH_SCENE: PackedScene = preload("res://src/ui/gate_room/console/palette_glyph.tscn")

var _buttons: Array[PaletteGlyph] = []


func _ready() -> void:
	for glyph: int in GateAddress.GLYPH_COUNT:
		var button: PaletteGlyph = _GLYPH_SCENE.instantiate() as PaletteGlyph
		button.name = "Glyph%02d" % glyph
		button.set_glyph(glyph)
		button.chosen.connect(glyph_chosen.emit)
		add_child(button)
		_buttons.append(button)


## Highlights every glyph in [param placed] and locks [param origin] (-1 for none), naming each
## glyph in its tooltip. [param translate] is the caller's tr.
func show_state(placed: Array[int], origin: int, translate: Callable) -> void:
	for button: PaletteGlyph in _buttons:
		var glyph_name: String = str(translate.call(PaletteGlyph.name_key_of(button.glyph)))
		var locked: bool = button.glyph == origin
		button.set_locked(locked)
		var tooltip: String = glyph_name
		if locked:
			tooltip = str(translate.call(&"CONSOLE_GLYPH_ORIGIN_LOCKED")).format(
				{"glyph": glyph_name}
			)
		elif placed.has(button.glyph):
			tooltip = str(translate.call(&"CONSOLE_GLYPH_PLACED")).format({"glyph": glyph_name})
		button.show_state(placed.has(button.glyph), tooltip)


## Returns the button of [param glyph], 0..35, or null.
func get_button(glyph: int) -> PaletteGlyph:
	if glyph < 0 or glyph >= _buttons.size():
		return null
	return _buttons[glyph]


## Returns the glyphs highlighted as placed, in glyph order.
func get_highlighted() -> Array[int]:
	var found: Array[int] = []
	for button: PaletteGlyph in _buttons:
		if button.is_placed():
			found.append(button.glyph)
	return found


## Returns the first glyph button that is not locked, the palette's focus target.
func get_first_focus() -> Control:
	for button: PaletteGlyph in _buttons:
		if not button.is_locked():
			return button
	return null
