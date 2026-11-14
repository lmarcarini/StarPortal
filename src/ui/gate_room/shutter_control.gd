class_name ShutterControl
extends Button
## The Gate Room's Close Shutter / Open Shutter button (M4c-10): shown once the Shutter is
## installed; a refusal ("Close the wormhole first") shows as its tooltip and a disabled
## button. Submits SetShutterCommand, also while paused.
## Bible: docs/content/m4c-incursions.md section 6

var _simulation: Simulation = null


func _init() -> void:
	name = &"ShutterControl"
	visible = false
	pressed.connect(_on_pressed)


func _enter_tree() -> void:
	EventBus.shutter_changed.connect(_on_changed)
	EventBus.installation_changed.connect(_on_changed)
	EventBus.tick_advanced.connect(_on_changed)


func _exit_tree() -> void:
	EventBus.shutter_changed.disconnect(_on_changed)
	EventBus.installation_changed.disconnect(_on_changed)
	EventBus.tick_advanced.disconnect(_on_changed)


## Shows the Shutter of [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	refresh()


## Rereads the state.
func refresh() -> void:
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	visible = ShutterRules.is_installed(state)
	var closed: bool = ShutterRules.is_closed(state)
	text = tr(&"GATE_SHUTTER_OPEN" if closed else &"GATE_SHUTTER_CLOSE")
	var check: CommandResult = SetShutterCommand.create(not closed).validate(state)
	disabled = not check.is_ok
	tooltip_text = (
		"" if check.is_ok else tr(StringName("GATE_ERR_" + String(check.error_code).to_upper()))
	)


func _on_pressed() -> void:
	if _simulation == null:
		return
	_simulation.submit(SetShutterCommand.create(not ShutterRules.is_closed(_simulation.state)))
	refresh()


func _on_changed(_value: Variant = null) -> void:
	refresh()
