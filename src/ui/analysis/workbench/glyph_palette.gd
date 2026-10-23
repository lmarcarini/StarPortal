class_name GlyphPalette
extends GridContainer
## All 36 glyphs of the Address Workbench, each with its name. Reports picks and shows which
## glyph is picked; changes nothing else.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## game-design.md#difficulty-and-accessibility (click-to-pick, dragging)

## The player pressed glyph [param glyph].
signal glyph_chosen(glyph: int)

const _GLYPH_SCENE: PackedScene = preload("res://src/ui/analysis/workbench/palette_glyph.tscn")

var _buttons: Array[PaletteGlyph] = []


func _ready() -> void:
	for glyph: int in GateAddress.GLYPH_COUNT:
		var button: PaletteGlyph = _GLYPH_SCENE.instantiate() as PaletteGlyph
		button.name = "Glyph%02d" % glyph
		button.set_glyph(glyph)
		button.chosen.connect(glyph_chosen.emit)
		add_child(button)
		_buttons.append(button)


## Marks [param picked] (-1 for none) as pressed and names each glyph in its tooltip.
## [param translate] is the caller's tr.
func show_picked(picked: int, translate: Callable) -> void:
	for button: PaletteGlyph in _buttons:
		var tooltip: String = str(translate.call(PaletteGlyph.name_key_of(button.glyph)))
		button.show_picked(button.glyph == picked, tooltip)


## Returns the button of [param glyph], 0..35, or null.
func get_button(glyph: int) -> PaletteGlyph:
	if glyph < 0 or glyph >= _buttons.size():
		return null
	return _buttons[glyph]
