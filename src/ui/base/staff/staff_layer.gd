class_name StaffLayer
extends Control
## The staff tokens over the base plan: one per person on base, at a spot in their room, or
## outside Quarters when unassigned. Draws with the plan's zoom and pan and only the plan's
## level. Never takes the mouse: the plan asks it which token is under a point. Reads the
## running simulation's state; updates on staff events, ticks (arrivals) and loads.
## Bible: docs/content/interface-pass.md section 5 (Staff tokens)

## The selected token changed: a person id or &"".
signal token_selected(person_id: StringName)

## Distance in plan pixels within which a point hits a token.
const HIT_RADIUS: float = 8.0
## Gap between unassigned tokens outside Quarters, in plan pixels.
const QUEUE_GAP: float = 14.0

## Moves tokens along corridors when people are reassigned, arrive or leave.
var walker := TokenWalker.new()
## People shifting about, visiting and going to Quarters at night (display/ambient_movement).
var ambient := AmbientLife.new()

var _plan: BasePlan = null
var _tokens: Dictionary[StringName, StaffToken] = {}
var _arriving: Dictionary[StringName, bool] = {}
var _selected: StringName = &""
var _hovered: StringName = &""


func _init() -> void:
	name = &"StaffLayer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED:
		_plan = get_parent() as BasePlan
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	elif what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		snap()


func _enter_tree() -> void:
	for signal_name: StringName in [&"staff_changed", &"day_started"]:
		EventBus.connect(signal_name, _on_event)
	EventBus.staff_arrived.connect(_on_arrived)
	EventBus.game_loaded.connect(_on_loaded)
	Settings.setting_changed.connect(_on_setting_changed)


func _exit_tree() -> void:
	for signal_name: StringName in [&"staff_changed", &"day_started"]:
		EventBus.disconnect(signal_name, _on_event)
	EventBus.staff_arrived.disconnect(_on_arrived)
	EventBus.game_loaded.disconnect(_on_loaded)
	Settings.setting_changed.disconnect(_on_setting_changed)


## Rebuilds every token from [param state]; called by the plan with the running state.
func rebuild(state: GameState) -> void:
	var kept: Dictionary[StringName, StaffToken] = {}
	var before: Dictionary[StringName, Vector3] = {}
	for person: PersonState in on_base(state):
		var known: bool = _tokens.has(person.id)
		var token: StaffToken = _tokens.get(person.id, StaffToken.new())
		if known:
			before[person.id] = Vector3(token.home.x, token.home.y, token.home_level)
		token.person_id = person.id
		token.name = person.name
		token.role = person.role
		token.room_id = person.room_id
		kept[person.id] = token
	for id: StringName in _tokens:
		if not kept.has(id):
			_send_out(state, _tokens[id])
	_tokens = kept
	ambient.reset()
	_place_all(state)
	_start_walks(state, before)
	if _plan != null:
		_plan.tray.show_tokens(unassigned(state))
	if not _tokens.has(_selected):
		_selected = &""
	queue_redraw()


## The people of [param state] shown on the plan: arrived and not away on a team.
static func on_base(state: GameState) -> Array[PersonState]:
	var found: Array[PersonState] = []
	for person: PersonState in state.staff.people:
		if person.is_on_base(state.clock.tick) and not StaffRules.is_on_team(state, person.id):
			found.append(person)
	return found


## The token of [param person_id], or null.
func token_for(person_id: StringName) -> StaffToken:
	return _tokens.get(person_id)


## Every token, in no set order.
func tokens() -> Array[StaffToken]:
	return _tokens.values()


## The unassigned tokens, in roster order of [param state].
func unassigned(state: GameState) -> Array[StaffToken]:
	var found: Array[StaffToken] = []
	for person: PersonState in on_base(state):
		if person.room_id == &"":
			found.append(_tokens[person.id])
	return found


## The selected person, or &"".
func selected() -> StringName:
	return _selected


## Selects the token of [param person_id] (&"" for none).
func select(person_id: StringName) -> void:
	if person_id != &"" and not _tokens.has(person_id):
		return
	_selected = person_id
	queue_redraw()
	token_selected.emit(person_id)


## Shows the level of [param person_id]'s token on the plan, selects their room (if any) and
## the token.
func focus_person(person_id: StringName) -> void:
	var token: StaffToken = token_for(person_id)
	if token == null or _plan == null:
		return
	_plan.show_level(token.level)
	if token.room_id != &"":
		_plan.select(token.room_id)
	select(person_id)


