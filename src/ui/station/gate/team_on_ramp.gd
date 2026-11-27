class_name TeamOnRamp
extends Node3D
## The Gate hall's people as 2D-HD billboards ([StaffSprite3D], one per person): while the
## mission sheet is open the team being planned stands on the ramp (markers ramp_slot_*),
## facing the Ring; on GO (team_sent) it walks up into the event horizon and vanishes there.
## A returning team (team_returned) steps out of the horizon and walks down the ramp to the
## blast door, the injured slower. Staff on base stand at the posts the hall has a marker
## for (post_*): scientists working at the console banks, soldiers at the door and on the
## catwalks. Sheets are built lazily (StaffSprite3D's queue): only the ramp team, walkers and
## the few people at posts, never the whole roster. Lives in gate_hall.tscn; finds the
## mission sheet through the view above the hall's Station3D.
## Bible: docs/content/interface-reference.md section 7; docs/content/portraits.md

## Walking speed, metres per second; the injured walk at INJURED_SHARE of it.
const SPEED: float = 1.3
const INJURED_SHARE: float = 0.55
## Seconds between two team members setting off.
const STAGGER: float = 0.7
## Seconds the ramp team waits after the sheet closes for team_sent before leaving.
const GRACE: float = 1.5
## Seconds between two reads of who stands at the posts.
const POST_SECONDS: float = 2.0
## Post marker to the role that stands there, and the pose and facing used.
const POSTS: Dictionary[StringName, Array] = {
	&"post_console_left": [&"role_scientist", "work", "back"],
	&"post_console_right": [&"role_scientist", "work", "back"],
	&"post_blast_door": [&"role_soldier", "idle", "front"],
	&"post_catwalk_left": [&"role_soldier", "idle", "front"],
	&"post_catwalk_right": [&"role_soldier", "idle", "front"],
}
## Ramp slots and how far behind the ramp top (towards the Ring) the horizon is.
const SLOTS: int = 4
const HORIZON_DEPTH: float = 1.3


## One person walking a path: on reaching the end the sprite hides.
class Walk:
	extends RefCounted
	var path: PackedVector3Array = PackedVector3Array()
	var travelled: float = 0.0
	var delay: float = 0.0
	var speed: float = SPEED


var _sprites: Dictionary[StringName, StaffSprite3D] = {}
var _walks: Dictionary[StringName, Walk] = {}
var _ramp: Array[StringName] = []
var _posts: Dictionary[StringName, StringName] = {}
## Members of the last team sent or back who have no sprite (no appearance record): the
## floor keeps mannequins for them.
var _unshown: int = 0
var _grace: float = 0.0
var _post_in: float = 0.0
## The mission sheet (a MissionSheet; untyped so the hall loads without the UI scripts).
var _sheet: Control = null
var _camera: Camera3D = null


## The autoloads are looked up by path: this script is loaded with the hall scene by tools
## that run without autoloads (the content validator).
func _enter_tree() -> void:
	var bus: Node = get_node_or_null(^"/root/EventBus")
	if bus != null:
		bus.connect(&"team_sent", _on_team_sent)
		bus.connect(&"team_returned", _on_team_returned)


func _exit_tree() -> void:
	var bus: Node = get_node_or_null(^"/root/EventBus")
	if bus != null and bus.is_connected(&"team_sent", _on_team_sent):
		bus.disconnect(&"team_sent", _on_team_sent)
		bus.disconnect(&"team_returned", _on_team_returned)


func _ready() -> void:
	_camera = get_viewport().get_camera_3d()
	var view: Node = get_viewport().get_parent()
	while view != null and not view.has_method(&"get_mission_sheet"):
		view = view.get_parent()
	if view != null:
		var found: Object = view.call(&"get_mission_sheet")
		_sheet = found as Control


## The sprite of [param id], or null.
func sprite_of(id: StringName) -> StaffSprite3D:
	return _sprites.get(id, null)


## The ids standing on the ramp now.
func ramp_team() -> Array[StringName]:
	return _ramp


## Members of the team walking now who have no sprite (FloorActors3D draws them).
func unshown() -> int:
	return _unshown


## True when someone stands at post [param spot] (a post_* marker name).
func covers_post(spot: StringName) -> bool:
	return _posts.has(spot)


## The ids walking now.
func walkers() -> Array[StringName]:
	return _walks.keys()


## Post marker to the id standing there.
func posts() -> Dictionary[StringName, StringName]:
	return _posts


