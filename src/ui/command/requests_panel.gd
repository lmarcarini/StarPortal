class_name RequestsPanel
extends HBoxContainer
## The Command tab's Requests sub-tab: on the left the requests grouped Offered, Active and
## Closed (the last 20), on the right the chosen one's faction, text, status, objective,
## previews and, for an offer, Accept and Decline. Mouse, keyboard and gamepad (rows and
## buttons take focus). Reads state; only the two commands change it.
## Bible: docs/content/m4-core-systems.md section 4

## Closed requests listed.
const CLOSED_SHOWN: int = 20

var _simulation: Simulation = null
var _selected: int = -1
var _list := VBoxContainer.new()
var _detail := VBoxContainer.new()
var _detail_text := Label.new()
var _accept := Button.new()
var _decline := Button.new()
var _empty := Label.new()


func _init() -> void:
	add_theme_constant_override(&"separation", 24)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_empty)
	column.add_child(_list)
	scroll.add_child(column)
	add_child(scroll)
	_detail.custom_minimum_size = Vector2(420, 0)
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_detail.add_child(_detail_text)
	var buttons := HBoxContainer.new()
	_accept.text = &"REQUEST_ACCEPT"
	_decline.text = &"REQUEST_DECLINE"
	_accept.pressed.connect(func() -> void: _submit(AcceptRequestCommand.new(_selected)))
	_decline.pressed.connect(func() -> void: _submit(DeclineRequestCommand.new(_selected)))
	buttons.add_child(_accept)
	buttons.add_child(_decline)
	_detail.add_child(buttons)
	add_child(_detail)
	_empty.text = &"REQUESTS_EMPTY"


## Connects the panel to [param simulation] and shows its requests.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_selected = -1
	refresh()


## Rebuilds the list and the detail from the state.
func refresh() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	var groups: Dictionary[StringName, Array] = {
		&"REQUESTS_OFFERED": [], &"REQUESTS_ACTIVE": [], &"REQUESTS_CLOSED": []
	}
	for index: int in range(state.requests.items.size() - 1, -1, -1):
		var record: RequestRecord = state.requests.items[index]
		match record.state:
			RequestRecord.RequestState.OFFERED:
				groups[&"REQUESTS_OFFERED"].append(record)
			RequestRecord.RequestState.ACTIVE:
				groups[&"REQUESTS_ACTIVE"].append(record)
			_:
				if groups[&"REQUESTS_CLOSED"].size() < CLOSED_SHOWN:
					groups[&"REQUESTS_CLOSED"].append(record)
	for key: StringName in groups:
		if groups[key].is_empty():
			continue
		var heading := Label.new()
		heading.text = key
		_list.add_child(heading)
		for record: RequestRecord in groups[key]:
			_list.add_child(_row(state, record))
	_empty.visible = state.requests.items.is_empty()
	if _selected < 0 and not state.requests.items.is_empty():
		_selected = state.requests.items[-1].uid
	_show_detail()


## Shows the request [param uid] in the detail.
func select(uid: int) -> void:
	_selected = uid
	_show_detail()


## Returns the request rows, in list order.
func get_rows() -> Array[Button]:
	var found: Array[Button] = []
	for child: Node in _list.get_children():
		if child is Button:
			found.append(child as Button)
	return found


## Returns the detail text.
func get_detail_text() -> String:
	return _detail_text.text


## Returns the Accept button.
func get_accept_button() -> Button:
	return _accept


## Returns the Decline button.
func get_decline_button() -> Button:
	return _decline


## Returns the first control to focus: the first row, else Accept.
func get_first_focus() -> Control:
	var rows: Array[Button] = get_rows()
	return rows[0] if not rows.is_empty() else _accept


func _row(state: GameState, record: RequestRecord) -> Button:
	var def: RequestDef = state.request_defs.get(record.request)
	var row := Button.new()
	row.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.text = "%s  %s" % [RequestText.title(def, record), RequestText.status(state, def, record)]
	row.pressed.connect(select.bind(record.uid))
	return row


func _show_detail() -> void:
	var record: RequestRecord = null
	if _simulation != null:
		record = RequestRules.find(_simulation.state, _selected)
	var is_offer: bool = record != null and record.state == RequestRecord.RequestState.OFFERED
	_accept.visible = is_offer
	_decline.visible = is_offer
	if record == null:
		_detail_text.text = ""
		return
	var state: GameState = _simulation.state
	var def: RequestDef = state.request_defs.get(record.request)
	var lines: Array[String] = [RequestText.title(def, record)]
	if def != null:
		lines.append(StoryText.name_of(def.faction))
		if not def.text_key.is_empty():
			lines.append(tr(def.text_key))
	lines.append(RequestText.status(state, def, record))
	lines.append_array(RequestText.objective_lines(state, def))
	lines.append_array(RequestText.preview_lines(def))
	_detail_text.text = "\n".join(lines)


func _submit(command: Command) -> void:
	if _simulation != null:
		_simulation.submit(command)
		refresh()
