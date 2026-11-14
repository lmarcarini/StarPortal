class_name BasePlan
extends Control
## The plan of one base level, straight from above (docs/content/m2-base.md section 6). Read
## only: it shows the rooms at their cells, sites hatched, a progress bar on each site and
## demolition (SiteBar), and the selection. No cell is
## reserved. The mouse wheel or the right stick zooms; a right
## or middle drag or the left stick pans; a click or (A) on the cursor cell selects what is
## there; the arrow keys or the D-pad move the cell cursor. Staff tokens stand on the plan
## (StaffLayer) and the unassigned are listed in a tray along its bottom
## (docs/content/interface-pass.md section 5).
## Bible: docs/content/m2-base.md section 6, game-design.md#base-building-and-power

## Emitted when the selection changes: a room id or [code]&""[/code].
signal selection_changed(selected: StringName)
## Emitted when a staff token is chosen on the plan or in the tray: a person id.
signal person_chosen(person_id: StringName)

## Level shown, 1 the top one.
var level: int = 1
## Cell under the keyboard and gamepad cursor.
var cursor: Vector2i = Vector2i.ZERO
## Zoom and pan of the plan inside this control.
var view: ZoomPan = ZoomPan.new()
## The staff tokens over the plan.
var staff_layer := StaffLayer.new()
## The unassigned people, along the bottom of the plan.
var tray := UnassignedTray.new()

var _base: BaseState = null
var _defs: Dictionary = {}
var _selected: StringName = &""
var _dragging: bool = false
## SiteProgress by room id, for the sites' and demolitions' bars (SiteBar).
var _progress: Dictionary = {}


func _init() -> void:
	add_child(staff_layer)
	add_child(tray)
	tray.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tray.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tray.person_chosen.connect(_choose_person)


func _ready() -> void:
	focus_mode = FOCUS_ALL
	clip_contents = true
	resized.connect(_on_resized)


## Shows [param base], with its RoomDefs by id in [param defs]. Keeps the level when it still
## exists.
func show_base(base: BaseState, defs: Dictionary) -> void:
	_base = base
	_defs = defs
	level = clampi(level, 1, maxi(1, base.level_count))
	view.reset(Vector2(base.grid_size) * BasePlanPainter.CELL, size)
	if base.find_room(_selected) == null:
		select(&"")
	var simulation: Simulation = SimClock.simulation
	if simulation != null and simulation.state.base == base:
		staff_layer.rebuild(simulation.state)
	queue_redraw()


## Shows the bars of [param progress] (SiteProgress by room id, SiteProgress.for_rooms).
func show_progress(progress: Dictionary) -> void:
	_progress = progress
	queue_redraw()


## Returns the progress shown for room [param id], or null.
func progress_of(id: StringName) -> SiteProgress:
	var found: Variant = _progress.get(id)
	return found if found is SiteProgress else null


## Shows level [param number] (clamped to the levels there are) and clears the selection.
func show_level(number: int) -> void:
	if _base == null:
		return
	var clamped: int = clampi(number, 1, maxi(1, _base.level_count))
	if clamped == level:
		return
	level = clamped
	select(&"")
	staff_layer.snap()
	queue_redraw()


## Returns the selection: a room id or [code]&""[/code].
func selected() -> StringName:
	return _selected


## Selects [param id] (a room id or [code]&""[/code]).
func select(id: StringName) -> void:
	if id == _selected:
		return
	_selected = id
	queue_redraw()
	selection_changed.emit(id)


## Returns what stands at [param cell] on the shown level: a room id or [code]&""[/code].
func item_at(cell: Vector2i) -> StringName:
	if _base == null:
		return &""
	for room: RoomState in BaseRules.rooms_on_level(_base, level):
		var def: RoomDef = _def(room.def_id)
		if def != null and BaseRules.footprint(room, def).has_point(cell):
			return room.id
	return &""


## Returns the cell at [param point] in this control's coordinates.
func cell_at(point: Vector2) -> Vector2i:
	var plan_point: Vector2 = (point - view.offset) / view.scale()
	return Vector2i((plan_point / BasePlanPainter.CELL).floor())


func _draw() -> void:
	if _base == null:
		return
	draw_set_transform(view.offset, 0.0, Vector2.ONE * view.scale())
	BasePlanPainter.draw_ground(self, _base.grid_size)
	var font: Font = UiThemeBuilder.stencil_font()
	for room: RoomState in BaseRules.rooms_on_level(_base, level):
		_draw_room(room, font)
	var chosen: Rect2i = _selected_cells()
	if chosen.size != Vector2i.ZERO:
		BasePlanPainter.draw_selection(self, chosen)
	if has_focus():
		BasePlanPainter.draw_cursor(self, cursor)
	draw_set_transform(Vector2.ZERO)
	staff_layer.queue_redraw()


func _draw_room(room: RoomState, font: Font) -> void:
	var def: RoomDef = _def(room.def_id)
	if def == null:
		return
	var cells: Rect2i = BaseRules.footprint(room, def)
	var plan_state: StringName = BasePlanPainter.state_of(room, def)
	if plan_state == BasePlanPainter.SITE or plan_state == BasePlanPainter.COMING_DOWN:
		BasePlanPainter.draw_site(self, cells, plan_state == BasePlanPainter.COMING_DOWN)
	elif room.def_id == StartingBase.CORRIDOR_DEF:
		BasePlanPainter.draw_corridor(self, cells)
	else:
		BasePlanPainter.draw_room(self, cells, room.def_id, plan_state, view.scale())
	if room.def_id != StartingBase.CORRIDOR_DEF or not room.is_built():
		BasePlanPainter.draw_label(self, cells, tr(def.name_key).to_upper(), font)
	var progress: SiteProgress = progress_of(room.id)
	if progress != null:
		var cell: float = BasePlanPainter.CELL
		var area := Rect2(Vector2(cells.position) * cell, Vector2(cells.size) * cell)
		SiteBar.draw(self, area, progress, ProgressText.caption(progress), font)


func _selected_cells() -> Rect2i:
	var room: RoomState = _base.find_room(_selected)
	if room == null or room.level != level:
		return Rect2i()
	var def: RoomDef = _def(room.def_id)
	return BaseRules.footprint(room, def) if def != null else Rect2i()


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		staff_layer.set_hovered(staff_layer.token_at(motion.position))
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var person: StringName = staff_layer.token_at(click.position)
		if person != &"":
			_choose_person(person)
			accept_event()
			return
	if BasePlanInput.handle(self, event):
		accept_event()


## Selects [param person_id]'s token and their room.
func _choose_person(person_id: StringName) -> void:
	staff_layer.focus_person(person_id)
	person_chosen.emit(person_id)


func _process(delta: float) -> void:
	BasePlanInput.apply_sticks(self, delta)


## Moves the cursor by [param step] cells, kept inside the grid.
func move_cursor(step: Vector2i) -> void:
	if _base == null:
		return
	cursor = (cursor + step).clamp(Vector2i.ZERO, _base.grid_size - Vector2i.ONE)
	queue_redraw()


## Selects what stands at the cursor cell.
func select_at_cursor() -> void:
	select(item_at(cursor))


## True while a pan drag is in progress.
func is_dragging() -> bool:
	return _dragging


## Starts or ends a pan drag.
func set_dragging(on: bool) -> void:
	_dragging = on


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()


func _on_resized() -> void:
	view.resize(size)
	queue_redraw()


## The RoomDef with id [param def_id], or null.
func _def(def_id: StringName) -> RoomDef:
	var found: Variant = _defs.get(def_id)
	return found if found is RoomDef else null
