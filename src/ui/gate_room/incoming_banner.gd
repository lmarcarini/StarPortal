class_name IncomingBanner
extends PanelContainer
## The "Incoming wormhole" banner over the Gate Room: the faction calling, the minutes left to
## answer, and Answer / Ignore (mouse, keyboard and gamepad; Answer takes focus when it shows).
## Hidden when no incoming wormhole waits.
## Bible: docs/content/m4-core-systems.md section 3 (Incoming wormhole)

var _simulation: Simulation = null
var _title := Label.new()
var _time := Label.new()
var _answer := Button.new()
var _ignore := Button.new()


func _init() -> void:
	visible = false
	var layout := VBoxContainer.new()
	add_child(layout)
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title.add_theme_font_size_override(&"font_size", 18)
	layout.add_child(_title)
	_time.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	layout.add_child(_time)
	var buttons := HBoxContainer.new()
	_answer.text = &"GATE_INCOMING_ANSWER"
	_ignore.text = &"GATE_INCOMING_IGNORE"
	_answer.pressed.connect(func() -> void: _submit(AnswerIncomingCommand.new()))
	_ignore.pressed.connect(func() -> void: _submit(IgnoreIncomingCommand.new()))
	buttons.add_child(_answer)
	buttons.add_child(_ignore)
	layout.add_child(buttons)


func _enter_tree() -> void:
	EventBus.tick_advanced.connect(_on_changed)
	EventBus.incoming_wormhole.connect(_on_changed)
	EventBus.incoming_answered.connect(_on_changed)
	EventBus.incoming_ignored.connect(_on_changed)


func _exit_tree() -> void:
	EventBus.tick_advanced.disconnect(_on_changed)
	EventBus.incoming_wormhole.disconnect(_on_changed)
	EventBus.incoming_answered.disconnect(_on_changed)
	EventBus.incoming_ignored.disconnect(_on_changed)


## Connects the banner to [param simulation] and shows its state.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	render(simulation.state)


## Shows or hides the banner for [param state].
func render(state: GameState) -> void:
	var was_visible: bool = visible
	visible = state.gate.has_incoming()
	if not visible:
		return
	var faction: FactionDef = state.faction_defs.get(state.gate.incoming_faction)
	var name: String = String(state.gate.incoming_faction)
	if faction != null:
		name = tr(faction.name_key)
	_title.text = tr(&"GATE_INCOMING_TITLE").format({"name": name})
	var minutes: int = maxi(state.gate.incoming_until_tick - state.clock.tick, 0)
	_time.text = tr(&"GATE_INCOMING_TIME").format({"minutes": minutes})
	if not was_visible and is_inside_tree():
		_answer.grab_focus.call_deferred()


## Returns the Answer button.
func get_answer_button() -> Button:
	return _answer


## Returns the Ignore button.
func get_ignore_button() -> Button:
	return _ignore


## Returns the title line.
func get_title_text() -> String:
	return _title.text


func _submit(command: Command) -> void:
	if _simulation == null:
		return
	_simulation.submit(command)
	render(_simulation.state)


func _on_changed(_arg: Variant = null) -> void:
	if _simulation != null:
		render(_simulation.state)