## Stands [param ids] on the ramp (empty clears it); people already walking are left alone.
## Without the mission sheet open the ramp clears after GRACE seconds (GO without team_sent).
func show_ramp_team(ids: Array[StringName]) -> void:
	if ids == _ramp:
		return
	var old: Array[StringName] = _ramp
	_ramp = ids.duplicate()
	_grace = GRACE
	for id: StringName in old:
		if not id in _ramp:
			_hide(id)
	for i: int in _ramp.size():
		var sprite: StaffSprite3D = _sprite_for(_ramp[i])
		if sprite == null:
			continue
		_release_post(_ramp[i])
		sprite.position = slot(i)
		sprite.set_pose("idle", "back")
		sprite.set_wanted(true)


## Sends [param ids] up the ramp into the horizon (from their slots, else the ramp foot);
## returns how many have a sprite (the rest have no appearance record).
func send(ids: Array[StringName]) -> int:
	var ramp: PackedVector3Array = _ramp_path()
	var shown: int = 0
	for i: int in ids.size():
		var sprite: StaffSprite3D = _sprite_for(ids[i])
		if sprite == null:
			continue
		shown += 1
		_release_post(ids[i])
		var from: Vector3 = sprite.position if ids[i] in _ramp else ramp[1]
		var top: Vector3 = ramp[0] + Vector3(from.x, 0.0, 0.0)
		_start(ids[i], PackedVector3Array([from, top, top + Vector3(0, 0, -HORIZON_DEPTH)]), i)
	_ramp.clear()
	return shown


## Brings [param ids] out of the horizon and down the ramp to the blast door; the people in
## [param injured] walk slower. Returns how many have a sprite.
func bring_back(ids: Array[StringName], injured: Array[StringName]) -> int:
	var ramp: PackedVector3Array = _ramp_path()
	var door: Vector3 = _marker_at(&"door_left", Vector3(-13.6, 0, 1.3))
	var shown: int = 0
	for i: int in ids.size():
		if _sprite_for(ids[i]) == null:
			continue
		shown += 1
		_release_post(ids[i])
		var side: Vector3 = Vector3((i % 2 - 0.5) * 0.6, 0, 0)
		var path := PackedVector3Array(
			[ramp[0] + side + Vector3(0, 0, -HORIZON_DEPTH), ramp[0] + side, ramp[1] + side, door]
		)
		var walk: Walk = _start(ids[i], path, i)
		if ids[i] in injured:
			walk.speed = SPEED * INJURED_SHARE
			_sprites[ids[i]].speed_scale = INJURED_SHARE
	return shown


## Moves the walkers on by [param delta] seconds and keeps the ramp and posts in step.
func advance(delta: float) -> void:
	_follow_sheet(delta)
	for id: StringName in _walks.keys():
		_step(id, _walks[id], delta)
	_post_in -= delta
	if _post_in <= 0.0:
		_post_in = POST_SECONDS
		_forget_gone(_state())
		refresh_posts(_state())


## Frees the sprites of people no longer on the roster (died, left).
func _forget_gone(state: GameState) -> void:
	if state == null:
		return
	var roster: Array[StringName] = []
	for person: PersonState in state.staff.people:
		roster.append(person.id)
	for id: StringName in _sprites.keys():
		if id in roster:
			continue
		_walks.erase(id)
		_ramp.erase(id)
		_release_post(id)
		_sprites[id].queue_free()
		_sprites.erase(id)


## Puts staff on base (not away, not on the ramp, not walking) at the posts of [param state].
func refresh_posts(state: GameState) -> void:
	var people: Dictionary[StringName, StringName] = RampCrew.post_crew(state, _busy(), POSTS)
	for spot: StringName in _posts:
		if people.get(spot, &"") != _posts[spot]:
			_hide(_posts[spot])
	_posts = people
	for spot: StringName in _posts:
		var sprite: StaffSprite3D = _sprite_for(_posts[spot])
		var node: Node3D = get_parent().find_child(String(spot), true, false) as Node3D
		if sprite == null or node == null:
			continue
		sprite.position = to_local(node.global_position)
		var look: Array = POSTS[spot]
		sprite.set_pose(str(look[1]), str(look[2]))
		sprite.set_wanted(true)


## Where ramp slot [param index] is (marker ramp_slot_<index>, else spaced on the ramp).
func slot(index: int) -> Vector3:
	var ramp: PackedVector3Array = _ramp_path()
	var fallback: Vector3 = ramp[0].lerp(ramp[1], 0.3 + 0.18 * index)
	return _marker_at(StringName("ramp_slot_%d" % index), fallback)


func _process(delta: float) -> void:
	advance(delta)


