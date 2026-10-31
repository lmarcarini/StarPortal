class_name RoomPanel
extends VBoxContainer
## The selected-room panel of the Base tab, read only: the room's name, size, power draw (or
## output), monthly upkeep and status, then its description. For the capacitor alcove it
## names the marked site. With nothing selected it shows a hint.
## Bible: docs/content/m2-base.md section 6

var _heading: Label = _add_label(16)
var _name: Label = _add_label(20)
var _size: Label = _add_label(14)
var _draw_line: Label = _add_label(14)
var _upkeep: Label = _add_label(14)
var _status: Label = _add_label(14)
var _description: Label = _add_label(14)


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


func _add_label(font_size: int) -> Label:
	var label := Label.new()
	label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", font_size)
	add_child(label)
	return label
