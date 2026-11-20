class_name SecurityLayer
extends Control
## Squads, intruders and the objective on the base plan (M4c-11). Squads are numbered square
## tags; intruder groups are red diamonds with their count, drawn only where SightRules can
## see them; elsewhere a hollow diamond marks where a group was last seen and fades over
## SightRules.FADE_TICKS. The room a seen group is heading for carries a target mark. Marks
## glide to the simulation's cells between ticks. Reads the state only.
## Bible: docs/content/m4c-incursions.md section 7

const _GLIDE: float = 10.0

## Where each mark is drawn now (plan pixels), by key ("squad:<post>", "group:<index>").
var shown: Dictionary[String, Vector2] = {}
## Last sighting of each group index: [cell, tick].
var last_seen: Dictionary[int, Array] = {}
## Rooms marked as the objective.
var targets: Array[StringName] = []
## The squad whose path to the plan's cursor is previewed (M4c-12), or &"".
var preview_squad: StringName = &""

var _plan: BasePlan = null


func _init() -> void:
	name = &"SecurityLayer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED:
		_plan = get_parent() as BasePlan
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var simulation: Simulation = SimClock.simulation
	if simulation == null or _plan == null:
		return
	var state: GameState = simulation.state
	if not preview_squad.is_empty():
		queue_redraw()
	if not state.incursion.is_active() and state.security.squads.is_empty():
		if not shown.is_empty():
			shown.clear()
			last_seen.clear()
			targets.clear()
			queue_redraw()
		return
	update_from(state)
	var weight: float = clampf(delta * _GLIDE, 0.0, 1.0)
	var wanted: Dictionary[String, Vector2] = _wanted(state)
	for key: String in wanted:
		var goal: Vector2 = wanted[key]
		var now: Vector2 = shown.get(key, goal)
		shown[key] = now.lerp(goal, weight)
	queue_redraw()


## Records sightings and objective marks from [param state].
func update_from(state: GameState) -> void:
	for index: int in state.incursion.groups.size():
		var group: IntruderGroup = state.incursion.groups[index]
		if group.standing().is_empty() or not SightRules.visible(state, group):
			continue
		last_seen[index] = [group.pos(), state.clock.tick]
		if not group.target_room.is_empty() and not targets.has(group.target_room):
			targets.append(group.target_room)


## The cell centre of [param cell] in plan pixels.
static func centre(cell: Vector3i) -> Vector2:
	return (Vector2(cell.x, cell.y) + Vector2(0.5, 0.5)) * BasePlanPainter.CELL


func _wanted(state: GameState) -> Dictionary[String, Vector2]:
	var found: Dictionary[String, Vector2] = {}
	for squad: SquadState in state.security.squads:
		found["squad:" + String(squad.post_room)] = centre(squad.pos)
	for index: int in state.incursion.groups.size():
		var group: IntruderGroup = state.incursion.groups[index]
		if SightRules.visible(state, group):
			found["group:%d" % index] = centre(group.pos())
	return found


func _draw() -> void:
	var simulation: Simulation = SimClock.simulation
	if simulation == null or _plan == null:
		return
	var state: GameState = simulation.state
	draw_set_transform(_plan.view.offset, 0.0, Vector2.ONE * _plan.view.scale())
	var font: Font = get_theme_default_font()
	_draw_targets(state)
	_draw_preview(state)
	_draw_last_seen(state)
	for index: int in state.incursion.groups.size():
		var group: IntruderGroup = state.incursion.groups[index]
		var key: String = "group:%d" % index
		if group.pos().z == _plan.level and shown.has(key) and SightRules.visible(state, group):
			SecurityMarks.diamond(self, shown[key], group.standing().size(), font, true)
	draw_set_transform(Vector2.ZERO)
	_draw_squads(state)


func _draw_squads(state: GameState) -> void:
	var picked: SquadState = state.security.squad_of(preview_squad)
	for squad: SquadState in state.security.squads:
		var key: String = "squad:" + String(squad.post_room)
		if squad.pos.z == _plan.level and shown.has(key):
			var number: int = SquadRules.number_of(state, squad.post_room)
			SecurityMarks.tag(self, _screen(shown[key]), number, squad == picked)


func _screen(at: Vector2) -> Vector2:
	return _plan.view.offset + at * _plan.view.scale()


func _draw_preview(state: GameState) -> void:
	var squad: SquadState = state.security.squad_of(preview_squad)
	if squad == null:
		return
	var goal := Vector3i(_plan.cursor.x, _plan.cursor.y, _plan.level)
	var path: PackedVector3Array = BasePaths.find(state.base, squad.pos, goal, state.room_defs)
	var points := PackedVector2Array()
	for point: Vector3 in path:
		if int(point.z) == _plan.level:
			points.append(_screen(Vector2(point.x, point.y) * BasePlanPainter.CELL))
	if points.size() >= 2:
		draw_set_transform(Vector2.ZERO)
		SecurityMarks.path(self, points)
		draw_set_transform(_plan.view.offset, 0.0, Vector2.ONE * _plan.view.scale())


func _draw_last_seen(state: GameState) -> void:
	for index: int in last_seen:
		var sighting: Array = last_seen[index]
		var cell: Vector3i = sighting[0]
		var seen_tick: int = sighting[1]
		var since: int = state.clock.tick - seen_tick
		if cell.z != _plan.level or since <= 0 or since >= SightRules.FADE_TICKS:
			continue
		var alpha: float = 1.0 - float(since) / float(SightRules.FADE_TICKS)
		SecurityMarks.faded(self, centre(cell), alpha)


func _draw_targets(state: GameState) -> void:
	for room_id: StringName in targets:
		var room: RoomState = state.base.find_room(room_id)
		var def: RoomDef = null if room == null else state.room_defs.get(room.def_id)
		if def != null and room.level == _plan.level:
			SecurityMarks.target(self, BaseRules.footprint(room, def))
