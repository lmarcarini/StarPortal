class_name WormholePanel
extends VBoxContainer
## The open wormhole: the destination's designation (known only after a lock), the minutes
## left of the maximum open time, the current power drain and a Close button, which posts
## CloseWormholeCommand. When the wormhole closes the panel says why (the player, the timer
## or the power) until the next dial starts. Hidden while there is nothing to say.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy, game-design.md#core-loop

## Translation key of the message for each close reason.
const _CLOSED_KEYS: Dictionary[StringName, StringName] = {
	&"player": &"GATE_CLOSED_PLAYER",
	&"timeout": &"GATE_CLOSED_TIMEOUT",
	&"power": &"GATE_CLOSED_POWER",
}

var _simulation: Simulation = null
var _closed_reason: StringName = &""

@onready var _open_box: VBoxContainer = %OpenBox
@onready var _destination: Label = %Destination
@onready var _time_left: Label = %TimeLeft
@onready var _drain: Label = %Drain
@onready var _close_button: Button = %CloseButton
@onready var _closed_label: Label = %ClosedLabel


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_refresh()


func _enter_tree() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.dial_started.connect(_on_dial_started)
	EventBus.dial_resolved.connect(_on_dial_resolved)
	EventBus.wormhole_closed.connect(_on_wormhole_closed)


func _exit_tree() -> void:
	EventBus.tick_advanced.disconnect(_on_tick_advanced)
	EventBus.dial_started.disconnect(_on_dial_started)
	EventBus.dial_resolved.disconnect(_on_dial_resolved)
	EventBus.wormhole_closed.disconnect(_on_wormhole_closed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


## Connects the panel to [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_closed_reason = &""
	if is_node_ready():
		_refresh()


## Returns the Close button.
func get_close_button() -> Button:
	return _close_button


## Returns the destination line; empty unless a wormhole is open.
func get_destination_text() -> String:
	return _destination.text if _open_box.visible else ""


## Returns the time-left line.
func get_time_left_text() -> String:
	return _time_left.text


## Returns the drain line.
func get_drain_text() -> String:
	return _drain.text


## Returns the "wormhole closed" message; empty unless one is shown.
func get_closed_text() -> String:
	return _closed_label.text if _closed_label.visible else ""


func _refresh() -> void:
	var is_open: bool = _simulation != null and _is_locked()
	_open_box.visible = is_open
	_closed_label.visible = not is_open and _closed_reason != &""
	visible = is_open or _closed_label.visible
	if is_open:
		_show_open(_simulation.state)
	if _closed_label.visible:
		var key: StringName = _CLOSED_KEYS.get(_closed_reason, &"GATE_CLOSED_OTHER")
		_closed_label.text = tr(key)


func _is_locked() -> bool:
	return _simulation.state.gate.mode == GateState.RingMode.LOCKED


func _show_open(state: GameState) -> void:
	var designation: String = _designation(state)
	_destination.text = tr("GATE_WORMHOLE_DESTINATION").format({"designation": designation})
	_time_left.text = (
		tr("GATE_WORMHOLE_TIME_LEFT")
		. format(
			{
				"left": GateRoomFormat.duration(GateQueries.open_ticks_left(state)),
				"total": GateRoomFormat.duration(state.balance.max_open_ticks),
			}
		)
	)
	var drain_text: String = String.num(PowerMath.drain_mw(state.gate, state.balance), 1)
	_drain.text = tr("GATE_WORMHOLE_DRAIN").format({"power": drain_text})


## Designation of the connected world. Only called while LOCKED, so the player has a lock.
func _designation(state: GameState) -> String:
	var world: WorldRecord = state.galaxy.get_world(state.gate.connected_world_id)
	if world == null or world.designation.is_empty():
		return tr("GATE_WORMHOLE_UNNAMED")
	return world.designation


func _on_close_pressed() -> void:
	if _simulation != null:
		_simulation.submit(CloseWormholeCommand.new())


func _on_tick_advanced(_tick: int) -> void:
	_refresh()


func _on_dial_started(_address_key: String) -> void:
	_closed_reason = &""
	_refresh()


func _on_dial_resolved(_outcome: int, _address_key: String) -> void:
	_refresh()


func _on_wormhole_closed(reason: StringName) -> void:
	_closed_reason = reason
	_refresh()
