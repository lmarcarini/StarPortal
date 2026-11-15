class_name CheatPanel
extends PanelContainer
## The cheat panel for testing (M4.6-04): a column of plain buttons and two small inputs (id
## and value) that submit DebugCheatCommands. F10 (debug_toggle_cheats) shows and hides it; it
## works while paused and, hidden, never takes focus. Stock, unthemed controls in English only:
## its strings are set in code with auto-translation off, like the debug overlay's, so the
## translation scan of scene files never sees them. The shell creates it only when cheats are on.
## Bible: docs/bible/technical-architecture.md#testing-and-tooling

const _ACTION_TOGGLE: StringName = &"debug_toggle_cheats"
const _BUTTONS: Array[Array] = [
	["+$1,000k funds", &"funds", 1000],
	["Set Confidence (value)", &"confidence", -1],
	["Fill capacitors", &"charge", 0],
	["Finish research", &"finish_research", 0],
	["Finish sites and digs", &"finish_sites", 0],
	["Add staff (id = role, value = skill)", &"add_staff", -1],
	["Set standing (id = faction, value)", &"standing", -1],
	["Grant artefact (id)", &"grant_artefact", 0],
	["Unlock all research", &"unlock_all_research", 0],
	["Heal all", &"heal_all", 0],
	["Incursion (id, e.g. incursion_test_sabotage)", &"incursion", 0],
	["Skip the warning", &"skip_warning", 0],
	["Down all intruders", &"clear_intruders", 0],
]

## The id input (role, faction or artefact) and the value input.
var id_field := LineEdit.new()
var value_field := SpinBox.new()
## The last result.
var result_label := Label.new()

var _column := VBoxContainer.new()


func _init() -> void:
	name = &"CheatPanel"
	theme = Theme.new()
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_column)
	var title := Label.new()
	title.text = "CHEATS (F10)"
	_column.add_child(title)
	id_field.placeholder_text = "id"
	_column.add_child(id_field)
	value_field.min_value = -100000
	value_field.max_value = 100000
	value_field.value = 1
	_column.add_child(value_field)
	for entry: Array in _BUTTONS:
		var button := Button.new()
		button.text = str(entry[0])
		var action: StringName = entry[1]
		var fixed: int = entry[2]
		button.pressed.connect(cheat.bind(action, fixed))
		_column.add_child(button)
	_column.add_child(result_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(_ACTION_TOGGLE):
		visible = not visible
		get_viewport().set_input_as_handled()


## Submits [param action]; [param fixed] is its value, or -1 to read the value field.
## Returns the result.
func cheat(action: StringName, fixed: int = 0) -> CommandResult:
	var simulation: Simulation = SimClock.simulation
	if simulation == null:
		return CommandResult.fail(&"no_game")
	var amount: int = int(value_field.value) if fixed < 0 else fixed
	var result: CommandResult = simulation.submit(
		DebugCheatCommand.create(action, StringName(id_field.text.strip_edges()), amount)
	)
	result_label.text = "%s: %s" % [action, "ok" if result.is_ok else String(result.error_code)]
	return result
