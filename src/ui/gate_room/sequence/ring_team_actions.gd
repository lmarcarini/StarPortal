class_name RingTeamActions
extends VBoxContainer
## The Ring actions of the open wormhole that throw a probe or move a team, inside
## WormholeActions: Throw the sample canister ($10k; while it is out, when it comes back), Send
## team (only while the ready plan's world is open; greyed with the reason, such as "Not enough
## open time to send a team (10 minutes needed).") and Signal T-1 (only while the rescue window
## is open on the missing team's world; once sent, when the team reaches the Ring). Each posts
## its command (LaunchCanisterCommand, SendTeamCommand, SignalTeamCommand) and redraws at once,
## so it updates while paused. Changes no state itself.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (Sample canister), section 4 (Departure,
## Missed check-in and rescue) and section 7

## The buttons that can take focus changed.
signal focus_changed

var _simulation: Simulation = null
var _canister_button := Button.new()
var _canister_note := Label.new()
var _team_button := Button.new()
var _team_note := Label.new()
var _signal_button := Button.new()
var _signal_note := Label.new()


func _init() -> void:
	add_theme_constant_override(&"separation", 6)
	_canister_button.text = &"GATE_WORMHOLE_CANISTER"
	_team_button.text = &"GATE_WORMHOLE_SEND_TEAM"
	_signal_button.text = &"GATE_WORMHOLE_SIGNAL"
	for pair: Array in [
		[_canister_button, _canister_note],
		[_team_button, _team_note],
		[_signal_button, _signal_note]
	]:
		var button: Button = pair[0]
		var note: Label = pair[1]
		note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override(&"font_size", 13)
		add_child(button)
		add_child(note)
	_canister_button.pressed.connect(_submit.bind(LaunchCanisterCommand.new()))
	_team_button.pressed.connect(_submit.bind(SendTeamCommand.new()))
	_signal_button.pressed.connect(_submit.bind(SignalTeamCommand.new()))


## Connects the actions to [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation


## Shows the actions for the open wormhole of [param state].
func render(state: GameState) -> void:
	_show_canister(state)
	_show_team(state)
	_show_signal(state)


## Returns the buttons that can take focus now, in order.
func get_focusables() -> Array[Control]:
	var found: Array[Control] = []
	for button: Button in [_canister_button, _team_button, _signal_button]:
		if button.visible and not button.disabled:
			found.append(button)
	return found


## Returns the Throw the sample canister button.
func get_canister_button() -> Button:
	return _canister_button


## Returns the Send team button.
func get_team_button() -> Button:
	return _team_button


## Returns the Signal T-1 button.
func get_signal_button() -> Button:
	return _signal_button


## Returns the notes under the three buttons, shown or not, in order.
func get_notes() -> Array[String]:
	var notes: Array[String] = []
	for note: Label in [_canister_note, _team_note, _signal_note]:
		notes.append(note.text if note.visible else "")
	return notes


func _show_canister(state: GameState) -> void:
	var result: CommandResult = LaunchCanisterCommand.new().validate(state)
	_set_enabled(_canister_button, result.is_ok)
	_canister_note.text = RingActionText.canister_note(state, result.error_code)


func _show_team(state: GameState) -> void:
	var plan: ExpeditionState = state.expedition
	var shown: bool = (
		plan.mode == ExpeditionState.Mode.PLANNED and state.gate.connected_world_id == plan.world_id
	)
	_team_button.visible = shown
	_team_note.visible = shown
	if not shown:
		return
	var error: StringName = ExpeditionRules.send_error(state)
	_set_enabled(_team_button, error.is_empty())
	_team_note.text = RingActionText.team_note(state, error)


func _show_signal(state: GameState) -> void:
	var shown: bool = (
		state.expedition.mode == ExpeditionState.Mode.MISSING
		and ExpeditionRescue.is_open_to_team(state)
	)
	_signal_button.visible = shown
	_signal_note.visible = shown
	if not shown:
		return
	_set_enabled(_signal_button, state.expedition.signal_tick < 0)
	_signal_note.text = RingActionText.signal_note(state)


func _set_enabled(button: Button, is_enabled: bool) -> void:
	button.disabled = not is_enabled
	button.focus_mode = Control.FOCUS_ALL if is_enabled else Control.FOCUS_NONE


func _submit(command: Command) -> void:
	if _simulation == null:
		return
	_simulation.submit(command)
	render(_simulation.state)
	focus_changed.emit()