## The token on the shown level under [param point] (this control's coordinates), or &"".
func token_at(point: Vector2) -> StringName:
	if _plan == null:
		return &""
	var plan_point: Vector2 = (point - _plan.view.offset) / _plan.view.scale()
	var best: StringName = &""
	var best_distance: float = HIT_RADIUS
	for token: StaffToken in _tokens.values():
		var distance: float = token.position.distance_to(plan_point)
		if token.level == _plan.level and distance <= best_distance:
			best = token.person_id
			best_distance = distance
	return best


## Shows [param person_id]'s name and role by the token (hover), or none with &"".
func set_hovered(person_id: StringName) -> void:
	if person_id == _hovered:
		return
	_hovered = person_id
	queue_redraw()


func _place_all(state: GameState) -> void:
	var by_room: Dictionary[StringName, int] = {}
	var queue: int = 0
	var quarters: RoomState = _first_quarters(state)
	for person: PersonState in on_base(state):
		var token: StaffToken = _tokens[person.id]
		var room: RoomState = state.base.find_room(person.room_id)
		if room == null:
			token.home_level = 1 if quarters == null else quarters.level
			token.home = _queue_spot(state, quarters, queue)
			queue += 1
		else:
			var index: int = by_room.get(room.id, 0)
			by_room[room.id] = index + 1
			token.home_level = room.level
			token.home = _room_spot(state, room, index)


## Walks every token whose place changed; new tokens appear at home, or walk in from the
## lift when the person just arrived.
func _start_walks(state: GameState, before: Dictionary[StringName, Vector3]) -> void:
	for id: StringName in _tokens:
		var token: StaffToken = _tokens[id]
		if before.has(id):
			var was: Vector3 = before[id]
			if Vector2(was.x, was.y) == token.home and int(was.z) == token.home_level:
				continue
			_walk(state, token, token.home_level)
		elif _arriving.has(id):
			_arriving.erase(id)
			var lift: Vector3i = entrance(state)
			token.position = (Vector2(lift.x, lift.y) + Vector2(0.5, 0.5)) * BasePlanPainter.CELL
			token.level = lift.z
			_walk(state, token, token.home_level)
		else:
			token.position = token.home
			token.level = token.home_level


func _walk(state: GameState, token: StaffToken, to_level: int) -> void:
	var from := Vector3i(
		floori(token.position.x / BasePlanPainter.CELL),
		floori(token.position.y / BasePlanPainter.CELL),
		token.level
	)
	var to := Vector3i(
		floori(token.home.x / BasePlanPainter.CELL),
		floori(token.home.y / BasePlanPainter.CELL),
		to_level
	)
	var path: PackedVector3Array = PlanPaths.find(state.base, from, to, state.room_defs)
	if path.is_empty():
		token.level = to_level
	walker.walk(token, path)


## A dismissed or departing person walks to the lift and vanishes.
func _send_out(state: GameState, token: StaffToken) -> void:
	var from := Vector3i(
		floori(token.position.x / BasePlanPainter.CELL),
		floori(token.position.y / BasePlanPainter.CELL),
		token.level
	)
	walker.leave(token, PlanPaths.find(state.base, from, entrance(state), state.room_defs))


## The cell people arrive at and leave from: the top level's lift, else its first corridor.
static func entrance(state: GameState) -> Vector3i:
	var fallback := Vector3i(0, 0, 1)
	for room: RoomState in state.base.rooms:
		if room.level != 1 or not room.is_built():
			continue
		if room.def_id == StartingBase.LIFT_DEF:
			return Vector3i(room.origin.x, room.origin.y, 1)
		if room.def_id == StartingBase.CORRIDOR_DEF and fallback == Vector3i(0, 0, 1):
			fallback = Vector3i(room.origin.x, room.origin.y, 1)
	return fallback


## Puts every token at its place at once (tab or level change).
func snap() -> void:
	walker.snap_all(tokens())
	for token: StaffToken in _tokens.values():
		token.level = token.home_level
	queue_redraw()


func _process(delta: float) -> void:
	var simulation: Simulation = SimClock.simulation
	if simulation == null:
		return
	var clock: ClockState = simulation.state.clock
	if not clock.is_paused and Settings.get_bool(&"display", &"ambient_movement"):
		var factor: float = TokenWalker.SPEED_FACTORS[clampi(clock.speed_index, 0, 3)]
		ambient.step(self, simulation.state, delta, factor)
	if walker.step(_tokens, delta, clock.speed_index, clock.is_paused):
		queue_redraw()


## Walks [param token] to [param target] (plan pixels) on [param level] for ambient life,
## without changing the person's assignment.
func move_token(state: GameState, token: StaffToken, target: Vector2, level: int) -> void:
	token.home = target
	token.home_level = level
	_walk(state, token, level)


