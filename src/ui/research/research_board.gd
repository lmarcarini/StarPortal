class_name ResearchBoard
extends VBoxContainer
## The left side of the Research tab (docs/content/m25-lean-start.md section 3): a header
## with the current project, its time left and a progress bar, the category sub-tabs
## (Construction, Energy, Gate, Alien, Staff, from the ResearchCategoryDefs) with a dot on
## each one that has a project to start, and the [ResearchTree] of the chosen sub-tab.
## Bible: docs/content/m25-lean-start.md section 3

## Emitted when a node takes focus.
signal project_chosen(project_id: StringName)
## Emitted on (A) or Enter on a node.
signal project_activated(project_id: StringName)
## Emitted when another sub-tab is shown.
signal category_changed(category: StringName)

## Appended to the name of a sub-tab with a project to start.
const DOT: String = " •"

var _title: Label = _label(18)
var _current: Label = _label(16)
var _left: Label = _label(16)
var _bar: ProgressBar = ProgressBar.new()
var _tabs: TabBar = TabBar.new()
var _scroll: ScrollContainer = ScrollContainer.new()
var _canvas: Control = Control.new()
var _tree: ResearchTree = ResearchTree.new()
var _controls := ResearchTreeControls.new()
var _zoom: float = 1.0
var _categories: Array[ResearchCategoryDef] = []
var _state: GameState = null


func _init() -> void:
	add_theme_constant_override(&"separation", 8)
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 16)
	header.custom_minimum_size.y = 48
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
	_tabs.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_tabs.focus_mode = FOCUS_ALL
	_tabs.tab_changed.connect(_on_tab_changed)
	add_child(_tabs)
	add_child(_controls)
	_controls.changed.connect(_apply_view)
	_controls.zoom_requested.connect(zoom_by)
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_canvas.mouse_filter = MOUSE_FILTER_IGNORE
	_canvas.add_child(_tree)
	_scroll.add_child(_canvas)
	_scroll.gui_input.connect(_on_scroll_input)
	add_child(_scroll)
	_tree.stub_pressed.connect(jump_to)
	_tree.project_chosen.connect(project_chosen.emit)
	_tree.project_activated.connect(project_activated.emit)


## Uses [param categories] as the sub-tabs, in their order; keeps the shown one if it stays.
func set_categories(categories: Array[ResearchCategoryDef]) -> void:
	var shown: StringName = get_category()
	_categories = categories.duplicate()
	_categories.sort_custom(
		func(a: ResearchCategoryDef, b: ResearchCategoryDef) -> bool: return a.order < b.order
	)
	_tabs.set_block_signals(true)
	_tabs.clear_tabs()
	for category: ResearchCategoryDef in _categories:
		_tabs.add_tab(tr(category.name_key))
	_tabs.set_block_signals(false)
	var index: int = maxi(0, _index_of(shown))
	if not _categories.is_empty():
		_tabs.current_tab = index


## Shows [param state]: the header, the sub-tab dots and the shown sub-tab's tree.
func show_state(state: GameState) -> void:
	_state = state
	_title.text = tr(&"RESEARCH_HEADING")
	_current.text = ResearchText.current(state)
	_left.text = ResearchText.time_left(state)
	_bar.visible = state.research.is_running()
	_bar.value = ResearchRules.progress(state)
	for index: int in _categories.size():
		var category: ResearchCategoryDef = _categories[index]
		var dot: String = DOT if has_available(state, category.id) else ""
		_tabs.set_tab_title(index, tr(category.name_key) + dot)
	_tree.show_category(state, get_category())
	_apply_view()


## True when a project of [param category] can be started in [param state] (its needs done).
static func has_available(state: GameState, category: StringName) -> bool:
	for def: ResearchDef in state.research_defs.values():
		if def.category == category and ResearchText.kind(state, def) == ResearchText.Kind.START:
			return true
	return false


## Shows the sub-tab [param offset] away from the current one; false at either end (then the
## shoulder button is left to the main tabs).
func step_category(offset: int) -> bool:
	var index: int = _tabs.current_tab + offset
	if index < 0 or index >= _categories.size():
		return false
	_tabs.current_tab = index
	return true


