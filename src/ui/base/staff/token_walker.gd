class_name TokenWalker
extends RefCounted
## Moves staff tokens along their walking paths, frame by frame. Presentation only: the
## simulation has already assigned the person. Walk speed is in cells a second: a base value
## times a factor that rises with the clock speed, capped. Paused, tokens stop. A token with
## no path fades out and in at its new place. Leaving tokens vanish at the end of their walk.
## Bible: docs/content/interface-pass.md section 5 (Staff walk)

## Base walk speed, in cells a second at 1x.
const CELLS_PER_SECOND: float = 3.0
## Speed factor per clock speed (SimClock.SPEEDS order), capped.
const SPEED_FACTORS: Array[float] = [0.75, 1.0, 1.6, 2.5]
## Seconds a fade out (and the fade in after it) lasts.
const FADE_SECONDS: float = 0.35

## Remaining path per person id: Vector3 points in plan pixels x, y and the level in z.
var _paths: Dictionary[StringName, PackedVector3Array] = {}
var _fading: Dictionary[StringName, float] = {}
var _leaving: Dictionary[StringName, StaffToken] = {}


## Starts [param token] along [param path] (cell centres with levels, from PlanPaths). An
## empty path fades the token to its home instead.
func walk(token: StaffToken, path: PackedVector3Array) -> void:
	_fading.erase(token.person_id)
	if path.is_empty():
		_paths.erase(token.person_id)
		_fading[token.person_id] = 0.0
		return
	var pixels := PackedVector3Array()
	for point: Vector3 in path:
		pixels.append(
			Vector3(point.x * BasePlanPainter.CELL, point.y * BasePlanPainter.CELL, point.z)
		)
	pixels.append(Vector3(token.home.x, token.home.y, path[path.size() - 1].z))
	_paths[token.person_id] = pixels


## Walks [param token] out along [param path], then drops it.
func leave(token: StaffToken, path: PackedVector3Array) -> void:
	_leaving[token.person_id] = token
	if path.is_empty():
		_paths.erase(token.person_id)
		_fading[token.person_id] = 0.0
		return
	token.home = Vector2(path[path.size() - 1].x, path[path.size() - 1].y) * BasePlanPainter.CELL
	walk(token, path)


## True while [param person_id] walks or fades.
func is_moving(person_id: StringName) -> bool:
	return _paths.has(person_id) or _fading.has(person_id)


## The tokens walking out, still drawn.
func leaving() -> Array[StaffToken]:
	return _leaving.values()


## The opacity of [param person_id]'s token: 1 except while fading.
func alpha_of(person_id: StringName) -> float:
	if not _fading.has(person_id):
		return 1.0
	var t: float = _fading[person_id] / FADE_SECONDS
	return absf(1.0 - t)


## Puts every token at its home and drops every walk, fade and leaver.
func snap_all(tokens: Array[StaffToken]) -> void:
	for token: StaffToken in tokens:
		token.position = token.home
	_paths.clear()
	_fading.clear()
	_leaving.clear()


## Moves every walking token by [param delta] seconds at clock speed [param speed_index];
## nothing moves while [param paused]. Returns true when anything moved.
func step(
	tokens: Dictionary[StringName, StaffToken], delta: float, speed_index: int, paused: bool
) -> bool:
	if paused or (_paths.is_empty() and _fading.is_empty()):
		return false
	var factor: float = SPEED_FACTORS[clampi(speed_index, 0, SPEED_FACTORS.size() - 1)]
	var budget: float = CELLS_PER_SECOND * factor * BasePlanPainter.CELL * delta
	for id: StringName in _paths.keys():
		var token: StaffToken = tokens.get(id, _leaving.get(id))
		if token == null:
			_paths.erase(id)
			continue
		_advance(token, budget)
	_step_fades(tokens, delta)
	return true


func _advance(token: StaffToken, budget: float) -> void:
	var path: PackedVector3Array = _paths[token.person_id]
	var left: float = budget
	while left > 0.0 and not path.is_empty():
		var target := Vector2(path[0].x, path[0].y)
		token.level = int(path[0].z)
		var gap: float = token.position.distance_to(target)
		if gap <= left:
			token.position = target
			left -= gap
			path.remove_at(0)
		else:
			token.position = token.position.move_toward(target, left)
			left = 0.0
	if path.is_empty():
		_paths.erase(token.person_id)
		_leaving.erase(token.person_id)
	else:
		_paths[token.person_id] = path


func _step_fades(tokens: Dictionary[StringName, StaffToken], delta: float) -> void:
	for id: StringName in _fading.keys():
		var t: float = _fading[id] + delta
		var token: StaffToken = tokens.get(id, _leaving.get(id))
		if token != null and t >= FADE_SECONDS and _fading[id] < FADE_SECONDS:
			token.position = token.home
			if _leaving.has(id):
				_leaving.erase(id)
				_fading.erase(id)
				continue
		if t >= FADE_SECONDS * 2.0:
			_fading.erase(id)
		else:
			_fading[id] = t
