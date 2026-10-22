class_name SealSlot
extends Button
## One seal of the Address Workbench: shows the glyph placed there (or the origin glyph, for
## the last seal) and takes a glyph by drag and drop or by click after a pick. Never edits the
## draft itself: it reports what the player did.
## Bible: gate-and-address-spec.md#player-tools,
## game-design.md#difficulty-and-accessibility (click-to-pick and click-to-place)

## The player clicked or accepted this slot.
signal chosen(seal: int)
## The player dropped [param glyph] on this slot.
signal glyph_dropped(seal: int, glyph: int)

## Space kept around the content, in pixels.
const PADDING: Vector2 = Vector2(4, 4)
## Narrowest the button gets, in pixels.
const MIN_WIDTH: float = 44.0

## Seal number, 1..8; 8 is the origin.
var seal: int = 1

var _glyph: int = -1

@onready var _content: VBoxContainer = %Content
@onready var _number: Label = %Number
@onready var _icon: GlyphIcon = %Icon


func _ready() -> void:
	pressed.connect(func() -> void: chosen.emit(seal))
	_content.minimum_size_changed.connect(_fit_content)
	_fit_content()
	_number.text = str(seal)


# Button sizes itself from its own text only, so the content's size is passed on as the
# custom minimum.
func _fit_content() -> void:
	var needed: Vector2 = _content.get_combined_minimum_size() + PADDING * 2.0
	custom_minimum_size = Vector2(maxf(MIN_WIDTH, needed.x), needed.y)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return PaletteGlyph.glyph_from_drag(data) >= 0


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var glyph: int = PaletteGlyph.glyph_from_drag(data)
	if glyph >= 0:
		glyph_dropped.emit(seal, glyph)


## Sets the seal number this slot stands for, 1..8.
func set_seal(seal_number: int) -> void:
	seal = seal_number
	if _number != null:
		_number.text = str(seal)


## Shows [param glyph] (-1 for an empty slot), with [param tooltip] saying it in words.
func show_glyph(glyph: int, tooltip: String) -> void:
	_glyph = glyph
	_icon.glyph_index = glyph
	tooltip_text = tooltip


## Returns the glyph shown, or -1.
func get_glyph() -> int:
	return _glyph
