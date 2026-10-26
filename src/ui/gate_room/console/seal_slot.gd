class_name SealSlot
extends Button
## One seal of the dial console: shows the glyph placed there (or CAIRN's origin glyph, locked,
## for seal 8) and takes a glyph by drag and drop. A click or accept, a right-click or the
## Delete or Backspace key asks to clear it (a click clears only a filled slot). Never edits
## the slots itself: it reports what the player did.
## Bible: gate-and-address-spec.md#the-dial-console,
## game-design.md#difficulty-and-accessibility (one-click clearing, dragging)

## The player clicked or accepted this slot.
signal chosen(seal: int)
## The player dropped [param glyph] on this slot.
signal glyph_dropped(seal: int, glyph: int)
## The player asked to empty this slot (right-click, Delete or Backspace).
signal clear_requested(seal: int)

## Space kept around the content, in pixels.
const PADDING: Vector2 = Vector2(4, 4)
## Narrowest the button gets, in pixels.
const MIN_WIDTH: float = 44.0

## Seal number, 1..8; 8 is the origin.
var seal: int = 1

var _glyph: int = -1
var _is_locked: bool = false

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


func _gui_input(event: InputEvent) -> void:
	if _is_locked:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	var is_right_click: bool = (
		mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT
	)
	var is_clear_key: bool = (
		event.is_action_pressed(&"ui_text_delete") or event.is_action_pressed(&"ui_text_backspace")
	)
	if is_right_click or is_clear_key:
		clear_requested.emit(seal)
		accept_event()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return not _is_locked and PaletteGlyph.glyph_from_drag(data) >= 0


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


## Locks the slot ([param locked] true): it shows its glyph but takes no drop or clear.
func set_locked(locked: bool) -> void:
	_is_locked = locked
	disabled = locked


## True while the slot is locked (seal 8, CAIRN's origin).
func is_locked() -> bool:
	return _is_locked


## Returns the glyph shown, or -1.
func get_glyph() -> int:
	return _glyph
