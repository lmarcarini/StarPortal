class_name ResearchRow
extends PanelContainer
## One 48 px row of the Research list (docs/content/m25-lean-start.md section 3): name, cost,
## days, unlock line and state. A locked slot shows "Unknown" and its reason in the line
## column. The row takes focus (D-pad, click); focusing it emits [signal chosen], and (A) or
## Enter on it emits [signal activated]. Done rows are dimmed.
## Bible: docs/content/m25-lean-start.md section 3

## Emitted when the row takes focus.
signal chosen(project_id: StringName)
## Emitted on (A) or Enter while the row has focus.
signal activated(project_id: StringName)

## Height of a row, in pixels.
const HEIGHT: float = 48.0

var project_id: StringName = &""
var _name: Label = _cell(0, true)
var _cost: Label = _cell(96, false)
var _days: Label = _cell(64, false)
var _line: Label = _cell(0, true)
var _state: Label = _cell(140, false)


func _init() -> void:
	custom_minimum_size.y = HEIGHT
	focus_mode = FOCUS_ALL
	mouse_filter = MOUSE_FILTER_STOP
	var cells := HBoxContainer.new()
	cells.add_theme_constant_override(&"separation", 12)
	cells.mouse_filter = MOUSE_FILTER_IGNORE
	for label: Label in [_name, _cost, _days, _line, _state]:
		cells.add_child(label)
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(cells)
	focus_entered.connect(_on_focus)
	focus_exited.connect(queue_redraw)


## Shows [param def] as it stands in [param state].
func show_project(state: GameState, def: ResearchDef) -> void:
	project_id = def.id
	_name.text = tr(def.name_key)
	_line.text = tr(def.line_key)
	var locked: bool = def.is_locked()
	_cost.text = "" if locked else MoneyLabel.format_k(def.cost_k)
	_days.text = "" if locked else tr(&"RESEARCH_DAYS").format({"n": def.days})
	_state.text = ResearchText.state_word(state, def)
	var kind: ResearchText.Kind = ResearchText.kind(state, def)
	var dim: bool = kind == ResearchText.Kind.DONE or kind == ResearchText.Kind.LOCKED
	modulate = Color(1, 1, 1, 0.55) if dim else Color.WHITE
	tooltip_text = _line.text


## Returns the texts of the row's columns, left to right.
func texts() -> Array[String]:
	return [_name.text, _cost.text, _days.text, _line.text, _state.text]


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		accept_event()
		activated.emit(project_id)


func _draw() -> void:
	if has_focus():
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.6), false, 2.0)


func _on_focus() -> void:
	queue_redraw()
	chosen.emit(project_id)


static func _cell(width: float, expand: bool) -> Label:
	var label := Label.new()
	label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	label.custom_minimum_size.x = width
	label.size_flags_vertical = SIZE_SHRINK_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = MOUSE_FILTER_IGNORE
	if expand:
		label.size_flags_horizontal = SIZE_EXPAND_FILL
	return label
