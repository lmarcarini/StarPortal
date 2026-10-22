class_name GlyphPicker
extends VBoxContainer
## Chooses the glyph of one seal: a drop-down of the 36 glyph names (it opens with a click or
## the gamepad accept button) and the glyph's constellation drawn above it.
## Bible: gate-and-address-spec.md#player-tools

## The chosen glyph changed.
signal glyph_changed

## Number of drop-down entries before the first glyph: the "not chosen" entry.
const _UNSET_ITEMS: int = 1

var _seal_number: int = 1

@onready var _seal_label: Label = %SealLabel
@onready var _icon: GlyphIcon = %Icon
@onready var _option: OptionButton = %Option


func _ready() -> void:
	_option.item_selected.connect(_on_item_selected)
	_populate()
	_update_seal_label()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_populate()
		_update_seal_label()


## Sets which seal this picker is for, 1 to 8; it names the picker.
func set_seal_number(number: int) -> void:
	_seal_number = number
	if is_node_ready():
		_update_seal_label()


## Returns the chosen glyph index, or -1 when none is chosen.
func get_glyph() -> int:
	return _option.selected - _UNSET_ITEMS


## Chooses glyph [param index], or none for -1.
func set_glyph(index: int) -> void:
	_option.select(index + _UNSET_ITEMS)
	_icon.glyph_index = index


## Returns the drop-down, the picker's focus target.
func get_option() -> OptionButton:
	return _option


func _populate() -> void:
	var chosen: int = get_glyph() if _option.item_count > 0 else -1
	_option.clear()
	_option.add_item(tr("GATE_ENTRY_UNSET"))
	for index: int in GateAddress.GLYPH_COUNT:
		_option.add_item(GateRoomFormat.glyph_name(index))
	set_glyph(chosen)


func _update_seal_label() -> void:
	var key: String = "GATE_ENTRY_ORIGIN"
	if _seal_number <= GateAddress.COORDINATE_COUNT:
		key = "GATE_ENTRY_SEAL"
	_seal_label.text = tr(key).format({"number": _seal_number})


func _on_item_selected(_item: int) -> void:
	_icon.glyph_index = get_glyph()
	glyph_changed.emit()
