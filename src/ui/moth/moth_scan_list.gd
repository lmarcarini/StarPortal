class_name MothScanList
extends VBoxContainer
## The SCANS column of the MOTH scan screen: one button per scan (Look around, a Close look per
## target the World Report lists, Sky, Ring), each with its battery minutes and "done" or
## "scanning" under it. A button is enabled exactly when its MothScanCommand would be accepted
## now. D-pad moves between them; A (or a click) asks to run one. Reads the state only.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (MOTH scans) and section 7

## The player asked to run [param scan] (a MothRules.Scan) on [param target_id].
signal scan_requested(scan: int, target_id: StringName)

const _WIDTH: float = 250.0

var _keys: Array[String] = []
var _buttons: Array[Button] = []
var _lines: Array[Label] = []
var _commands: Array[MothScanCommand] = []


func _init() -> void:
	custom_minimum_size = Vector2(_WIDTH, 0.0)
	add_theme_constant_override(&"separation", 2)


## Shows the scans of the MOTH in [param state], or nothing when none is out.
func render(state: GameState) -> void:
	var run: MothRun = state.probes.moth
	var commands: Array[MothScanCommand] = _commands_for(state, run)
	var keys: Array[String] = []
	for command: MothScanCommand in commands:
		keys.append(MothRun.scan_key(command.scan, command.target_id))
	if keys != _keys:
		_rebuild(keys, commands)
	for index: int in _commands.size():
		var command: MothScanCommand = _commands[index]
		var is_ok: bool = run != null and command.validate(state).is_ok
		_buttons[index].text = _button_text(state, command)
		_buttons[index].disabled = not is_ok
		_buttons[index].focus_mode = Control.FOCUS_ALL if is_ok else Control.FOCUS_NONE
		_lines[index].text = MothText.scan_line(run, command.scan, command.target_id)


## Returns the scan buttons, in order.
func get_buttons() -> Array[Button]:
	return _buttons


## Returns the first enabled scan button, or null.
func get_default_focus() -> Button:
	for button: Button in _buttons:
		if not button.disabled:
			return button
	return null


## Returns the button of [param scan] on [param target_id], or null.
func get_button(scan: MothRules.Scan, target_id: StringName = &"") -> Button:
	var index: int = _keys.find(MothRun.scan_key(scan, target_id))
	return _buttons[index] if index >= 0 else null


static func _commands_for(state: GameState, run: MothRun) -> Array[MothScanCommand]:
	var commands: Array[MothScanCommand] = []
	if run == null:
		return commands
	commands.append(MothScanCommand.create(MothRules.Scan.LOOK_AROUND))
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, run.world_id)
	if facts != null:
		var report: WorldReport = state.worlds.report_of(run.world_id)
		for target: WorldTarget in WorldReportRules.shown_targets(facts, report):
			commands.append(MothScanCommand.create(MothRules.Scan.CLOSE_LOOK, target.id))
	commands.append(MothScanCommand.create(MothRules.Scan.SKY))
	commands.append(MothScanCommand.create(MothRules.Scan.RING))
	return commands


func _rebuild(keys: Array[String], commands: Array[MothScanCommand]) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_keys = keys
	_commands = commands
	_buttons.clear()
	_lines.clear()
	var title := Label.new()
	title.text = &"MOTH_SCANS"
	add_child(title)
	for command: MothScanCommand in commands:
		var button := Button.new()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(scan_requested.emit.bind(command.scan as int, command.target_id))
		add_child(button)
		var line := Label.new()
		line.add_theme_font_size_override(&"font_size", 13)
		add_child(line)
		_buttons.append(button)
		_lines.append(line)


static func _button_text(state: GameState, command: MothScanCommand) -> String:
	var name: String = GateRoomFormat.translate(MothText.SCAN_KEYS[command.scan])
	if command.scan != MothRules.Scan.CLOSE_LOOK:
		return name
	return GateRoomFormat.translate(&"MOTH_SCAN_CLOSE_LOOK_AT").format(
		{"target": target_name(state, command.target_id)}
	)


## The translated name of [param target_id] on the MOTH's world in [param state].
static func target_name(state: GameState, target_id: StringName) -> String:
	var run: MothRun = state.probes.moth
	if run == null:
		return ""
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, run.world_id)
	var target: WorldTarget = facts.find_target(target_id) if facts != null else null
	return GateRoomFormat.translate(target.name_key) if target != null else String(target_id)