## The plan pixels of spot [param index] of [param count] in [param room].
func spot_pixels(state: GameState, room: RoomState, index: int, count: int) -> Vector2:
	var def: RoomDef = state.room_defs.get(room.def_id)
	if def == null:
		return Vector2(room.origin) * BasePlanPainter.CELL
	var cells: Rect2i = BaseRules.footprint(room, def)
	var spots: Array[Vector2] = RoomSpots.for_room(def, cells.size, count)
	var area := Rect2(Vector2(cells.position), Vector2(cells.size))
	return (area.position + area.size * spots[index % spots.size()]) * BasePlanPainter.CELL


func _room_spot(state: GameState, room: RoomState, index: int) -> Vector2:
	var def: RoomDef = state.room_defs.get(room.def_id)
	if def == null:
		return Vector2(room.origin) * BasePlanPainter.CELL
	var cells: Rect2i = BaseRules.footprint(room, def)
	var slots: int = maxi(StaffRules.slots(state, room), index + 1)
	var spots: Array[Vector2] = RoomSpots.for_room(def, cells.size, slots)
	var area := Rect2(Vector2(cells.position), Vector2(cells.size))
	return (area.position + area.size * spots[index % spots.size()]) * BasePlanPainter.CELL


## Unassigned people line up just below Quarters, or along the first corridor without one.
func _queue_spot(state: GameState, quarters: RoomState, index: int) -> Vector2:
	if quarters == null:
		var corridor: RoomState = _first_corridor(state)
		if corridor == null:
			return Vector2(QUEUE_GAP * (index + 1), QUEUE_GAP)
		var start := Vector2(corridor.origin) * BasePlanPainter.CELL
		return start + Vector2(QUEUE_GAP * (index + 0.5), BasePlanPainter.CELL * 0.5)
	var def: RoomDef = state.room_defs.get(quarters.def_id)
	if def == null:
		return Vector2(quarters.origin) * BasePlanPainter.CELL
	var cells: Rect2i = BaseRules.footprint(quarters, def)
	var start := Vector2(cells.position.x, cells.end.y) * BasePlanPainter.CELL
	return start + Vector2(QUEUE_GAP * (index + 0.5), BasePlanPainter.CELL * 0.5)


static func _first_corridor(state: GameState) -> RoomState:
	for room: RoomState in state.base.rooms:
		if room.def_id == StartingBase.CORRIDOR_DEF and room.is_built() and room.level == 1:
			return room
	return null


static func _first_quarters(state: GameState) -> RoomState:
	for room: RoomState in state.base.rooms:
		if room.def_id == &"room_quarters" and room.is_built():
			return room
	return null


func _draw() -> void:
	if _plan == null:
		return
	draw_set_transform(_plan.view.offset, 0.0, Vector2.ONE * _plan.view.scale())
	var font: Font = UiThemeBuilder.data_font()
	for token: StaffToken in _tokens.values() + walker.leaving():
		if token.level == _plan.level:
			var alpha: float = walker.alpha_of(token.person_id)
			StaffToken.draw(self, token, font, token.person_id == _selected, alpha)
	for id: StringName in [_hovered, _selected]:
		var token: StaffToken = _tokens.get(id)
		if token != null and token.level == _plan.level:
			_draw_name(token, font)
	draw_set_transform(Vector2.ZERO)


func _draw_name(token: StaffToken, font: Font) -> void:
	var role_def: DefBase = Registry.get_def(token.role) if Registry.has_def(token.role) else null
	var role_key: Variant = null if role_def == null else role_def.get(&"name_key")
	var role_name: String = (
		String(token.role) if role_key == null else tr(StringName(str(role_key)))
	)
	var text: String = "%s · %s" % [token.name, role_name]
	var size: int = 9
	var at: Vector2 = token.position + Vector2(StaffToken.RADIUS + 3.0, -StaffToken.RADIUS - 2.0)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_rect(
		Rect2(at - Vector2(2, size), Vector2(width + 4, size + 4)), Color(UiPalette.GROUND, 0.85)
	)
	draw_string(font, at, text, 0, -1, size, UiPalette.TEXT)


## Switching ambient movement off sends everyone back to their spots.
func _on_setting_changed(section: StringName, key: StringName, _value: Variant) -> void:
	if section == &"display" and key == &"ambient_movement":
		_on_event()


func _on_arrived(person_id: StringName) -> void:
	_arriving[person_id] = true
	_on_event()


func _on_loaded(_slot: StringName) -> void:
	_tokens.clear()
	walker.snap_all([])
	_on_event()


func _on_event(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	var simulation: Simulation = SimClock.simulation
	if simulation != null and is_inside_tree():
		rebuild(simulation.state)
