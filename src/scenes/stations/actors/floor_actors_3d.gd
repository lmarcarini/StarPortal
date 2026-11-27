class_name FloorActors3D
extends Node3D
## The Gate floor's people and props in 3D (M5-04): mirrors [FloorActors] (which keeps the
## cues, timing and who stands idle) with 3D figures and props on fixed paths built from the
## hall's markers: teams from the blast door up the ramp into the horizon and back, props
## up or down the ramp, intruders out of the horizon, staff at the consoles and the door, a
## walker across the floor. One figure scene ([constant FIGURE_SCENE]) to swap for real art.
## Bible: docs/content/interface-reference.md section 7

## The figure every person uses; replace this scene to change the character model.
const FIGURE_SCENE: PackedScene = preload("res://src/scenes/stations/actors/figure_3d.tscn")

var _floor: FloorActors = null
var _view: Station3D = null
var _figures: Array[Figure3D] = []
var _props: Dictionary[int, MeshInstance3D] = {}


## Follows [param floor] in [param view]'s hall.
func bind(floor: FloorActors, view: Station3D) -> void:
	_floor = floor
	_view = view


## Figures shown now.
func shown_figures() -> int:
	return _figures.filter(func(f: Figure3D) -> bool: return f.visible).size()


## The props shown now, by Props.Kind.
func shown_props() -> Array[int]:
	var out: Array[int] = []
	for kind: int in _props:
		if _props[kind].visible:
			out.append(kind)
	return out


func _process(_delta: float) -> void:
	refresh()


## Places every figure and prop for the floor's actors now.
func refresh() -> void:
	if _floor == null:
		return
	var sprites: bool = _view.get_root().has_node(^"TeamOnRamp")
	var people: Array[Actor] = []
	if not sprites:
		people = _floor.get_idle().duplicate()
	if _floor.get_crosser() != null:
		people.append(_floor.get_crosser())
	var props: Array[Actor] = []
	for actor: Actor in _floor.get_actors():
		if not actor.has_started() or (sprites and _is_team(actor)):
			continue
		(props if actor.figure < 0 else people).append(actor)
	_place_people(people)
	_place_props(props)


## Teams and the staff at posts are drawn by the hall's TeamOnRamp when it has one (M8-04).
static func _is_team(actor: Actor) -> bool:
	return actor.figure >= 0 and actor.route in [Actor.Route.OUT, Actor.Route.IN]


func _place_people(people: Array[Actor]) -> void:
	while _figures.size() < people.size():
		var figure: Figure3D = FIGURE_SCENE.instantiate() as Figure3D
		add_child(figure)
		_figures.append(figure)
	for i: int in _figures.size():
		var figure: Figure3D = _figures[i]
		figure.visible = i < people.size() and _alpha(people[i]) > 0.5
		if not figure.visible:
			continue
		var actor: Actor = people[i]
		figure.set_kind(actor.figure)
		_put(figure, actor)
		figure.set_pose(actor.elapsed, actor.route != Actor.Route.STAND and not actor.fade_only)


func _place_props(props: Array[Actor]) -> void:
	for mesh: MeshInstance3D in _props.values():
		mesh.visible = false
	for actor: Actor in props:
		if not _props.has(actor.prop):
			_props[actor.prop] = FloorPaths3D.prop_mesh(actor.prop)
			add_child(_props[actor.prop])
		var mesh: MeshInstance3D = _props[actor.prop]
		mesh.visible = _alpha(actor) > 0.5
		_put(mesh, actor)


func _put(node: Node3D, actor: Actor) -> void:
	var path: PackedVector3Array = FloorPaths3D.path_of(_view, actor.route, actor.spot)
	var t: float = 1.0 if actor.fade_only else actor.progress()
	var at: Vector3 = FloorPaths3D.along(path, t)
	var ahead: Vector3 = FloorPaths3D.along(path, minf(1.0, t + 0.02))
	if actor.route == Actor.Route.STAND and _floor.is_busy():
		at.x += signf(at.x) * 1.2
	node.position = at
	var dir: Vector3 = ahead - at
	dir.y = 0.0
	if dir.length() > 0.001:
		node.rotation.y = atan2(dir.x, dir.z)
	elif actor.route == Actor.Route.STAND:
		node.rotation.y = 0.0


func _alpha(actor: Actor) -> float:
	if actor.fade_only:
		return 1.0 - actor.progress()
	return 1.0


## Adds the 3D floor to [param station]'s hall for [param floor]; null when not 3D.
static func install(station: StationScene, floor: FloorActors) -> FloorActors3D:
	var view: Station3D = station.get_3d()
	if view == null or view.get_root() == null:
		return null
	var actors: FloorActors3D = FloorActors3D.new()
	actors.name = "FloorActors3D"
	view.get_root().add_child(actors)
	actors.bind(floor, view)
	return actors
