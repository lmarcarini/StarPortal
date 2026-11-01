class_name RoomPanel
extends VBoxContainer
## The selected-room panel of the Base tab, read only: the room's name, size, power draw (or
## output), monthly upkeep and status, then its description. For the capacitor alcove it
## names the marked site. With nothing selected it shows a hint. Under the lines, a hold
## button offers the room's action (Cancel a site, Demolish a room) with its refund, or why it
## is refused; the panel only emits [signal action_held].
## Bible: docs/content/m2-base.md sections 4 and 6

## Emitted when the action button's hold confirms; [param command] is the one to submit.
signal action_held(command: Command)

var _heading: Label = _add_label(16)
var _name: Label = _add_label(22)
var _size: Label = _add_label(16)
var _draw_line: Label = _add_label(16)
var _upkeep: Label = _add_label(16)
var _status: Label = _add_label(16)
var _description: Label = _add_label(16)
var _action: HoldButton = _add_action()
var _reason: Label = _add_label(14)
var _command: Command = null


## Shows nothing selected.
func show_nothing() -> void:
	_set_lines([tr(&"BASE_PANEL_SELECTED"), "", "", "", "", "", tr(&"BASE_PANEL_NONE")])


## Shows [param room] built from [param def].
func show_room(room: RoomState, def: RoomDef) -> void:
	_set_lines(
		[
			tr(&"BASE_PANEL_SELECTED"),
			tr(def.name_key),
			size_text(room, def),
			BasePanelText.power(def),
			BasePanelText.upkeep(def.upkeep_k),
			BasePanelText.status(room, def),
			tr(def.description_key),
		]
	)


## Shows the free capacitor alcove, sized for [param bank].
func show_alcove(bank: RoomDef) -> void:
	var cells: Vector2i = bank.size_cells if bank != null else Vector2i.ZERO
	_set_lines(
		[
			tr(&"BASE_PANEL_SELECTED"),
			tr(&"BASE_ALCOVE_NAME"),
			tr(&"BASE_PANEL_SIZE").format({"w": cells.x, "h": cells.y}),
			"",
			"",
			tr(&"BASE_STATUS_SITE"),
			tr(&"BASE_ALCOVE_DESC"),
		]
	)


## Returns the panel's lines, top to bottom, as shown.
func lines() -> Array[String]:
	var found: Array[String] = []
	for label: Label in [_heading, _name, _size, _draw_line, _upkeep, _status, _description]:
		found.append(label.text)
	return found


## Returns "Size 4 × 3" for [param room], turned when it is.
func size_text(room: RoomState, def: RoomDef) -> String:
	var cells: Vector2i = BaseRules.footprint(room, def).size
	return tr(&"BASE_PANEL_SIZE").format({"w": cells.x, "h": cells.y})


func _set_lines(texts: Array) -> void:
	var labels: Array[Label] = [_heading, _name, _size, _draw_line, _upkeep, _status, _description]
	for index: int in labels.size():
		var text: String = texts[index]
		labels[index].text = text
		labels[index].visible = not text.is_empty()


## Offers [param command] on the action button as [param text]; when [param reason] is not
## empty the button is disabled and the reason shows under it. A null command hides both.
func show_action(command: Command, text: String, reason: String = "") -> void:
	_command = command
	_action.visible = command != null
	_action.text = text
	_action.disabled = not reason.is_empty()
	_reason.text = reason
	_reason.visible = command != null and not reason.is_empty()


## Returns the action button.
func get_action_button() -> HoldButton:
	return _action


## Returns the reason under the action button, or "".
func get_action_reason() -> String:
	return _reason.text if _reason.visible else ""


func _add_action() -> HoldButton:
	var button := HoldButton.new()
	button.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	button.visible = false
	button.size_flags_horizontal = SIZE_SHRINK_BEGIN
	button.confirmed.connect(_on_action_confirmed)
	add_child(button)
	return button


func _on_action_confirmed() -> void:
	if _command != null:
		action_held.emit(_command)


func _add_label(font_size: int) -> Label:
	var label := Label.new()
	label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", font_size)
	add_child(label)
	return label
