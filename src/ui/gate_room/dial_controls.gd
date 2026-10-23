class_name DialControls
extends VBoxContainer
## The dial button of the dial console's address and everything that decides whether it may be
## pressed: the repeat warning and the reason it is disabled. It never shows the charge an
## address needs: a dial the bank cannot power is refused by DialCommand, and the panel then
## says so without numbers. Dialing is a hold-to-confirm; an address that already failed needs
## a second hold. The panel posts a DialCommand and never changes state itself.
## Bible: gate-and-address-spec.md#the-dial-console,
## gate-and-address-spec.md#dialing-outcomes-and-energy,
## game-design.md#difficulty-and-accessibility

## Translation key of the disabled reason for each rejected command code.
const _REJECTION_KEYS: Dictionary[StringName, StringName] = {
	&"ring_busy": &"GATE_REASON_BUSY",
	&"insufficient_charge": &"GATE_DIAL_REJECT_CHARGE",
	&"bad_address": &"GATE_REASON_INCOMPLETE",
}

var _simulation: Simulation = null
var _address: GateAddress = null
var _is_repeat_armed: bool = false
## Key of the last refusal, shown until the address changes or a dial starts; &"" for none.
var _rejection_key: StringName = &""

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


## Connects the controls to [param simulation]; no address is set.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	set_address(null)


## Sets [param address] (null while the console's slots are not all filled) as the address to
## dial and drops a half-done repeat confirmation.
func set_address(address: GateAddress) -> void:
	_address = address
	_is_repeat_armed = false
	_rejection_key = &""
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
	if _simulation == null:
		return &"GATE_REASON_INCOMPLETE"
	var state: GameState = _simulation.state
	if state.gate.mode == GateState.RingMode.DIALING:
		return &"GATE_REASON_DIALING"
	if state.gate.mode == GateState.RingMode.LOCKED:
		return &"GATE_REASON_WORMHOLE_OPEN"
	if _address == null or not _address.is_well_formed():
		return &"GATE_REASON_INCOMPLETE"
	return _bank_reason_key(state.power)


## The reason the bank cannot dial anything: no capacitors, or no charge; &"" when it can try.
static func _bank_reason_key(power: PowerState) -> StringName:
	if power.capacity_mwh <= 0.0:
		return &"GATE_DIAL_NO_CAPACITORS"
	if power.stored_mwh <= 0.0:
		return &"GATE_DIAL_CAPACITORS_EMPTY"
	return &""


func _refresh() -> void:
	_refresh_warning()
	var key: StringName = disabled_reason_key()
	_dial_button.disabled = key != &""
	_dial_button.tooltip_text = "" if key == &"" else tr(key)
	var shown: StringName = key if key != &"" else _rejection_key
	_reason_label.text = "" if shown == &"" else tr(shown)
	_reason_label.visible = shown != &""
	var button_key: StringName = &"GATE_DIAL_HOLD"
	if _is_repeat_armed:
		button_key = &"GATE_DIAL_HOLD_AGAIN"
	_dial_button.text = tr(button_key)


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
	_rejection_key = _REJECTION_KEYS.get(code, &"GATE_REASON_REJECTED")
	_refresh()


func _on_event(_tick: int) -> void:
	_refresh()


func _on_text_event(_address_key: String) -> void:
	_rejection_key = &""
	_refresh()


func _on_outcome_event(_outcome: int, _address_key: String) -> void:
	_refresh()


func _on_closed_event(_reason: StringName) -> void:
	_refresh()
