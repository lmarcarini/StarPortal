class_name MothOrderControl
extends Button
## The Gate Room's Order a MOTH button (M4c-20): shown once the rack is installed, with the
## MOTHs owned; greyed with the reason when the rack is full or money is short.
## Bible: docs/content/m4c-incursions.md section 6

var _simulation: Simulation = null


func _init() -> void:
	name = &"MothOrderControl"
	visible = false
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	pressed.connect(_on_pressed)


func _enter_tree() -> void:
	EventBus.installation_changed.connect(_on_changed)
	EventBus.tick_advanced.connect(_on_changed)
	EventBus.budget_changed.connect(_on_changed)


func _exit_tree() -> void:
	EventBus.installation_changed.disconnect(_on_changed)
	EventBus.tick_advanced.disconnect(_on_changed)
	EventBus.budget_changed.disconnect(_on_changed)


## Shows the rack of [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	refresh()


## Rereads the state.
func refresh() -> void:
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	visible = MothRules.has_rack(state)
	text = tr(&"GATE_MOTH_ORDER").format({"count": MothRules.owned(state)})
	var check: CommandResult = OrderMothCommand.new().validate(state)
	disabled = not check.is_ok
	update_minimum_size()
	var box: Control = get_parent() as Control
	if box != null:
		box.reset_size()
	tooltip_text = (
		"" if check.is_ok else tr(StringName("GATE_ERR_" + String(check.error_code).to_upper()))
	)


func _on_pressed() -> void:
	if _simulation != null:
		_simulation.submit(OrderMothCommand.new())
	refresh()


func _on_changed(_value: Variant = null) -> void:
	refresh()
