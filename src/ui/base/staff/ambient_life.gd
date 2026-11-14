class_name AmbientLife
extends RefCounted
## Ambient movement of staff tokens (presentation only): people shift between spots in their
## room, now and then visit another room and come back, and at night most go to Quarters
## while one keeper stays in every room that is on. It only moves tokens' places on the plan;
## any staff event rebuilds the tokens and so interrupts it at once. Its own seeded
## RandomNumberGenerator; never the simulation's.
## Bible: docs/content/interface-pass.md section 5 (Ambient life)

## Spots in a room beyond its slots, so there is somewhere to move to.
const EXTRA_SPOTS: int = 2
## Real seconds a visit lasts before the person walks back, at 1x.
const VISIT_SECONDS: float = 6.0
const _SEED: int = 4519

var _rng := RandomNumberGenerator.new()
var _timers: Dictionary[StringName, float] = {}
var _visits: Dictionary[StringName, float] = {}
var _layer: StaffLayer = null
var _state: GameState = null


func _init() -> void:
	_rng.seed = _SEED


## Forgets every timer and visit (after a rebuild or when switched off).
func reset() -> void:
	_timers.clear()
	_visits.clear()


## Advances ambient life by [param delta] real seconds at speed [param factor] over the
## tokens of [param layer], reading [param state]. Moves go through [method StaffLayer.move_token].
func step(layer: StaffLayer, state: GameState, delta: float, factor: float) -> void:
	_layer = layer
	_state = state
	var hour: int = TimeMath.date_of(state.clock.tick)["hour"]
	var night: bool = AmbientRules.is_night(hour)
	var keepers: Dictionary[StringName, bool] = _keepers()
	for token: StaffToken in layer.tokens():
		if token.room_id == &"" or layer.walker.is_moving(token.person_id):
			continue
		var resting: bool = night and not keepers.has(token.person_id)
		resting = resting and not AmbientRules.on_shift(token.person_id, hour)
		if resting and _send_to_quarters(token):
			continue
		_tick_person(token, delta * factor, resting)


## Each room that is on keeps its first person at night.
func _keepers() -> Dictionary[StringName, bool]:
	var found: Dictionary[StringName, bool] = {}
	var seen: Dictionary[StringName, bool] = {}
	for person: PersonState in StaffLayer.on_base(_state):
		if person.room_id == &"" or seen.has(person.room_id):
			continue
		var room: RoomState = _state.base.find_room(person.room_id)
		var def: RoomDef = null if room == null else _state.room_defs.get(room.def_id)
		if def != null and BasePlanPainter.state_of(room, def) == BasePlanPainter.ON:
			seen[person.room_id] = true
			found[person.id] = true
	return found


func _tick_person(token: StaffToken, seconds: float, resting: bool) -> void:
	var id: StringName = token.person_id
	if _visits.has(id):
		_visits[id] -= seconds
		if _visits[id] <= 0.0:
			_visits.erase(id)
			_go_to_spot(token, _state.base.find_room(token.room_id), -1)
		return
	if resting:
		return
	if not _timers.has(id):
		_timers[id] = AmbientRules.wait_seconds(_rng, 1.0)
	_timers[id] -= seconds
	if _timers[id] > 0.0:
		return
	_timers[id] = AmbientRules.wait_seconds(_rng, 1.0)
	_move(token)


func _move(token: StaffToken) -> void:
	var room: RoomState = _state.base.find_room(token.room_id)
	if room == null:
		return
	var others: Array[RoomState] = _other_rooms(room)
	var ambient := AmbientState.new()
	ambient.spot_count = _spot_count(room)
	ambient.taken = _taken(room)
	ambient.other_rooms = others.size()
	var move: AmbientMove = AmbientRules.next_move(_rng, ambient)
	match move.kind:
		AmbientMove.SPOT:
			_go_to_spot(token, room, move.index)
		AmbientMove.VISIT:
			_visits[token.person_id] = VISIT_SECONDS
			_go_to_spot(token, others[move.index], -1)


## Walks [param token] to spot [param index] of [param room] (-1: any free spot).
func _go_to_spot(token: StaffToken, room: RoomState, index: int) -> void:
	if room == null:
		return
	var count: int = _spot_count(room)
	var spot: int = index
	if spot < 0:
		var taken: Array[int] = _taken(room)
		spot = 0
		while taken.has(spot) and spot < count - 1:
			spot += 1
	_layer.move_token(_state, token, _layer.spot_pixels(_state, room, spot, count), room.level)


func _send_to_quarters(token: StaffToken) -> bool:
	for room: RoomState in _state.base.rooms:
		if room.def_id != &"room_quarters" or not room.is_built():
			continue
		if _inside(room, token.home) and token.home_level == room.level:
			return true
		if _taken(room).size() >= _spot_count(room):
			continue
		_go_to_spot(token, room, -1)
		return true
	return false


func _spot_count(room: RoomState) -> int:
	var people: int = 0
	for token: StaffToken in _layer.tokens():
		if token.room_id == room.id:
			people += 1
	return maxi(StaffRules.slots(_state, room), people) + EXTRA_SPOTS


## Spot indices of [param room] whose place a token already heads to.
func _taken(room: RoomState) -> Array[int]:
	var count: int = _spot_count(room)
	var found: Array[int] = []
	for spot: int in count:
		var at: Vector2 = _layer.spot_pixels(_state, room, spot, count)
		for token: StaffToken in _layer.tokens():
			if token.home_level == room.level and token.home.distance_to(at) < 1.0:
				found.append(spot)
				break
	return found


func _inside(room: RoomState, point: Vector2) -> bool:
	var def: RoomDef = _state.room_defs.get(room.def_id)
	if def == null:
		return false
	var cells: Rect2i = BaseRules.footprint(room, def)
	return (
		Rect2(
			Vector2(cells.position) * BasePlanPainter.CELL,
			Vector2(cells.size) * BasePlanPainter.CELL
		)
		. has_point(point)
	)


func _other_rooms(room: RoomState) -> Array[RoomState]:
	var found: Array[RoomState] = []
	for other: RoomState in _state.base.rooms:
		if other == room or other.def_id == StartingBase.CORRIDOR_DEF:
			continue
		var def: RoomDef = _state.room_defs.get(other.def_id)
		if def != null and BasePlanPainter.state_of(other, def) == BasePlanPainter.ON:
			found.append(other)
	return found
