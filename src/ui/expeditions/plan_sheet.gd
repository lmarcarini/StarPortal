class_name ExpeditionPlanSheet
extends VBoxContainer
## The plan sheet of the Expeditions tab (docs/content/m3-beyond-the-ring.md section 7): the
## world (those Probed), its threat as the report knows it, the objective (Survey, or Recover a
## recoverable target), the four team slots (each a roster filtered by the slot's role, with
## skill and what the base loses), the risk and days, and **Ready team**, greyed with the
## reason when the plan would be refused. Rows are 32 px. The sheet keeps the player's choices
## in an [ExpeditionPlanDraft]; it takes the game's plan when that plan changes, and while a
## team is out it shows that team with every control disabled. Reads state only: Ready team
## emits [signal ready_pressed] and the view submits the command.
## Bible: docs/content/m3-beyond-the-ring.md section 7 (Expeditions tab)

## Emitted when **Ready team** is pressed on a plan that can be readied.
signal ready_pressed

## Height of every row.
const ROW_HEIGHT: int = 32

var _draft := ExpeditionPlanDraft.new()
var _state: GameState = null
## The game's plan the draft last took, to take it again only when it changes.
var _plan_key: String = ""
var _title := Label.new()
var _world := OptionButton.new()
var _threat := Label.new()
var _objectives := VBoxContainer.new()
var _objective_group := ButtonGroup.new()
var _slots: Dictionary[String, OptionButton] = {}
var _risk := Label.new()
var _reason := Label.new()
var _ready := Button.new()


func _init() -> void:
	add_theme_constant_override(&"separation", 2)
	_title.text = &"EXPEDITION_PLAN_TITLE"
	add_child(_title)
	_add_row(&"EXPEDITION_WORLD", _world)
	_world.item_selected.connect(_on_world_selected)
	_add_row(&"EXPEDITION_THREAT", _threat)
	_add_heading(&"EXPEDITION_OBJECTIVE")
	add_child(_objectives)
	_add_heading(&"EXPEDITION_TEAM")
	for slot: String in ExpeditionState.SLOTS:
		var picker := OptionButton.new()
		picker.fit_to_longest_item = false
		picker.clip_text = true
		picker.item_selected.connect(_on_member_selected.bind(slot))
		_slots[slot] = picker
		_add_row(ExpeditionText.SLOT_KEYS[slot], picker)
	_risk.custom_minimum_size.y = ROW_HEIGHT
	add_child(_risk)
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason.custom_minimum_size.x = 300
	add_child(_reason)
	_ready.text = &"EXPEDITION_READY"
	_ready.custom_minimum_size.y = ROW_HEIGHT
	_ready.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_ready.pressed.connect(press_ready)
	add_child(_ready)
	for label: Label in [_threat, _risk, _reason]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


## Rereads [param state]: the choices, the threat, the risk and the reason.
func show_state(state: GameState) -> void:
	_state = state
	var key: String = _key_of(state.expedition)
	if key != _plan_key:
		_plan_key = key
		_draft.take_plan(state)
	if not state.expedition.is_out():
		_draft.sync(state)
	_fill_worlds()
	_fill_objectives()
	_fill_slots()
	_show_verdict()


## Chooses [param world_id] when it can be planned (Plan expedition in the World Report).
func choose_world(world_id: StringName) -> void:
	if _state == null or _state.expedition.is_out():
		return
	if not world_id in ExpeditionPlanDraft.worlds(_state):
		return
	_draft.choose_world(world_id)
	show_state(_state)


## Presses **Ready team** (A on it, a click, or Y anywhere in the tab): emits
## [signal ready_pressed] unless it is disabled.
func press_ready() -> void:
	if not _ready.disabled:
		ready_pressed.emit()


## Shows [param text] (a refusal) on the reason line until the next refresh.
func show_refusal(text: String) -> void:
	_reason.text = text


## Returns the plan being put together.
func get_draft() -> ExpeditionPlanDraft:
	return _draft


## Returns the world picker.
func get_world_picker() -> OptionButton:
	return _world


## Returns the objective buttons, Survey first.
func get_objective_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in _objectives.get_children():
		buttons.append(child as Button)
	return buttons


## Returns the picker of [param slot].
func get_slot_picker(slot: String) -> OptionButton:
	return _slots[slot]


## Returns the Ready team button.
func get_ready_button() -> Button:
	return _ready


## Returns the risk line and the reason line.
func texts() -> Array[String]:
	return [_threat.text, _risk.text, _reason.text]


## Returns the first control the D-pad reaches.
func get_first_focus() -> Control:
	return _world


func _add_row(key: StringName, control: Control) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = ROW_HEIGHT
	var label := Label.new()
	label.text = key
	label.custom_minimum_size.x = 104
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	add_child(row)


func _add_heading(key: StringName) -> void:
	var label := Label.new()
	label.text = key
	label.custom_minimum_size.y = ROW_HEIGHT
	add_child(label)


