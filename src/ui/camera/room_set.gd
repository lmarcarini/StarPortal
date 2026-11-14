@abstract class_name RoomSet
extends Node3D
## Base of a camera set: a small room built in code from SetKit primitives, one fixed camera
## and one light. Subclasses add their furniture in [method _build_props]. People are simple
## figures placed across the floor; the state switches between on (lit), off (dark) and site
## (scaffolding, no furniture). Inheritance stops here: a set extends this class.
## Bible: docs/content/interface-pass.md sections 1 and 5 (Camera inset)

## Set states.
const STATE_ON: StringName = &"on"
const STATE_OFF: StringName = &"off"
const STATE_SITE: StringName = &"site"

## Floor size in metres (x across, z in depth).
var room_size: Vector2 = Vector2(8, 6)
## Wall height in metres.
var wall_height: float = 3.0
## The fixed camera.
var camera := Camera3D.new()
## The one light.
var light := OmniLight3D.new()

var _state: StringName = STATE_ON
var _props := Node3D.new()
var _people := Node3D.new()
var _scaffolding: Node3D = null


func _init() -> void:
	_props.name = &"Props"
	_people.name = &"People"


func _ready() -> void:
	add_child(SetKit.floor_slab(room_size))
	add_child(SetKit.walls(room_size, wall_height))
	add_child(_props)
	add_child(_people)
	_build_props(_props)
	light.position = Vector3(0, wall_height - 0.3, 0)
	light.omni_range = room_size.length()
	light.light_energy = 2.0
	light.shadow_enabled = false
	add_child(light)
	camera.fov = 60.0
	add_child(camera)
	_place_camera(camera)
	_scaffolding = SetKit.scaffolding(room_size)
	add_child(_scaffolding)
	set_state(_state)


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	for part: Node in [_props, _people, camera, light]:
		if is_instance_valid(part) and part.get_parent() == null:
			part.free()


## Adds the set's furniture under [param props].
@abstract func _build_props(props: Node3D) -> void


## Places the fixed camera: high in the front corner, looking across the room.
func _place_camera(cam: Camera3D) -> void:
	var half := room_size / 2.0
	cam.position = Vector3(half.x * 0.85, wall_height * 0.85, half.y * 1.1)
	cam.look_at(Vector3(-half.x * 0.2, 0.6, -half.y * 0.3))


## Shows [param people] as figures on the floor.
func set_people(people: Array[FeedPerson]) -> void:
	for child: Node in _people.get_children():
		_people.remove_child(child)
		child.queue_free()
	var half := room_size / 2.0
	for person: FeedPerson in people:
		var figure: Node3D = SetKit.figure(person.role)
		var spot: Vector2 = person.position.clamp(Vector2.ZERO, Vector2.ONE)
		figure.position = Vector3(
			lerpf(-half.x * 0.8, half.x * 0.8, spot.x),
			0,
			lerpf(-half.y * 0.8, half.y * 0.8, spot.y)
		)
		_people.add_child(figure)


## The number of figures shown.
func people_count() -> int:
	return _people.get_child_count()


## Shows the room on, off (dark) or as a site (scaffolding, no furniture or people).
func set_state(state: StringName) -> void:
	_state = state
	if not is_node_ready():
		return
	light.visible = state != STATE_OFF
	_props.visible = state != STATE_SITE
	_people.visible = state != STATE_SITE
	_scaffolding.visible = state == STATE_SITE


## The state shown.
func get_state() -> StringName:
	return _state
