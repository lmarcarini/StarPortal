class_name StaffSubTab
extends Control
## The Base console's STAFF tray (interface-reference.md section 8): everyone on base as face
## tiles (name, role letter, room). Drag a tile onto a room's empty slot (a dashed amber line
## follows), or onto the tray to unassign. A press chooses the person and starts placing them
## (keyboard and gamepad: move the cursor to a highlighted room and confirm; Esc or (B)
## cancels).
## Bible: docs/content/interface-pass.md section 5 (Allocation by placing)

## The player chose [param person_id] in the list.
signal person_chosen(person_id: StringName)
## The player pressed Assign for the selected person.
signal assign_pressed
## Staff changed: the list should be redrawn.
signal staff_changed
## A face's drag began: show which rooms take [param person_id].
signal drag_started(person_id: StringName)
## A face was dropped on the tray: unassign [param person_id].
signal tray_drop(person_id: StringName)

## Height of the scrolling list, so the strip never grows over the plan or the sub-tabs.
const LIST_HEIGHT: float = 92.0

## Starts placing the selected person.
var assign_button := Button.new()

var _list := HBoxContainer.new()
var _scroll := ScrollContainer.new()
var _hint := Label.new()


func _init() -> void:
	name = &"StaffSubTab"
	visible = false
	custom_minimum_size = Vector2(0, StaffFaceKey.SIZE.y + 16)
	assign_button.visible = false
	assign_button.pressed.connect(assign_pressed.emit)
	add_child(assign_button)
	_hint.visible = false
	_hint.z_index = 2
	_hint.position = Vector2(4, -40)
	_hint.add_theme_color_override(&"font_color", RefPaint.AMBER)
	_hint.add_theme_font_override(
		&"font", RefText.make(RefText.LABEL_MEDIUM, 0, RefPaint.AMBER, 1.0).get_font()
	)
	_hint.add_theme_font_size_override(&"font_size", 17)
	add_child(_hint)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_list.add_theme_constant_override(&"separation", 8)
	_scroll.add_child(_list)
	add_child(_scroll)
	TrayArrow.new().attach(_scroll)
	resized.connect(func() -> void: _scroll.position = Vector2(10, 8))
	resized.connect(func() -> void: _scroll.size = size - Vector2(20, 16))


## Dropping a face on the tray takes the person out of their room.
func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var payload: Dictionary = data if data is Dictionary else {}
	return payload.has("person")


func _drop_data(_at: Vector2, data: Variant) -> void:
	var payload: Dictionary = data if data is Dictionary else {}
	var person: StringName = payload.get("person", &"")
	tray_drop.emit(person)


func _enter_tree() -> void:
	EventBus.staff_changed.connect(_on_staff_changed)


func _exit_tree() -> void:
	EventBus.staff_changed.disconnect(_on_staff_changed)


func _on_staff_changed(_reason: StringName, _room_def_id: StringName, _count: int) -> void:
	staff_changed.emit()


## Lists the people of [param state] on base; [param selected] marks the chosen one.
func show_state(state: GameState, selected: StringName) -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for person: PersonState in StaffLayer.on_base(state):
		var tile := StaffFaceKey.new()
		tile.person_id = person.id
		tile.person = person
		tile.text = person.name
		tile.room_line = (
			"%s · %s" % [StaffToken.letter_of(person.role), _room_name(state, person.room_id)]
		)
		tile.button_pressed = person.id == selected
		tile.pressed.connect(person_chosen.emit.bind(person.id))
		tile.drag_started.connect(drag_started.emit)
		_list.add_child(tile)
	assign_button.disabled = selected == &""


## Shows [param text] beside the Assign key (a refusal or how to place).
func show_hint(text: String) -> void:
	_hint.text = text
	_hint.visible = not text.is_empty()


## The list buttons, one per person on base.
func rows() -> Array[Button]:
	var found: Array[Button] = []
	for child: Node in _list.get_children():
		if child is Button and not child.is_queued_for_deletion():
			found.append(child as Button)
	return found


func _room_name(state: GameState, room_id: StringName) -> String:
	var room: RoomState = state.base.find_room(room_id)
	var def: RoomDef = null if room == null else state.room_defs.get(room.def_id)
	return "—" if def == null else BuildCardText.title(def).get_slice(" ", 0)
