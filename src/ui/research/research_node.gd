class_name ResearchNode
extends PanelContainer
## One node of the research tree (docs/content/m25-lean-start.md section 3): the name, then
## by state "$400k · 2 d" with Start, a progress bar and the time left (active), "done ✓",
## "needs Lift shaft" (dimmed) or, for a locked slot, "Unknown" and its reason. The node
## takes focus (D-pad, click); focusing it emits [signal chosen], and (A) or Enter on it
## emits [signal activated].
## Bible: docs/content/m25-lean-start.md section 3

## Emitted when the node takes focus.
signal chosen(project_id: StringName)
## Emitted on (A) or Enter while the node has focus.
signal activated(project_id: StringName)

## Size of a node, in pixels.
const SIZE: Vector2 = Vector2(220, 84)

var project_id: StringName = &""
var _name: Label = _label(16)
var _detail: Label = _label(14)
var _state: Label = _label(14)
var _bar: ProgressBar = ProgressBar.new()


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	focus_mode = FOCUS_ALL
	mouse_filter = MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 2)
	_bar.custom_minimum_size = Vector2(0, 6)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.mouse_filter = MOUSE_FILTER_IGNORE
	for part: Control in [_name, _detail, _state, _bar]:
		box.add_child(part)
	add_child(box)
	focus_entered.connect(_on_focus)
	focus_exited.connect(queue_redraw)


## Shows [param def] as it stands in [param state].
func show_project(state: GameState, def: ResearchDef) -> void:
	project_id = def.id
	_name.text = tr(def.name_key)
	var kind: ResearchText.Kind = ResearchText.kind(state, def)
	_detail.text = tr(def.line_key) if def.is_locked() else _cost(def)
	_state.text = ResearchText.state_word(state, def)
	_bar.visible = kind == ResearchText.Kind.ACTIVE
	if _bar.visible:
		_bar.value = ResearchRules.progress(state)
		var left: String = ResearchText.time_left(state)
		_state.text = left if not left.is_empty() else _state.text
	var dim: bool = kind == ResearchText.Kind.NEEDS or kind == ResearchText.Kind.LOCKED
	modulate = Color(1, 1, 1, 0.55) if dim else Color.WHITE
	tooltip_text = tr(def.line_key)


## Returns the node's lines, top to bottom: name, detail, state.
func texts() -> Array[String]:
	return [_name.text, _detail.text, _state.text]


## Returns the progress bar, shown while the project runs.
func get_bar() -> ProgressBar:
	return _bar


func _cost(def: ResearchDef) -> String:
	var days: String = tr(&"RESEARCH_DAYS").format({"n": def.days})
	return "%s · %s" % [MoneyLabel.format_k(def.cost_k), days]


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


static func _label(font_size: int) -> Label:
	var label := Label.new()
	label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", font_size)
	return label