func _follow_sheet(delta: float) -> void:
	var draft: Object = _sheet.call(&"get_draft") if _sheet != null else null
	if _sheet != null and _sheet.is_visible_in_tree() and draft != null:
		if not _sheet.call(&"is_order"):
			var team: Dictionary = draft.get(&"team")
			var ids: Array[StringName] = []
			ids.assign(team.values())
			show_ramp_team(ids.slice(0, SLOTS))
			_grace = GRACE
			return
	_grace -= delta
	if _grace <= 0.0 and not _ramp.is_empty():
		show_ramp_team([])


func _start(id: StringName, path: PackedVector3Array, order: int) -> Walk:
	var walk := Walk.new()
	walk.path = path
	walk.delay = STAGGER * order
	_walks[id] = walk
	var sprite: StaffSprite3D = _sprites[id]
	sprite.speed_scale = 1.0
	sprite.position = path[0]
	sprite.set_wanted(not _from_horizon(path))
	return walk


func _step(id: StringName, walk: Walk, delta: float) -> void:
	var sprite: StaffSprite3D = _sprites[id]
	if walk.delay > 0.0:
		walk.delay -= delta
		return
	walk.travelled += walk.speed * delta
	var at: Vector3 = RampCrew.along(walk.path, walk.travelled)
	var motion: Vector3 = at - sprite.position
	sprite.position = at
	sprite.face_motion(motion, _camera)
	sprite.set_wanted(walk.travelled > HORIZON_DEPTH or not _from_horizon(walk.path))
	if walk.travelled >= RampCrew.length(walk.path):
		_walks.erase(id)
		_hide(id)


func _from_horizon(path: PackedVector3Array) -> bool:
	return path.size() > 3


func _on_team_sent(_world: StringName, _objective: int, team: Array, _blind: bool) -> void:
	var ids: Array[StringName] = _ids_of(team)
	if ids.is_empty():
		ids = _ramp.duplicate()
	_unshown = maxi(0, team.size() - send(ids))


func _on_team_returned(_world: StringName, _objective: int, _success: bool, team: Array) -> void:
	var ids: Array[StringName] = _ids_of(team)
	var injured: Array[StringName] = []
	var state: GameState = _state()
	for person: PersonState in state.staff.people if state != null else []:
		if person.id in ids and person.is_injured():
			injured.append(person.id)
	_unshown = maxi(0, team.size() - bring_back(ids, injured))


## Ids of the people named in [param team] (events carry names), in that order.
func _ids_of(team: Array) -> Array[StringName]:
	var ids: Array[StringName] = []
	var state: GameState = _state()
	if state == null:
		return ids
	for entry: Variant in team:
		for person: PersonState in state.staff.people:
			if person.name == str(entry) or person.id == StringName(str(entry)):
				ids.append(person.id)
				break
	return ids


func _sprite_for(id: StringName) -> StaffSprite3D:
	var record: Dictionary = _record_of(id)
	if record.is_empty():
		return null
	if not _sprites.has(id):
		var sprite := StaffSprite3D.new()
		sprite.name = "Staff_%s" % id
		add_child(sprite)
		_sprites[id] = sprite
	_sprites[id].show_person(id, record)
	return _sprites[id]


func _record_of(id: StringName) -> Dictionary:
	var state: GameState = _state()
	if state == null:
		return {}
	for person: PersonState in state.staff.people:
		if person.id == id:
			return person.appearance
	return {}


func _hide(id: StringName) -> void:
	if _sprites.has(id) and not _walks.has(id) and not id in _ramp:
		_sprites[id].set_wanted(false)


func _release_post(id: StringName) -> void:
	for spot: StringName in _posts.keys():
		if _posts[spot] == id:
			_posts.erase(spot)


func _busy() -> Array[StringName]:
	var busy: Array[StringName] = _ramp.duplicate()
	for id: StringName in _walks:
		busy.append(id)
	return busy


func _ramp_path() -> PackedVector3Array:
	var path: Path3D = get_parent().find_child("ramp", true, false) as Path3D
	if path == null or path.curve == null or path.curve.point_count < 2:
		return PackedVector3Array([Vector3(0, 0.9, 1.1), Vector3(0, 0, 8.1)])
	var out := PackedVector3Array()
	for i: int in path.curve.point_count:
		out.append(to_local(path.global_transform * path.curve.get_point_position(i)))
	return out


func _marker_at(marker_name: StringName, fallback: Vector3) -> Vector3:
	var node: Node3D = get_parent().find_child(String(marker_name), true, false) as Node3D
	return to_local(node.global_position) if node != null else fallback


func _state() -> GameState:
	var clock: Node = get_node_or_null(^"/root/SimClock")
	var simulation: Object = clock.get(&"simulation") if clock != null else null
	var state: Object = simulation.get(&"state") if simulation != null else null
	return state as GameState
