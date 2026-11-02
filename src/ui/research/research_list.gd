class_name ResearchList
extends VBoxContainer
## The Research list (docs/content/m25-lean-start.md section 3): a header with the current
## project, its time left and a progress bar, then one [ResearchRow] per project in list
## order. Open projects come first, then the locked "Unknown" slots, then the done projects,
## ticked. The rows scroll and follow focus; up and down (D-pad) move between them.
## Bible: docs/content/m25-lean-start.md section 3

## Emitted when a row takes focus.
signal project_chosen(project_id: StringName)
## Emitted on (A) or Enter on a row.
signal project_activated(project_id: StringName)

var _title: Label = _label(18)
var _current: Label = _label(16)
var _left: Label = _label(16)
var _bar: ProgressBar = ProgressBar.new()
var _scroll: ScrollContainer = ScrollContainer.new()
var _rows_box: VBoxContainer = VBoxContainer.new()
var _rows: Dictionary[StringName, ResearchRow] = {}


func _init() -> void:
	add_theme_constant_override(&"separation", 8)
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 16)
	header.custom_minimum_size.y = ResearchRow.HEIGHT
	_current.size_flags_horizontal = SIZE_EXPAND_FILL
	_current.clip_text = true
	_current.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_bar.custom_minimum_size = Vector2(160, 16)
	_bar.size_flags_vertical = SIZE_SHRINK_CENTER
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.step = 0.0
	for part: Control in [_title, _current, _left, _bar]:
		header.add_child(part)
	add_child(header)
	add_child(HSeparator.new())
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_rows_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override(&"separation", 0)
	_scroll.add_child(_rows_box)
	add_child(_scroll)


## Shows the projects of [param state]: header, rows and their order.
func show_state(state: GameState) -> void:
	_title.text = tr(&"RESEARCH_HEADING")
	_current.text = ResearchText.current(state)
	_left.text = ResearchText.time_left(state)
	_bar.visible = state.research.is_running()
	_bar.value = ResearchRules.progress(state)
	var index: int = 0
	for def: ResearchDef in ordered(state):
		var row: ResearchRow = _row(def.id)
		row.show_project(state, def)
		_rows_box.move_child(row, index)
		index += 1


## The defs of [param state] in the order the list shows them.
static func ordered(state: GameState) -> Array[ResearchDef]:
	var open: Array[ResearchDef] = []
	var locked: Array[ResearchDef] = []
	var done: Array[ResearchDef] = []
	for def: ResearchDef in ResearchRules.projects(state):
		if def.is_locked():
			locked.append(def)
		elif state.research.is_done(def.id):
			done.append(def)
		else:
			open.append(def)
	open.append_array(locked)
	open.append_array(done)
	return open


## Returns the rows, top to bottom.
func rows() -> Array[ResearchRow]:
	var found: Array[ResearchRow] = []
	for child: Node in _rows_box.get_children():
		found.append(child as ResearchRow)
	return found


## Returns the row of [param project_id], or null.
func row_of(project_id: StringName) -> ResearchRow:
	return _rows.get(project_id)


## Returns the header's texts: title, current project, time left.
func header() -> Array[String]:
	return [_title.text, _current.text, _left.text]


## Returns the header's progress bar.
func get_bar() -> ProgressBar:
	return _bar


func _row(project_id: StringName) -> ResearchRow:
	var row: ResearchRow = _rows.get(project_id)
	if row != null:
		return row
	row = ResearchRow.new()
	row.chosen.connect(project_chosen.emit)
	row.activated.connect(project_activated.emit)
	_rows_box.add_child(row)
	_rows[project_id] = row
	return row


static func _label(font_size: int) -> Label:
	var label := Label.new()
	label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	label.size_flags_vertical = SIZE_SHRINK_CENTER
	label.add_theme_font_size_override(&"font_size", font_size)
	return label
