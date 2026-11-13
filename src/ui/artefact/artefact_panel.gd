class_name ArtefactPanel
extends VBoxContainer
## Every artefact the player holds: name, state, where it is, what it does while housed and
## its hazard; with the moves that apply (House in a fitting room with a free slot, Remove to
## holding, Retrieve from the gate). Every move is a command; a refusal shows its reason.
## Shown in the Archive's Artefacts section and from the Gate Room. Placeholder look.
## Bible: docs/content/m4-core-systems.md section 5

## When at least 0: show only artefacts in that room and in holding, with moves for that room
## only (the Base room panel). −1 shows everything.
var room_filter: int = -1
var _simulation: Simulation = null
var _header := Label.new()
var _message := Label.new()
var _list := VBoxContainer.new()


func _init() -> void:
	for label: Label in [_header, _message]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		add_child(label)
	_message.modulate = Color(1.0, 0.75, 0.4)
	_list.add_theme_constant_override(&"separation", 10)
	add_child(_list)


func _enter_tree() -> void:
	for bus_signal: Signal in _signals():
		bus_signal.connect(_on_changed)


func _exit_tree() -> void:
	for bus_signal: Signal in _signals():
		bus_signal.disconnect(_on_changed)


## Connects the panel to [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_message.text = ""
	refresh()


## Rebuilds the header and the rows from the state.
func refresh() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	_header.text = ArtefactText.header(state)
	for record: ArtefactRecord in state.artefacts.items:
		if room_filter >= 0 and record.room_uid != room_filter:
			if record.room_uid != ArtefactRecord.IN_HOLDING:
				continue
			if not ArtefactRules.house_error(state, record.uid, room_filter).is_empty():
				continue
		_list.add_child(_row(state, record))


## Returns the action buttons, in order.
func get_buttons() -> Array[Button]:
	var found: Array[Button] = []
	for row: Node in _list.get_children():
		for child: Node in row.get_child(1).get_children():
			found.append(child as Button)
	return found


## Returns the text of row [param index].
func get_row_text(index: int) -> String:
	return (_list.get_child(index).get_child(0) as Label).text


## Returns the header text.
func get_header_text() -> String:
	return _header.text


## Returns the last refusal shown ("" when none).
func get_message() -> String:
	return _message.text


func _row(state: GameState, record: ArtefactRecord) -> VBoxContainer:
	var row := VBoxContainer.new()
	var info := Label.new()
	info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = ArtefactText.describe(state, record)
	row.add_child(info)
	var buttons := HFlowContainer.new()
	row.add_child(buttons)
	if record.room_uid == ArtefactRecord.AT_GATE:
		_add(buttons, tr(&"ARTEFACT_RETRIEVE"), RetrieveArtefactCommand.new(record.uid))
	elif record.room_uid == ArtefactRecord.IN_HOLDING:
		for room: RoomState in state.base.rooms:
			var room_uid: int = ArtefactRules.room_uid_of(room.id)
			if room_filter >= 0 and room_uid != room_filter:
				continue
			if ArtefactRules.house_error(state, record.uid, room_uid).is_empty():
				var text: String = tr(&"ARTEFACT_HOUSE").format(
					{"room": ArtefactText.room_name(state, room_uid)}
				)
				_add(buttons, text, HouseArtefactCommand.new(record.uid, room_uid))
	else:
		_add(buttons, tr(&"ARTEFACT_REMOVE"), UnhouseArtefactCommand.new(record.uid))
	return row


func _add(buttons: HFlowContainer, text: String, command: Command) -> void:
	var button := Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.text = text
	button.pressed.connect(_submit.bind(command))
	buttons.add_child(button)


func _submit(command: Command) -> void:
	if _simulation == null:
		return
	var result: CommandResult = _simulation.submit(command)
	_message.text = "" if result.is_ok else ArtefactText.refusal(result.error_code)
	refresh()


func _on_changed(_arg: Variant = null) -> void:
	if is_visible_in_tree():
		refresh()


static func _signals() -> Array[Signal]:
	return [
		EventBus.artefact_arrived,
		EventBus.artefact_moved,
		EventBus.artefact_taken,
		EventBus.artefact_studied,
		EventBus.tick_advanced,
	]
