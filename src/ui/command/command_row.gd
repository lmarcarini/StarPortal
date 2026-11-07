class_name CommandRow
extends PanelContainer
## One 32 px row of the Command tab (docs/content/m27-daily-rhythm.md section 4): a name and
## two right-aligned figures (a money line: per day and per 30 days, or a cause: its date and
## words, then the change). A focusable row takes the D-pad and the mouse: (A), Enter or a
## click emits [signal activated]; its tooltip shows the same breakdown on hover.
## Bible: docs/content/m27-daily-rhythm.md section 4

## Emitted when the row takes focus.
signal chosen(row: CommandRow)
## Emitted on (A), Enter or a click.
signal activated(row: CommandRow)

## Height of a row, in pixels.
const HEIGHT: int = 32
## Widths of the two figure columns.
const FIGURE_WIDTHS: Array[int] = [110, 130]
## Font size of the rows.
const FONT_SIZE: int = 16

## What the row stands for (the index of its money line or cause), set by its owner.
var index: int = -1
var _name: Label = _label(0)
var _first: Label = _label(FIGURE_WIDTHS[0])
var _second: Label = _label(FIGURE_WIDTHS[1])


func _init(focusable: bool = true) -> void:
	custom_minimum_size.y = HEIGHT
	focus_mode = FOCUS_ALL if focusable else FOCUS_NONE
	mouse_filter = MOUSE_FILTER_STOP if focusable else MOUSE_FILTER_IGNORE
	add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	var box := HBoxContainer.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 12)
	_name.size_flags_horizontal = SIZE_EXPAND_FILL
	_first.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_second.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for part: Label in labels():
		box.add_child(part)
	add_child(box)
	focus_entered.connect(_on_focus)
	focus_exited.connect(queue_redraw)


## Shows [param name] with the figures [param first] and [param second] ("" hides one).
func show_texts(name: String, first: String, second: String) -> void:
	_name.text = name
	_first.text = first
	_first.visible = not first.is_empty()
	_second.text = second
	_second.visible = not second.is_empty()


## Sets the name column's minimum width (the cause rows' date column).
func set_name_width(width: int) -> void:
	_name.custom_minimum_size.x = width


## Returns the row's labels: name, first figure, second figure.
func labels() -> Array[Label]:
	return [_name, _first, _second]


## Returns the shown texts, left to right.
func texts() -> Array[String]:
	var found: Array[String] = []
	for label: Label in labels():
		if label.visible:
			found.append(label.text)
	return found


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		accept_event()
		activated.emit(self)
	elif event.is_action_pressed(&"ui_accept"):
		accept_event()
		activated.emit(self)


func _draw() -> void:
	if has_focus():
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.6), false, 2.0)


func _on_focus() -> void:
	queue_redraw()
	chosen.emit(self)


static func _label(width: int) -> Label:
	var label := Label.new()
	label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	label.custom_minimum_size.x = width
	label.size_flags_vertical = SIZE_SHRINK_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	return label
