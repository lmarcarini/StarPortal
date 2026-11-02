class_name PlacementGhost
extends Control
## The ghost footprint of the room being placed, drawn over the [BasePlan] it is a child of: green
## when the placement command would be accepted, red with the first broken rule's reason otherwise.
## It follows the mouse and the plan's cell cursor. Q, E or a shoulder button turns it; one left
## click, Enter or (A) builds it at once (no hold), and the ghost stays out to place another; Esc,
## (B) or a right click leaves placing. A corridor is painted as a run: drag with the mouse (the run
## builds on release), or move the cursor and press Enter or (A); Esc or (B) first clears the run.
## Keys count only while the plan has focus, so focused buttons and dialogs get theirs first.
## Changes no state: it emits [signal build_held] with the command to submit.
## Bible: docs/content/m2-base.md sections 4 and 6

## Emitted when a click or press confirms the placement; [param command] is the one to submit.
signal build_held(command: Command)
## Emitted when the ghost is checked again: [param reason] is empty when it is valid.
signal checked(reason: String)
## Emitted when placing ends without building.
signal cancelled

const _OK := Color(0.35, 0.85, 0.45, 0.45)
const _BAD := Color(0.9, 0.3, 0.25, 0.45)
const _STEPS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

## Def being placed, or &"" when not placing.
var def_id: StringName = &""
## True when turned a quarter turn.
var rotated: bool = false
## Top-left cell of the footprint (a room) or the run's last cell (a corridor).
var origin: Vector2i = Vector2i.ZERO
## The corridor run being painted, in painting order.
var run: Array[Vector2i] = []

var _plan: BasePlan = null
var _state: GameState = null
var _reason: String = ""
var _painting: bool = false
var _cursor: Vector2i = Vector2i.ZERO


## Attaches the ghost to [param plan] (as its child) to place rooms in [param state].
func attach(plan: BasePlan, state: GameState) -> void:
	_plan = plan
	_state = state
	if get_parent() == null:
		plan.add_child(self)
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_set_placing(false)


## True while a room or corridor is being placed.
func is_placing() -> bool:
	return not def_id.is_empty()


## Starts placing [param room_def] at [param cell] of the shown level.
func start(room_def: StringName, cell: Vector2i) -> void:
	def_id = room_def
	rotated = false
	run.clear()
	_set_placing(true)
	move_to(cell)


## Stops placing; emits [signal cancelled] when [param by_player].
func stop(by_player: bool = false) -> void:
	def_id = &""
	run.clear()
	_painting = false
	_set_placing(false)
	queue_redraw()
	if by_player:
		cancelled.emit()


## Turns the ghost when its def may turn.
func rotate_ghost() -> void:
	var def: RoomDef = _def()
	if def == null or not def.rotatable or is_corridor():
		return
	rotated = not rotated
	_check()


## Moves the ghost to [param cell]; a corridor run grows to it, or shrinks when it steps back.
func move_to(cell: Vector2i) -> void:
	if not is_placing():
		return
	origin = cell
	if is_corridor():
		_extend_run(cell)
	_check()


## True when a corridor is being painted.
func is_corridor() -> bool:
	return def_id == StartingBase.CORRIDOR_DEF


## The command the ghost stands for now, or null when not placing.
func command() -> Command:
	if not is_placing():
		return null
	if is_corridor():
		return PaintCorridorCommand.create(_plan.level, run)
	return PlaceRoomCommand.create(def_id, _plan.level, origin, rotated)


## Why the ghost may not be built here, or "" when it may.
func reason() -> String:
	return _reason


## The cells the ghost covers, as one rect (a corridor run's bounding box).
func area() -> Rect2i:
	var def: RoomDef = _def()
	if def == null:
		return Rect2i()
	if is_corridor():
		var box := (
			Rect2i(run[0], Vector2i.ONE) if not run.is_empty() else Rect2i(origin, Vector2i.ONE)
		)
		for cell: Vector2i in run:
			box = box.expand(cell).merge(Rect2i(cell, Vector2i.ONE))
		return box
	var probe := RoomState.create(&"", def_id, _plan.level, origin)
	probe.rotated = rotated
	return BaseRules.footprint(probe, def)


