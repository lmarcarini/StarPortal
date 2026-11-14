class_name UnassignedTray
extends PanelContainer
## The strip at the bottom of the base plan listing everyone on base without a room, one
## button each (role letter and name). Pressing one focuses that person's token. Hidden when
## nobody is unassigned.
## Bible: docs/content/interface-pass.md section 5 (Staff tokens)

## The player chose [param person_id] in the tray.
signal person_chosen(person_id: StringName)

var _row := HFlowContainer.new()
var _title := Label.new()


func _init() -> void:
	name = &"UnassignedTray"
	theme_type_variation = &"PanelBezel"
	var box := HBoxContainer.new()
	add_child(box)
	_title.text = &"STAFF_TRAY_TITLE"
	_title.theme_type_variation = &"StencilLabel"
	box.add_child(_title)
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_row)
	visible = false


## Shows [param tokens] (the unassigned people), or hides the tray when there are none.
func show_tokens(tokens: Array[StaffToken]) -> void:
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for token: StaffToken in tokens:
		var button := Button.new()
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.text = "%s %s" % [StaffToken.letter_of(token.role), token.name]
		button.pressed.connect(person_chosen.emit.bind(token.person_id))
		_row.add_child(button)
	visible = not tokens.is_empty()


## The buttons, one per unassigned person.
func buttons() -> Array[Button]:
	var found: Array[Button] = []
	for child: Node in _row.get_children():
		if child is Button and not child.is_queued_for_deletion():
			found.append(child as Button)
	return found
