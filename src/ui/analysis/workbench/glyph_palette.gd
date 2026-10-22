class_name GlyphPalette
extends GridContainer
## All 36 glyphs of the Address Workbench, each with its name and its status in the draft
## (undecided, ruled out, in the address). Reports picks; never edits the draft.
## Bible: gate-and-address-spec.md#player-tools

## The player pressed glyph [param glyph].
signal glyph_chosen(glyph: int)

## Status key per WorkbenchEdits.GlyphStatus, in enum order.
const STATUS_KEYS: Array[StringName] = [
	&"WORKBENCH_STATUS_NEUTRAL", &"WORKBENCH_STATUS_RULED_OUT", &"WORKBENCH_STATUS_IN_ADDRESS"
]

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


## Shows each glyph's status in [param constraints] and marks [param picked] (-1 for none) as
## pressed. [param translate] is the caller's tr.
func show_draft(constraints: Array[AddressConstraint], picked: int, translate: Callable) -> void:
	var template: String = str(translate.call("WORKBENCH_PALETTE_TOOLTIP"))
	for button: PaletteGlyph in _buttons:
		var status: WorkbenchEdits.GlyphStatus = WorkbenchEdits.glyph_status(
			constraints, button.glyph
		)
		var tooltip: String = (
			template
			. format(
				{
					"glyph": WorkbenchText.glyph_name(button.glyph, translate),
					"status": str(translate.call(STATUS_KEYS[status])),
				}
			)
		)
		button.show_status(status, button.glyph == picked, tooltip)


## Returns the button of [param glyph], 0..35, or null.
func get_button(glyph: int) -> PaletteGlyph:
	if glyph < 0 or glyph >= _buttons.size():
		return null
	return _buttons[glyph]
