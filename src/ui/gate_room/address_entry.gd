class_name AddressEntry
extends VBoxContainer
## Manual address entry: eight glyph pickers and an "add to queue" button. The address is
## queued with QueueAddressCommand; the dial queue panel shows the result. The button stays
## disabled, with the reason shown, until all eight glyphs are chosen and no glyph repeats.
## Bible: gate-and-address-spec.md#player-tools, game-design.md#core-loop

## An address was queued; the panel clears its pickers.
signal queued(address: GateAddress)

const _PICKER_SCENE: PackedScene = preload("res://src/ui/gate_room/glyph_picker.tscn")
## Translation key of the message for each rejected command code.
const _REJECTION_KEYS: Dictionary[StringName, StringName] = {
	&"already_queued": &"GATE_ENTRY_ALREADY_QUEUED",
	&"queue_full": &"GATE_ENTRY_QUEUE_FULL",
}

var _simulation: Simulation = null
var _pickers: Array[GlyphPicker] = []

@onready var _grid: GridContainer = %Grid
@onready var _add_button: Button = %AddButton
@onready var _message: Label = %Message


func _ready() -> void:
	for number: int in range(1, GateAddress.SEAL_COUNT + 1):
		var picker: GlyphPicker = _PICKER_SCENE.instantiate() as GlyphPicker
		picker.set_seal_number(number)
		picker.glyph_changed.connect(_update_state)
		_grid.add_child(picker)
		_pickers.append(picker)
	_add_button.pressed.connect(_on_add_pressed)
	_update_state()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_state()


## Connects the panel to [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation


## Returns the address typed so far, or null when a picker is empty. It may be malformed
## (a repeated glyph).
func get_entered_address() -> GateAddress:
	var seals: Array[int] = []
	for picker: GlyphPicker in _pickers:
		if picker.get_glyph() < 0:
			return null
		seals.append(picker.get_glyph())
	var origin: int = seals.pop_back()
	return GateAddress.create(seals, origin)


## Chooses every glyph of [param address] in the pickers.
func set_entered_address(address: GateAddress) -> void:
	var seals: Array[int] = address.seals()
	for index: int in _pickers.size():
		_pickers[index].set_glyph(seals[index])
	_update_state()


## Returns the eight pickers in seal order.
func get_pickers() -> Array[GlyphPicker]:
	return _pickers


## Returns the add button.
func get_add_button() -> Button:
	return _add_button


## Returns the message under the pickers: a hint, or why the last add failed.
func get_message_text() -> String:
	return _message.text


## Returns the first picker's drop-down, the panel's focus target.
func get_first_focus() -> Control:
	return _pickers[0].get_option()


func _update_state() -> void:
	var address: GateAddress = get_entered_address()
	var is_valid: bool = address != null and address.is_well_formed()
	_add_button.disabled = not is_valid
	if address == null:
		_message.text = tr("GATE_ENTRY_HINT")
	elif not is_valid:
		_message.text = tr("GATE_ENTRY_DUPLICATE")
	else:
		_message.text = ""


func _on_add_pressed() -> void:
	var address: GateAddress = get_entered_address()
	if _simulation == null or address == null or not address.is_well_formed():
		return
	var result: CommandResult = _simulation.submit(QueueAddressCommand.create(address))
	if not result.is_ok:
		var key: StringName = _REJECTION_KEYS.get(result.error_code, &"GATE_ENTRY_REJECTED")
		_message.text = tr(key)
		return
	queued.emit(address)
	for picker: GlyphPicker in _pickers:
		picker.set_glyph(-1)
	_update_state()
	_pickers[0].get_option().grab_focus()
