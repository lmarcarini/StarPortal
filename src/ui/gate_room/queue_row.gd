class_name QueueRow
extends HBoxContainer
## One address of the dial queue: its glyphs, the charge it needs and when the bank will hold
## it, with a select button (the whole row) and a remove button. Posts requests only.
## Bible: gate-and-address-spec.md#player-tools

## The row was chosen (clicked, or accepted with the gamepad).
signal selected(address: GateAddress)
## The remove button was pressed.
signal remove_requested(address: GateAddress)

var _address: GateAddress = null

@onready var _select_button: Button = %SelectButton
@onready var _strip: AddressStrip = %Strip
@onready var _info: Label = %Info
@onready var _remove_button: Button = %RemoveButton


func _ready() -> void:
	_select_button.pressed.connect(func() -> void: selected.emit(_address))
	_remove_button.pressed.connect(func() -> void: remove_requested.emit(_address))
	_strip.setup(_address)


## Shows [param address]; call before the row enters the tree or after.
func setup(address: GateAddress) -> void:
	_address = address
	if is_node_ready():
		_strip.setup(address)


## Redraws the charge and the "ready in" time from [param state].
func refresh(state: GameState) -> void:
	if _address == null:
		return
	var needed: String = GateRoomFormat.energy(GateQueries.lock_energy_mwh(state, _address))
	var ready_text: String = GateRoomFormat.ready_in(GateQueries.ticks_until_ready(state, _address))
	_info.text = tr("GATE_QUEUE_ROW_INFO").format({"energy": needed, "ready": ready_text})
	_select_button.tooltip_text = GateRoomFormat.address_text(_address)


## Marks the row as the selected one, without posting [signal selected].
func set_selected(is_selected: bool) -> void:
	_select_button.set_pressed_no_signal(is_selected)


## Returns the address of the row.
func get_address() -> GateAddress:
	return _address


## Returns true when the row is marked as selected.
func is_selected() -> bool:
	return _select_button.button_pressed


## Returns the select button, the row's focus target.
func get_select_button() -> Button:
	return _select_button


## Returns the remove button.
func get_remove_button() -> Button:
	return _remove_button


## Returns the label with the charge and the "ready in" time.
func get_info_label() -> Label:
	return _info