## Total cost of the ghost in $k.
func cost_k() -> int:
	var def: RoomDef = _def()
	if def == null:
		return 0
	return def.build_cost_k * (maxi(1, run.size()) if is_corridor() else 1)


## Emits [signal build_held] with the command when the ghost is valid.
func confirm() -> void:
	_check()
	if is_placing() and _reason.is_empty():
		build_held.emit(command())


## After a build: a corridor starts a new run at the cursor; the ghost stays out and checks again.
func after_build() -> void:
	if is_corridor():
		run = [origin]
	_painting = false
	recheck()


## Checks the ghost again (money or rooms may have changed).
func recheck() -> void:
	if is_placing():
		_check()


func _process(_delta: float) -> void:
	if _plan != null and _plan.cursor != _cursor:
		_cursor = _plan.cursor
		move_to(_cursor)


## Moves the plan's cursor and the ghost to [param cell] together (the mouse).
func follow(cell: Vector2i) -> void:
	_plan.cursor = cell
	_cursor = cell
	move_to(cell)
	_plan.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_placing() or not is_visible_in_tree() or not _plan.has_focus():
		return
	if PlacementInput.handle_key(self, event):
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if is_placing() and PlacementInput.handle_mouse(self, _plan, event):
		accept_event()


## Starts or ends painting a corridor run with the mouse at [param cell].
func set_painting(on: bool, cell: Vector2i) -> void:
	_painting = on and is_corridor()
	if _painting:
		run.clear()
		follow(cell)


## True while a corridor run is being dragged.
func is_painting() -> bool:
	return _painting


func _extend_run(cell: Vector2i) -> void:
	if run.size() >= 2 and run[-2] == cell:
		run.pop_back()
		return
	if cell in run:
		return
	if run.is_empty() or (not _painting and _distance(run[-1], cell) != 1):
		run = [cell]
		return
	var step: Vector2i = run[-1]
	while step != cell:
		if step.x != cell.x:
			step.x += signi(cell.x - step.x)
		else:
			step.y += signi(cell.y - step.y)
		if step not in run:
			run.append(step)


static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _check() -> void:
	var result: CommandResult = command().validate(_state)
	_reason = _reason_of(result)
	queue_redraw()
	checked.emit(_reason)


func _reason_of(result: CommandResult) -> String:
	if result.is_ok:
		return ""
	if result.error_code == &"overlap":
		var level: int = BuildText.level_of(result.detail)
		var on: int = level if level > 0 else _plan.level
		return BuildText.overlap_reason(_state, on, area(), on != _plan.level)
	return BuildText.reason(result, _state, cost_k())


func _draw() -> void:
	if not is_placing() or _plan == null:
		return
	draw_set_transform(_plan.view.offset, 0.0, Vector2.ONE * _plan.view.scale())
	var color: Color = _OK if _reason.is_empty() else _BAD
	if is_corridor():
		for cell: Vector2i in run:
			draw_rect(_pixels(Rect2i(cell, Vector2i.ONE)), color)
	else:
		var box: Rect2 = _pixels(area())
		draw_rect(box, color)
		draw_rect(box, color.lightened(0.4), false, 2.0)
	draw_set_transform(Vector2.ZERO)


static func _pixels(cells: Rect2i) -> Rect2:
	return Rect2(
		Vector2(cells.position) * BasePlanPainter.CELL, Vector2(cells.size) * BasePlanPainter.CELL
	)


func _set_placing(on: bool) -> void:
	mouse_filter = MOUSE_FILTER_PASS if on else MOUSE_FILTER_IGNORE
	set_process(on)
	if on and _plan != null:
		_cursor = _plan.cursor


func _def() -> RoomDef:
	return _state.room_defs.get(def_id) if _state != null else null
