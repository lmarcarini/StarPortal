class_name GateRoomSet
extends RoomSet
## The Gate Room: the Ring standing on its ramp against the back wall.
## Bible: docs/content/interface-pass.md section 5 (Camera inset)

## The Ring.
var ring: MeshInstance3D = null


func _init() -> void:
	super()
	room_size = Vector2(12, 10)
	wall_height = 6.0


func _build_props(props: Node3D) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 2.0
	torus.outer_radius = 2.5
	torus.rings = 24
	torus.ring_segments = 8
	torus.material = SetKit.material(Color("#6b6f6a"))
	ring = MeshInstance3D.new()
	ring.mesh = torus
	ring.name = &"Ring"
	ring.position = Vector3(0, 2.8, -3.6)
	ring.rotation_degrees = Vector3(90, 0, 0)
	props.add_child(ring)
	props.add_child(SetKit.box(Vector3(2.4, 0.3, 3.0), Vector3(0, 0.15, -1.2), SetKit.METAL))