func _fill_worlds() -> void:
	var ids: Array[StringName] = ExpeditionPlanDraft.worlds(_state)
	if _draft.world_id != &"" and not _draft.world_id in ids:
		ids.append(_draft.world_id)
	var names: Array[String] = []
	for world_id: StringName in ids:
		names.append(AddressBookText.name_of_world(world_id, _state))
	_fill_picker(_world, names, ids, ids.find(_draft.world_id))
	_world.disabled = _state.expedition.is_out() or ids.is_empty()
	_threat.text = ExpeditionText.threat(_state, _draft.world_id)


func _fill_objectives() -> void:
	var choices: Array[Array] = [[ExpeditionState.Objective.SURVEY, &""]]
	for target: WorldTarget in ExpeditionPlanDraft.targets(_state, _draft.world_id):
		choices.append([ExpeditionState.Objective.RECOVER, target.id, target.name_key])
	if _draft.objective == ExpeditionState.Objective.RECOVER and choices.size() == 1:
		choices.append([ExpeditionState.Objective.RECOVER, _draft.target_id, _draft.target_id])
	var buttons: Array[Button] = get_objective_buttons()
	if buttons.size() != choices.size():
		for child: Node in _objectives.get_children():
			child.free()
		for choice: Array in choices:
			var button := CheckBox.new()
			button.button_group = _objective_group
			button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			button.custom_minimum_size.y = ROW_HEIGHT
			_objectives.add_child(button)
		buttons = get_objective_buttons()
	for index: int in choices.size():
		_show_objective(buttons[index], choices[index])


func _show_objective(button: Button, choice: Array) -> void:
	var objective: ExpeditionState.Objective = choice[0]
	var target: StringName = choice[1]
	button.text = ExpeditionText.objective_name(objective)
	if objective == ExpeditionState.Objective.RECOVER:
		var name_key: StringName = choice[2]
		button.text = tr(&"EXPEDITION_RECOVER_TARGET").format({"target": tr(name_key)})
	button.set_pressed_no_signal(_draft.objective == objective and _draft.target_id == target)
	button.disabled = _state.expedition.is_out()
	for connection: Dictionary in button.pressed.get_connections():
		var callable: Callable = connection["callable"]
		button.pressed.disconnect(callable)
	button.pressed.connect(_on_objective_pressed.bind(objective, target))


func _fill_slots() -> void:
	for slot: String in ExpeditionState.SLOTS:
		var people: Array[PersonState] = ExpeditionPlanDraft.candidates(_state, slot)
		var names: Array[String] = [tr(&"EXPEDITION_SLOT_EMPTY")]
		var ids: Array[StringName] = [&""]
		for person: PersonState in people:
			names.append(ExpeditionText.member_option(_state, person))
			ids.append(person.id)
		var chosen: StringName = _draft.team.get(slot, &"")
		if not chosen in ids:
			chosen = &""
			_draft.team.erase(slot)
		_fill_picker(_slots[slot], names, ids, ids.find(chosen))
		_slots[slot].disabled = _state.expedition.is_out()


## Fills [param picker] with [param names] (ids kept as item metadata) unless it already shows
## them, and selects [param index].
func _fill_picker(
	picker: OptionButton, names: Array[String], ids: Array[StringName], index: int
) -> void:
	var same: bool = picker.item_count == names.size()
	for item: int in mini(picker.item_count, names.size()):
		same = same and picker.get_item_text(item) == names[item]
		same = same and picker.get_item_metadata(item) == ids[item]
	if not same:
		picker.clear()
		for item: int in names.size():
			picker.add_item(names[item])
			picker.set_item_metadata(item, ids[item])
	picker.select(index)


func _show_verdict() -> void:
	var expedition: ExpeditionState = _state.expedition
	_risk.text = ExpeditionText.risk(_state, _draft.world_id, _draft.objective)
	var error: StringName = _draft.error(_state)
	if expedition.is_out():
		_reason.text = tr(&"EXPEDITION_TEAM_OUT")
	elif not error.is_empty():
		_reason.text = ExpeditionText.refusal(error)
	elif _draft.is_ready_in(_state):
		_reason.text = tr(&"EXPEDITION_PLAN_READY")
	else:
		_reason.text = ""
	_ready.disabled = not error.is_empty() or _draft.is_ready_in(_state)
	_ready.tooltip_text = _reason.text


func _key_of(expedition: ExpeditionState) -> String:
	var data: Dictionary = expedition.to_dict()
	return (
		"%s|%s|%s|%s|%s"
		% [data["mode"], data["objective"], data["world_id"], data["target_id"], str(data["team"])]
	)


func _on_world_selected(index: int) -> void:
	_draft.choose_world(StringName(str(_world.get_item_metadata(index))))
	show_state(_state)


func _on_objective_pressed(objective: ExpeditionState.Objective, target: StringName) -> void:
	_draft.choose_objective(objective, target)
	show_state(_state)


func _on_member_selected(index: int, slot: String) -> void:
	_draft.choose_member(slot, StringName(str(_slots[slot].get_item_metadata(index))))
	show_state(_state)
