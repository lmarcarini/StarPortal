class_name PersonnelPanel
extends VBoxContainer
## The SELECTED panel of the Personnel tab (docs/content/m26-staff-and-money.md section 6).
## For a person: name, role, skill and salary, room or arrival, then Assign…, Unassign and
## Dismiss (hold, because it is destructive). For a candidate: name, role, skill and salary,
## pipeline, fee and arrival time, then Hire. Assign… swaps the buttons for the rooms with a
## free slot of the person's role, each with its effect, and Back. A button greyed by a
## refusal shows why under it. The panel only emits; the view submits the commands.
## Bible: docs/content/m26-staff-and-money.md section 6

## Emitted when a room is picked on the Assign… list.
signal assign_pressed(person_id: StringName, room_id: StringName)
## Emitted when Unassign is pressed.
signal unassign_pressed(person_id: StringName)
## Emitted when the Dismiss hold confirms.
signal dismiss_held(person_id: StringName)
## Emitted when Hire is pressed.
signal hire_pressed(candidate_id: StringName)

var _heading: Label = _add_label(16)
var _name: Label = _add_label(22)
var _role: Label = _add_label(16)
var _skill: Label = _add_label(16)
var _where: Label = _add_label(16)
var _assign: Button = _add_button(Button.new(), _open_rooms)
var _unassign: Button = _add_button(Button.new(), _on_unassign)
var _dismiss: HoldButton = _add_button(HoldButton.new(), Callable()) as HoldButton
var _hire: Button = _add_button(Button.new(), _on_hire)
var _rooms: VBoxContainer = VBoxContainer.new()
var _notice: Label = _add_label(14)
var _id: StringName = &""
var _state: GameState = null


func _init() -> void:
	_dismiss.confirmed.connect(func() -> void: dismiss_held.emit(_id))
	add_child(_rooms)
	move_child(_notice, -1)


## Shows the person or candidate [param id] as it stands in [param state]; an unknown id
## shows only the heading. Closes the Assign… list.
func show_id(state: GameState, id: StringName) -> void:
	_state = state
	_id = id
	_heading.text = tr(&"STAFF_SELECTED")
	_close_rooms()
	for label: Label in [_name, _role, _skill, _where]:
		label.text = ""
	for button: Button in buttons():
		button.visible = false
	var person: PersonState = state.staff.find_person(id)
	var candidate: CandidateState = state.recruitment.find_candidate(id)
	if person != null:
		_show_person(person)
	elif candidate != null:
		_show_candidate(candidate)
	else:
		_id = &""


## Shows [param text] under the buttons (a refusal or a result).
func show_notice(text: String) -> void:
	_notice.text = text


## Returns the panel's lines, top to bottom: heading, name, role, skill, where, notice.
func lines() -> Array[String]:
	return [_heading.text, _name.text, _role.text, _skill.text, _where.text, _notice.text]


## Returns the buttons: Assign…, Unassign, Dismiss, Hire.
func buttons() -> Array[Button]:
	return [_assign, _unassign, _dismiss, _hire]


## Returns the buttons of the open Assign… list (rooms, then Back), or none.
func room_buttons() -> Array[Button]:
	var found: Array[Button] = []
	for child: Node in _rooms.get_children():
		if child is Button and not child.is_queued_for_deletion():
			found.append(child as Button)
	return found


## Returns the Hire button.
func get_hire_button() -> Button:
	return _hire


## Returns the Dismiss hold button.
func get_dismiss_button() -> HoldButton:
	return _dismiss


## Returns the id shown, or &"".
func get_id() -> StringName:
	return _id


## True while the Assign… list is open.
func is_picking() -> bool:
	return _rooms.visible


## Opens the Assign… list for the person shown and focuses its first entry.
func open_rooms() -> void:
	_open_rooms()


func _show_person(person: PersonState) -> void:
	_fill(person.name, person.role, person.skill, person.salary_k)
	_where.text = PersonnelText.where(_state, person)
	_assign.text = tr(&"STAFF_ASSIGN")
	_unassign.text = tr(&"STAFF_UNASSIGN")
	_dismiss.text = tr(&"STAFF_DISMISS")
	var on_base: bool = person.is_on_base(_state.clock.tick)
	_assign.visible = true
	_assign.disabled = not on_base or StaffPicks.rooms_for(_state, person).is_empty()
	_unassign.visible = person.is_assigned()
	_dismiss.visible = true
	if not on_base:
		_notice.text = tr(&"STAFF_ERR_NOT_ON_BASE")
	elif _assign.disabled:
		_notice.text = tr(&"STAFF_NO_ROOM")


func _show_candidate(candidate: CandidateState) -> void:
	_fill(candidate.name, candidate.role, candidate.skill, candidate.salary_k)
	_where.text = PersonnelText.offer(candidate)
	_hire.text = tr(&"STAFF_HIRE").format(
		{"fee": MoneyLabel.format_k(RecruitmentRules.fee_k(candidate))}
	)
	_hire.visible = true
	var error: StringName = RecruitmentRules.hire_error(_state, candidate.id)
	_hire.disabled = not error.is_empty()
	if not error.is_empty():
		_notice.text = PersonnelText.refusal(error)


func _fill(name: String, role: StringName, skill: int, salary_k: int) -> void:
	_notice.text = ""
	_name.text = name
	_role.text = PersonnelText.role_name(role)
	_skill.text = (
		"%s  %s  %s"
		% [PersonnelText.stars(skill), PersonnelText.skill(skill), PersonnelText.salary(salary_k)]
	)


func _open_rooms() -> void:
	var person: PersonState = null if _state == null else _state.staff.find_person(_id)
	if person == null:
		return
	_close_rooms()
	for room: RoomState in StaffPicks.rooms_for(_state, person):
		var room_id: StringName = room.id
		var text: String = PersonnelText.room_option(_state, room, person)
		_rooms.add_child(_make_button(text, func() -> void: assign_pressed.emit(_id, room_id)))
	_rooms.add_child(_make_button(tr(&"STAFF_BACK"), _back))
	for button: Button in buttons():
		button.visible = false
	_rooms.visible = true
	room_buttons()[0].grab_focus()


func _back() -> void:
	if _state != null:
		show_id(_state, _id)
	_assign.grab_focus()


func _close_rooms() -> void:
	for child: Node in _rooms.get_children():
		_rooms.remove_child(child)
		child.queue_free()
	_rooms.visible = false


func _on_unassign() -> void:
	unassign_pressed.emit(_id)


func _on_hire() -> void:
	hire_pressed.emit(_id)


func _add_button(button: Button, action: Callable) -> Button:
	button.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	button.size_flags_horizontal = SIZE_SHRINK_BEGIN
	button.focus_mode = FOCUS_ALL
	button.visible = false
	if action.is_valid():
		button.pressed.connect(action)
	add_child(button)
	return button


func _make_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	button.focus_mode = FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.text = text
	button.pressed.connect(action)
	return button


func _add_label(font_size: int) -> Label:
	var label := Label.new()
	label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", font_size)
	add_child(label)
	return label
