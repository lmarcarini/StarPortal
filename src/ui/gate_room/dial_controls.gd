class_name DialControls
extends VBoxContainer
## The dial button of the selected address and everything that decides whether it may be
## pressed: the charge it needs, the repeat warning and the reason it is disabled. Dialing is a
## hold-to-confirm; an address that already failed needs a second hold. The panel posts a
## DialCommand and never changes state itself.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## gate-and-address-spec.md#player-tools, game-design.md#difficulty-and-accessibility

## Translation key of the disabled reason for each rejected command code.
const _REJECTION_KEYS: Dictionary[StringName, StringName] = {
	&"ring_busy": &"GATE_REASON_BUSY",
	&"insufficient_charge": &"GATE_REASON_CHARGE",
	&"bad_address": &"GATE_REASON_NONE_SELECTED",
}

var _simulation: Simulation = null
var _address: GateAddress = null
var _is_repeat_armed: bool = false

@onready var _needs_label: Label = %NeedsLabel
@onready var _warning_label: Label = %WarningLabel
@onready var _reason_label: Label = %ReasonLabel
@onready var _dial_button: HoldButton = %DialButton


func _ready() -> void:
	_dial_button.confirmed.connect(_on_confirmed)
	_refresh()


func _enter_tree() -> void:
	EventBus.tick_advanced.connect(_on_event)
	EventBus.dial_started.connect(_on_text_event)
	EventBus.dial_resolved.connect(_on_outcome_event)
	EventBus.wormhole_closed.connect(_on_closed_event)


func _exit_tree() -> void:
	EventBus.tick_advanced.disconnect(_on_event)
	EventBus.dial_started.disconnect(_on_text_event)
	EventBus.dial_resolved.disconnect(_on_outcome_event)
	EventBus.wormhole_closed.disconnect(_on_closed_event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


## Connects the controls to [param simulation]; nothing is selected.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	set_address(null)


## Selects [param address] (null for none) as the address to dial and drops a half-done
## repeat confirmation.
func set_address(address: GateAddress) -> void:
	_address = address
	_is_repeat_armed = false
	if is_node_ready():
		_refresh()


## Returns the dial button.
func get_dial_button() -> HoldButton:
	return _dial_button


## Returns the text that says why the button is disabled; empty while it is enabled.
func get_reason_text() -> String:
	return _reason_label.text


## Returns the repeat warning's text; empty when the address has not failed before.
func get_warning_text() -> String:
	return _warning_label.text


## True after the first hold of a repeat dial, while the second one is awaited.
func is_repeat_armed() -> bool:
	return _is_repeat_armed


## Returns the translation key of the reason the dial is not possible now, or &"" when it is.
func disabled_reason_key() -> StringName:
	if _simulation == null or _address == null or not _address.is_well_formed():
		return &"GATE_REASON_NONE_SELECTED"
	var state: GameState = _simulation.state
	if state.gate.mode != GateState.RingMode.IDLE:
		return &"GATE_REASON_BUSY"
	if state.power.stored_mwh < GateQueries.lock_energy_mwh(state, _address):
		return &"GATE_REASON_CHARGE"
	return &""


func _refresh() -> void:
	_refresh_needs()
	_refresh_warning()
	var key: StringName = disabled_reason_key()
	_dial_button.disabled = key != &""
	_reason_label.text = "" if key == &"" else _reason_text(key)
	_reason_label.visible = key != &""
	_dial_button.tooltip_text = _reason_label.text
	var button_key: StringName = &"GATE_DIAL_HOLD"
	if _is_repeat_armed:
		button_key = &"GATE_DIAL_HOLD_AGAIN"
	_dial_button.text = tr(button_key)


func _refresh_needs() -> void:
	_needs_label.visible = _address != null and _simulation != null
	if not _needs_label.visible:
		return
	var state: GameState = _simulation.state
	var needed: float = GateQueries.lock_energy_mwh(state, _address)
	_needs_label.text = (
		tr("GATE_DIAL_NEEDS")
		. format(
			{
				"energy": GateRoomFormat.energy(needed),
				"ready": GateRoomFormat.ready_in(GateQueries.ticks_until_ready(state, _address)),
			}
		)
	)


func _refresh_warning() -> void:
	var last: DialLogEntry = _last_failure()
	_warning_label.visible = last != null
	if last == null:
		_warning_label.text = ""
		return
	_warning_label.text = (
		tr("GATE_REPEAT_WARNING")
		. format(
			{
				"date": GateRoomFormat.date_time(last.tick),
				"outcome": GateRoomFormat.outcome_name(last.outcome),
			}
		)
	)


## Returns the newest Dial Log entry of the selected address that failed, or null.
func _last_failure() -> DialLogEntry:
	if _simulation == null or _address == null or not _address.is_well_formed():
		return null
	var found: DialLogEntry = null
	for entry: DialLogEntry in GateQueries.previous_attempts(_simulation.state, _address):
		if GateRoomFormat.is_failure(entry.outcome):
			found = entry
	return found


func _reason_text(key: StringName) -> String:
	if key != &"GATE_REASON_CHARGE" or _simulation == null:
		return tr(key)
	var state: GameState = _simulation.state
	return (
		tr(key)
		. format(
			{
				"needed": GateRoomFormat.energy(GateQueries.lock_energy_mwh(state, _address)),
				"stored": GateRoomFormat.energy(state.power.stored_mwh),
			}
		)
	)


func _on_confirmed() -> void:
	if _simulation == null or _address == null or disabled_reason_key() != &"":
		return
	if _last_failure() != null and not _is_repeat_armed:
		_is_repeat_armed = true
		_refresh()
		return
	_is_repeat_armed = false
	var result: CommandResult = _simulation.submit(DialCommand.create(_address))
	_refresh()
	if not result.is_ok:
		_show_rejection(result.error_code)


func _show_rejection(code: StringName) -> void:
	var key: StringName = _REJECTION_KEYS.get(code, &"GATE_REASON_REJECTED")
	_reason_label.text = tr(key)
	_reason_label.visible = true


func _on_event(_tick: int) -> void:
	_refresh()


func _on_text_event(_address_key: String) -> void:
	_refresh()


func _on_outcome_event(_outcome: int, _address_key: String) -> void:
	_refresh()


func _on_closed_event(_reason: StringName) -> void:
	_refresh()
