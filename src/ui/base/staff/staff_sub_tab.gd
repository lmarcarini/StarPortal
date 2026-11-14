class_name StaffSubTab
extends VBoxContainer
## The Base's Staff sub-tab strip: everyone on base (role letter, name and room), and an
## Assign key for the selected person that starts placing them on the plan (keyboard and
## gamepad: move the cursor to a highlighted room and confirm; Esc or (B) cancels). While it
## shows, the plan tints rooms by filled slots.
## Bible: docs/content/interface-pass.md section 5 (Allocation by placing)

## The player chose [param person_id] in the list.
signal person_chosen(person_id: StringName)
## The player pressed Assign for the selected person.
signal assign_pressed
## Staff changed: the list should be redrawn.
signal staff_changed

## Height of the scrolling list, so the strip never grows over the plan or the sub-tabs.
const LIST_HEIGHT: float = 92.0

## Starts placing the selected person.
var assign_button := Button.new()

var _list := HFlowContainer.new()
var _hint := Label.new()


func _init() -> void:
	name = &"StaffSubTab"
	visible = false
	var row := HBoxContainer.new()
	var title := Label.new()
	title.text = &"STAFF_SUBTAB_TITLE"
	title.theme_type_variation = &"StencilLabel"
	row.add_child(title)
	assign_button.text = &"STAFF_PLACE"
	assign_button.disabled = true
	assign_button.pressed.connect(assign_pressed.emit)
	row.add_child(assign_button)
	_hint.theme_type_variation = &"StencilLabel"
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.clip_text = true
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_hint)
	add_child(row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = LIST_HEIGHT
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	add_child(scroll)


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
		var button := Button.new()
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.toggle_mode = true
		button.button_pressed = person.id == selected
		button.text = (
			"%s %s · %s"
			% [StaffToken.letter_of(person.role), person.name, _room_name(state, person.room_id)]
		)
		button.pressed.connect(person_chosen.emit.bind(person.id))
		_list.add_child(button)
	assign_button.disabled = selected == &""


## Shows [param text] beside the Assign key (a refusal or how to place).
func show_hint(text: String) -> void:
	_hint.text = text


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
	return tr(&"STAFF_TRAY_TITLE") if def == null else tr(def.name_key)
