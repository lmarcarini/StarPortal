class_name ResearchQueueBox
extends VBoxContainer
## The research queue under the SELECTED panel: "Queue (2/5)", why the first one waits, each
## queued project with Up, Down and Remove, and "Add to queue" for the selected project. Every
## change is a QueueResearchCommand or UnqueueResearchCommand.
## Bible: docs/content/m4-core-systems.md section 7 (4)

var _simulation: Simulation = null
var _selected: StringName = &""
var _title := Label.new()
var _wait := Label.new()
var _rows := VBoxContainer.new()
var _add := Button.new()


func _init() -> void:
	for label: Label in [_title, _wait]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		add_child(label)
	add_child(_rows)
	_add.text = &"RESEARCH_QUEUE_ADD"
	_add.pressed.connect(func() -> void: _submit(QueueResearchCommand.new(_selected)))
	add_child(_add)


## Connects the box to [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	refresh()


## Offers "Add to queue" for [param project_id] when it can be queued.
func select(project_id: StringName) -> void:
	_selected = project_id
	refresh()


## Rebuilds from the state.
func refresh() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	var queue: Array[StringName] = state.research.queue
	var most: int = 5 if state.balance == null else state.balance.research_queue_max
	_title.text = tr(&"RESEARCH_QUEUE_TITLE").format({"count": queue.size(), "max": most})
	var wait: StringName = ResearchRules.queue_wait(state)
	_wait.text = (
		"" if wait.is_empty() else tr(StringName("RESEARCH_QUEUE_" + String(wait).to_upper()))
	)
	for index: int in queue.size():
		_rows.add_child(_row(state, queue[index], index))
	_add.visible = (
		not _selected.is_empty() and ResearchRules.queue_error(state, _selected).is_empty()
	)


## Returns the queued project names shown, in order.
func get_names() -> Array[String]:
	var found: Array[String] = []
	for row: Node in _rows.get_children():
		found.append((row.get_child(0) as Label).text)
	return found


## Returns the wait line ("" when nothing waits).
func get_wait_text() -> String:
	return _wait.text


## Returns the Add to queue button.
func get_add_button() -> Button:
	return _add


## Returns row [param index]'s [Up, Down, Remove] buttons.
func get_row_buttons(index: int) -> Array[Button]:
	var found: Array[Button] = []
	for child: Node in _rows.get_child(index).get_children():
		if child is Button:
			found.append(child as Button)
	return found


func _row(state: GameState, project_id: StringName, index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name := Label.new()
	name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name.text = "%d. %s" % [index + 1, ResearchText.name_of(state, project_id)]
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var moves: Array = [
		[&"RESEARCH_QUEUE_UP", QueueResearchCommand.new(project_id, maxi(index - 1, 0))],
		[&"RESEARCH_QUEUE_DOWN", QueueResearchCommand.new(project_id, index + 1)],
		[&"RESEARCH_QUEUE_REMOVE", UnqueueResearchCommand.new(project_id)],
	]
	for move: Array in moves:
		var button := Button.new()
		var key: StringName = move[0]
		button.text = key
		var command: Command = move[1]
		button.pressed.connect(_submit.bind(command))
		row.add_child(button)
	return row


func _submit(command: Command) -> void:
	if _simulation != null:
		_simulation.submit(command)
		refresh()