## Shows the sub-tab of [param category]; unknown ids are ignored.
func show_category(category: StringName) -> void:
	var index: int = _index_of(category)
	if index >= 0:
		_tabs.current_tab = index


## The id of the shown sub-tab, or &"".
func get_category() -> StringName:
	var index: int = _tabs.current_tab
	return _categories[index].id if index >= 0 and index < _categories.size() else &""


## Returns the sub-tab titles, left to right.
func tab_titles() -> Array[String]:
	var found: Array[String] = []
	for index: int in _tabs.tab_count:
		found.append(_tabs.get_tab_title(index))
	return found


## Returns the tree of the shown sub-tab.
func get_tree_view() -> ResearchTree:
	return _tree


## Returns the sub-tab bar.
func get_tabs() -> TabBar:
	return _tabs


## Returns the filter and search bar.
func get_controls() -> ResearchTreeControls:
	return _controls


## The tree's zoom (0.4 to 2).
func get_zoom() -> float:
	return _zoom


## Zooms the tree by [param factor], between 0.4 and 2.
func zoom_by(factor: float) -> void:
	_zoom = clampf(_zoom * factor, 0.4, 2.0)
	_tree.scale = Vector2(_zoom, _zoom)
	_canvas.custom_minimum_size = _tree.custom_minimum_size * _zoom


## Shows [param project_id]'s branch and scrolls its node to the middle of the view.
func jump_to(project_id: StringName) -> void:
	var def: ResearchDef = null if _state == null else _state.research_defs.get(project_id)
	if def == null:
		return
	show_category(def.category)
	centre_on(project_id)


## Scrolls so [param project_id]'s node sits in the middle of the view; false when not shown.
func centre_on(project_id: StringName) -> bool:
	var node: ResearchNode = _tree.node_of(project_id)
	if node == null:
		return false
	var centre: Vector2 = (node.position + ResearchNode.SIZE * 0.5) * _zoom
	_scroll.scroll_horizontal = int(centre.x - _scroll.size.x * 0.5)
	_scroll.scroll_vertical = int(centre.y - _scroll.size.y * 0.5)
	return true


## Pans with the right stick (research_pan_* actions) while shown.
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var pan: Vector2 = Input.get_vector(
		&"research_pan_left", &"research_pan_right", &"research_pan_up", &"research_pan_down"
	)
	if not pan.is_zero_approx():
		_scroll.scroll_horizontal += int(pan.x * 900.0 * delta)
		_scroll.scroll_vertical += int(pan.y * 900.0 * delta)


func _apply_view() -> void:
	if _state == null:
		return
	_canvas.custom_minimum_size = _tree.custom_minimum_size * _zoom
	var matches: Array[StringName] = _tree.apply_view(
		_state, _controls.get_filter(), _controls.get_search()
	)
	if not matches.is_empty() and not _controls.get_search().strip_edges().is_empty():
		centre_on(matches[0])


## Ctrl + mouse wheel zooms the tree.
func _on_scroll_input(event: InputEvent) -> void:
	var wheel: InputEventMouseButton = event as InputEventMouseButton
	if wheel == null or not wheel.pressed or not wheel.ctrl_pressed:
		return
	if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_by(ResearchTreeControls.ZOOM_STEP)
		_scroll.accept_event()
	elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_by(1.0 / ResearchTreeControls.ZOOM_STEP)
		_scroll.accept_event()


## Returns the header's texts: title, current project, time left.
func header() -> Array[String]:
	return [_title.text, _current.text, _left.text]


## Returns the header's progress bar.
func get_bar() -> ProgressBar:
	return _bar


func _index_of(category: StringName) -> int:
	for index: int in _categories.size():
		if _categories[index].id == category:
			return index
	return -1


func _on_tab_changed(_index: int) -> void:
	if _state != null:
		show_state(_state)
	category_changed.emit(get_category())


static func _label(font_size: int) -> Label:
	var label := Label.new()
	label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	label.size_flags_vertical = SIZE_SHRINK_CENTER
	label.add_theme_font_size_override(&"font_size", font_size)
	return label
