class_name WorldsSection
extends HBoxContainer
## The Archive's Worlds section: every known world (state not UNKNOWN) as a row with its state,
## sorted by name, beside the World Report of the chosen world. It refreshes when a world's state
## or a report fact rises (also while paused) and whenever it is shown. Mouse: click a row.
## Gamepad: D-pad through the rows, A opens the report, Right reaches **Plan expedition**.
## **Plan expedition** re-emits as [signal plan_requested]. Reads state only.
## Bible: docs/content/m3-beyond-the-ring.md section 7 (World Report; gamepad: Worlds)

## Emitted when the report's **Plan expedition** is pressed, with its world.
signal plan_requested(world_id: StringName)

const _LIST_WIDTH: float = 300.0

var _simulation: Simulation = null
var _rows: Array[Button] = []
var _ids: Array[StringName] = []
var _refresh_queued: bool = false
var _above: Control = null
var _rows_box: VBoxContainer = VBoxContainer.new()
var _empty: Label = Label.new()
var _report: WorldReportPanel = WorldReportPanel.new()


func _init() -> void:
	add_theme_constant_override(&"separation", 8)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = _LIST_WIDTH
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty.text = &"WORLD_LIST_EMPTY"
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_empty)
	_rows_box.add_theme_constant_override(&"separation", 2)
	column.add_child(_rows_box)
	scroll.add_child(column)
	add_child(scroll)
	add_child(_report)
	_report.plan_requested.connect(
		func(world_id: StringName) -> void: plan_requested.emit(world_id)
	)
	visibility_changed.connect(_on_visibility_changed)


func _enter_tree() -> void:
	EventBus.world_status_changed.connect(_on_world_status_changed)
	EventBus.world_fact_raised.connect(_on_world_fact_raised)


func _exit_tree() -> void:
	EventBus.world_status_changed.disconnect(_on_world_status_changed)
	EventBus.world_fact_raised.disconnect(_on_world_fact_raised)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## Connects the section to [param simulation]; no world is open.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_report.clear()
	refresh()


## Up from the first row goes to [param above] (the section tabs).
func link_up(above: Control) -> void:
	_above = above
	_link_rows()


## Rebuilds the rows from the state and re-reads the open report.
func refresh() -> void:
	_refresh_queued = false
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	var ids: Array[StringName] = WorldReportText.known_world_ids(state)
	if ids != _ids:
		_rebuild(ids)
	for index: int in _ids.size():
		_rows[index].text = _row_text(_ids[index])
		_rows[index].set_pressed_no_signal(_ids[index] == _report.get_world_id())
	_empty.visible = _ids.is_empty()
	if not _report.get_world_id().is_empty():
		_report.show_world(_report.get_world_id(), state)


## Opens the report of [param world_id]; a world the base does not know is ignored.
func open_world(world_id: StringName) -> void:
	if _simulation == null or not _ids.has(world_id):
		return
	_report.show_world(world_id, _simulation.state)
	for index: int in _ids.size():
		_rows[index].set_pressed_no_signal(_ids[index] == world_id)
	_link_rows()


## Returns the rows, in listing order.
func get_rows() -> Array[Button]:
	return _rows


## Returns the world ids of the rows, in listing order.
func get_world_ids() -> Array[StringName]:
	return _ids


## Returns the report panel.
func get_report() -> WorldReportPanel:
	return _report


## The open world's row, else the first row; null with no worlds.
func get_first_focus() -> Control:
	var index: int = _ids.find(_report.get_world_id())
	if index >= 0:
		return _rows[index]
	return null if _rows.is_empty() else _rows[0]


func _rebuild(ids: Array[StringName]) -> void:
	for row: Button in _rows:
		_rows_box.remove_child(row)
		row.queue_free()
	_rows.clear()
	_ids = ids.duplicate()
	for world_id: StringName in _ids:
		var row := Button.new()
		row.toggle_mode = true
		row.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.pressed.connect(open_world.bind(world_id))
		_rows_box.add_child(row)
		_rows.append(row)
	if not _ids.has(_report.get_world_id()):
		_report.clear()
	_link_rows()


func _row_text(world_id: StringName) -> String:
	var state: GameState = _simulation.state
	return (
		tr(&"WORLD_ROW")
		. format(
			{
				"world": AddressBookText.name_of_world(world_id, state),
				"status": WorldReportText.status_name(state.worlds.status_of(world_id)),
			}
		)
	)


## Rows step Up/Down; Up from the first reaches the tabs; Right from any row reaches
## **Plan expedition** while a report is open, and Left from it returns to the open row.
func _link_rows() -> void:
	var plan: Button = _report.get_plan_button()
	var open_row: Control = get_first_focus()
	for index: int in _rows.size():
		var row: Button = _rows[index]
		row.focus_neighbor_top = NodePath()
		if index == 0 and _above != null:
			row.focus_neighbor_top = row.get_path_to(_above)
		var right: Control = plan if plan.visible else row
		row.focus_neighbor_right = row.get_path_to(right)
		row.focus_neighbor_left = row.get_path_to(row)
	if open_row != null:
		plan.focus_neighbor_left = plan.get_path_to(open_row)
	plan.focus_neighbor_right = plan.get_path_to(plan)


func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		refresh.call_deferred()


func _on_world_status_changed(_world_id: StringName, _status: int) -> void:
	_queue_refresh()


func _on_world_fact_raised(_world_id: StringName, _fact: int, _confidence: int) -> void:
	_queue_refresh()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
