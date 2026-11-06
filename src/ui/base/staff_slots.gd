class_name StaffSlots
extends VBoxContainer
## The staff slots of a staffable room on the Base tab's SELECTED panel
## (docs/content/m26-staff-and-money.md section 6): "Staff 2/4", then one button per slot.
## A filled slot shows the person ("Dr Ana Ferreira  ×") and unassigns them; an empty slot's
## "+ Empty slot" opens the Unassigned people on base of the room's role, and picking one
## assigns them. Both go through the commands; a refusal shows under the slots. Hidden for a
## room with no slots, a site, or a room coming down. It rereads the room on every staff event,
## so it stays right while paused.
## Bible: docs/content/m26-staff-and-money.md section 6

var _simulation: Simulation = null
var _room_id: StringName = &""
var _picking: bool = false
var _heading: Label = _add_label(16)
var _list: VBoxContainer = VBoxContainer.new()
var _notice: Label = _add_label(14)


func _init() -> void:
	add_child(_list)
	move_child(_notice, -1)
	visible = false


func _enter_tree() -> void:
	EventBus.staff_changed.connect(_on_staff_changed)
	EventBus.staff_arrived.connect(_on_arrived)


func _exit_tree() -> void:
	EventBus.staff_changed.disconnect(_on_staff_changed)
	EventBus.staff_arrived.disconnect(_on_arrived)


## Reads [param simulation]'s staff from now on.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	show_room(&"")


## Shows the slots of [param room_id], or hides them when it has none.
func show_room(room_id: StringName) -> void:
	if room_id != _room_id:
		_picking = false
		_notice.text = ""
	_room_id = room_id
	_clear()
	var room: RoomState = _room()
	visible = room != null and StaffRules.slots(_simulation.state, room) > 0
	visible = visible and PowerRules.is_standing(room)
	if not visible:
		return
	var state: GameState = _simulation.state
	var people: Array[PersonState] = StaffRules.assigned(state, room)
	var slots: int = StaffRules.slots(state, room)
	_heading.text = tr(&"STAFF_SLOTS").format({"used": people.size(), "slots": slots})
	for person: PersonState in people:
		var person_id: StringName = person.id
		var text: String = tr(&"STAFF_SLOT_REMOVE").format({"name": person.name})
		_add_button(text, func() -> void: unassign(person_id))
	if slots > people.size():
		_add_empty(state, room)


## Returns the slot buttons, top to bottom: people, then the empty slot or its picks.
func buttons() -> Array[Button]:
	var found: Array[Button] = []
	for child: Node in _list.get_children():
		if child is Button:
			found.append(child as Button)
	return found


## Returns the heading and the notice under the slots.
func lines() -> Array[String]:
	return [_heading.text, _notice.text]


## Opens the people who can fill the room's empty slot.
func open_picks() -> void:
	_picking = true
	show_room(_room_id)
	var found: Array[Button] = buttons()
	if not found.is_empty():
		found[-1].grab_focus()


## Assigns [param person_id] to the room shown; a refusal shows under the slots.
func assign(person_id: StringName) -> void:
	_picking = false
	_submit(AssignStaffCommand.create(person_id, _room_id))


## Unassigns [param person_id]; a refusal shows under the slots.
func unassign(person_id: StringName) -> void:
	_submit(UnassignStaffCommand.create(person_id))


func _add_empty(state: GameState, room: RoomState) -> void:
	if not _picking:
		_add_button(tr(&"STAFF_SLOT_EMPTY"), open_picks)
		return
	var people: Array[PersonState] = StaffPicks.people_for(state, room)
	if people.is_empty():
		var role: String = PersonnelText.role_name(StaffRules.slot_role(state, room))
		_notice.text = tr(&"STAFF_SLOT_NOBODY").format({"role": role.to_lower()})
		_picking = false
		_add_button(tr(&"STAFF_SLOT_EMPTY"), open_picks)
		return
	for person: PersonState in people:
		var person_id: StringName = person.id
		var text: String = "%s  %s" % [person.name, PersonnelText.stars(person.skill)]
		_add_button(text, func() -> void: assign(person_id))


func _submit(command: Command) -> void:
	if _simulation == null:
		return
	var result: CommandResult = _simulation.submit(command)
	show_room(_room_id)
	_notice.text = "" if result.is_ok else PersonnelText.refusal(result.error_code)
	var found: Array[Button] = buttons()
	if not found.is_empty():
		found[-1].grab_focus()


func _room() -> RoomState:
	if _simulation == null:
		return null
	return _simulation.state.base.find_room(_room_id)


func _clear() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()


func _on_staff_changed(_reason: StringName, _room_def_id: StringName, _count: int) -> void:
	if _simulation != null:
		show_room(_room_id)


func _on_arrived(_person_id: StringName) -> void:
	if _simulation != null:
		show_room(_room_id)


func _add_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = FOCUS_ALL
	button.text = text
	button.pressed.connect(action)
	_list.add_child(button)


func _add_label(font_size: int) -> Label:
	var label := Label.new()
	label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", font_size)
	add_child(label)
	return label
