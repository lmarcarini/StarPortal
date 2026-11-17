class_name SendRail
extends HBoxContainer
## The send rail on the floor right of the ramp while a wormhole is open
## (interface-reference.md section 5, send_rail): CAMERA, CANISTER, MOTH, TEAM and HAIL as
## 96 x 100 keys 10 px apart, icon over label, badges as paper discs; used keys are off, the
## key whose sheet is open is lit (states and hover reasons from [SendRailRules]); a small
## STAND BY key after them while the gate operates. The far console key lives beside the
## Gate's locker in the right panel's header (the host moves it there). A press operates the
## gate first if it is standing by, then submits the key's command; a refusal becomes the
## key's hover reason. Keys 1 to 5 press them.
## Bible: docs/content/interface-rethink.md section 4 (Gate, With a wormhole open)

## Key [param id]'s command was accepted.
signal key_used(id: StringName)
## TEAM was pressed while a team can be sent (the mission sheet opens on it, M4.9-10).
signal team_requested

## Actions that press keys 1 to 5.
const RAIL_ACTIONS: Array[StringName] = [
	&"dialog_choice_1",
	&"dialog_choice_2",
	&"dialog_choice_3",
	&"dialog_choice_4",
	&"station_rail_5"
]

## Key size, in pixels.
const CAP_SIZE: Vector2 = Vector2(96, 100)

## When set, TEAM emits team_requested instead of sending at once.
var team_opens_sheet: bool = false

var _simulation: Simulation = null
var _keys: Dictionary[StringName, IconKey] = {}
var _stand_by: IconKey = IconKey.new()


func _ready() -> void:
	add_theme_constant_override(&"separation", 10)
	for id: StringName in SendRailRules.KEYS:
		var key: IconKey = IconKey.new()
		key.name = "Rail" + String(id).capitalize()
		key.icon_id = id
		key.look = IconKey.Look.STEEL
		key.label = "STATION_RAIL_" + String(id).to_upper()
		key.pressed.connect(press.bind(id))
		_keys[id] = key
		add_child(key)
	_stand_by.name = "StandBy"
	_stand_by.icon_id = &"clock"
	_stand_by.set_help("STATION_STAND_BY")
	_stand_by.pressed.connect(stand_by)
	add_child(_stand_by)
	_stand_by.look = IconKey.Look.STEEL
	_stand_by.custom_minimum_size = Vector2(44, 44)
	_stand_by.size_flags_vertical = Control.SIZE_SHRINK_END
	for key: IconKey in _keys.values():
		key.custom_minimum_size = CAP_SIZE
	_keys[&"console"].label = ""
	_keys[&"console"].custom_minimum_size = Vector2(44, 44)


## Reads [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	refresh()


## Shows the rail for the state now (hidden while no wormhole is open).
func refresh() -> void:
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	visible = SendRailRules.is_shown(state)
	if not visible:
		_keys[&"console"].visible = false
		return
	for look: SendRailRules.KeyLook in SendRailRules.looks(state):
		var key: IconKey = _keys[look.id]
		key.visible = look.shown
		key.set_state(look.state as IconKey.KeyState)
		key.badge_text = look.badge
		key.set_help(String(look.reason))
	_stand_by.visible = state.gate.operating and not state.gate.is_incoming_lock()


## Presses key [param id].
func press(id: StringName) -> void:
	if (
		_simulation == null
		or not SendRailRules.is_shown(_simulation.state)
		or not _keys[id].visible
	):
		return
	var state: GameState = _simulation.state
	if id == &"team" and team_opens_sheet and not SignalTeamCommand.new().validate(state).is_ok:
		team_requested.emit()
		return
	var command: Command = SendRailRules.command_for(state, id)
	if command == null:
		return
	if not state.gate.operating and not state.gate.is_incoming_lock():
		_simulation.submit(OperateGateCommand.new())
	var result: CommandResult = _simulation.submit(command)
	refresh()
	if not result.is_ok:
		_keys[id].set_help(String(SendRailRules.reason_key(result.error_code)))
		return
	key_used.emit(id)


## Stands by: the wormhole stays open, the gate stops slowing the clock.
func stand_by() -> void:
	if _simulation != null and _simulation.state.gate.operating:
		_simulation.submit(StandByCommand.new())
	refresh()


## Moves the far console key (the reference's rail has five keys) into [param holder].
func move_console_key(holder: Control) -> void:
	_keys[&"console"].reparent(holder)


## The key for [param id].
func get_key(id: StringName) -> IconKey:
	return _keys[id]


func _process(_delta: float) -> void:
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	for index: int in RAIL_ACTIONS.size():
		if event.is_action_pressed(RAIL_ACTIONS[index]):
			press(SendRailRules.KEYS[index])
			get_viewport().set_input_as_handled()
			return
