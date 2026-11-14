class_name GateFocus
extends Node
## Brings the gate to the front on a lock (docs/content/event-time.md section 3): with the
## gameplay/switch_to_gate_on_lock setting on and no conversation or incursion running, a
## lock opens the Gate Room tab and operates the gate (OperateGateCommand, slow). Otherwise
## the open wormhole shows as an alert. Leaving the Gate Room tab stands by.
## Bible: docs/content/event-time.md section 3

## The section and key of the setting that turns the automatic tab switch on.
const SETTING_SECTION: StringName = &"gameplay"
## See SETTING_SECTION.
const SETTING_KEY: StringName = &"switch_to_gate_on_lock"

var _switcher: ViewSwitcher = null


## Watches [param switcher] for the player leaving the Gate Room.
func attach(switcher: ViewSwitcher) -> void:
	_switcher = switcher
	switcher.view_changed.connect(_on_view_changed)


func _enter_tree() -> void:
	EventBus.dial_resolved.connect(_on_dial_resolved)


func _exit_tree() -> void:
	EventBus.dial_resolved.disconnect(_on_dial_resolved)


## True when a lock in [param state] should switch to the Gate Room and operate the gate.
static func should_switch(state: GameState, setting_on: bool) -> bool:
	if not setting_on or state.conversations.active != null:
		return false
	for key: StringName in state.clock.slows:
		if TimeControl.reason_of(key) == &"incursion":
			return false
	return state.gate.mode == GateState.RingMode.LOCKED and not state.gate.operating


func _on_dial_resolved(outcome: int, _address_key: String) -> void:
	var simulation: Simulation = SimClock.simulation
	if (
		simulation == null
		or _switcher == null
		or not DialOutcome.is_lock(outcome as DialOutcome.Kind)
	):
		return
	if not should_switch(simulation.state, Settings.get_bool(SETTING_SECTION, SETTING_KEY)):
		return
	_switcher.show_view(ViewSwitcher.GATE_ROOM)
	simulation.submit(OperateGateCommand.new())


func _on_view_changed(view_id: StringName) -> void:
	var simulation: Simulation = SimClock.simulation
	if simulation == null or view_id == ViewSwitcher.GATE_ROOM:
		return
	if simulation.state.gate.operating:
		simulation.submit(StandByCommand.new())
