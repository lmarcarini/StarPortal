class_name SetKit
extends RefCounted
## Builders for the camera sets: floor, walls, door, desk, console, scaffolding and figures,
## all from primitive meshes in flat colours. No imported models or textures.
## Bible: docs/content/interface-pass.md sections 1 and 5

const CONCRETE: Color = Color("#5a605c")
const WALL: Color = Color("#3d4441")
const METAL: Color = Color("#6f7671")
const DESK: Color = Color("#4a4136")
const SCREEN: Color = Color("#7fd68a")
const SCAFFOLD: Color = Color("#c9a24a")
## Figure colours by role.
const ROLE_COLOURS: Dictionary[StringName, Color] = {
	&"scientist": Color("#d8d6cc"),
	&"engineer": Color("#c98a3a"),
	&"analyst": Color("#7d8fa3"),
	&"soldier": Color("#55654a"),
	&"medic": Color("#c9c9c9"),
	&"intruder": Color("#e5533d"),
}


## A flat-coloured material; [param glow] makes it unshaded (screens, lamps).
static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var made := StandardMaterial3D.new()
	made.albedo_color = color
	made.roughness = 0.9
	if glow:
		made.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return made


## A box of [param size] centred at [param at].
static func box(size: Vector3, at: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material(color, glow)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	return node


## The floor of a [param size] room (x across, z in depth), its top at y = 0.
static func floor_slab(size: Vector2) -> MeshInstance3D:
	return box(Vector3(size.x, 0.1, size.y), Vector3(0, -0.05, 0), CONCRETE)


## The back and side walls of a [param size] room, [param height] high, with a door gap in
## the left wall.
static func walls(size: Vector2, height: float) -> Node3D:
	var root := Node3D.new()
	root.name = &"Walls"
	var half := size / 2.0
	root.add_child(box(Vector3(size.x, height, 0.15), Vector3(0, height / 2, -half.y), WALL))
	root.add_child(box(Vector3(0.15, height, size.y), Vector3(half.x, height / 2, 0), WALL))
	var side: float = (size.y - 1.2) / 2.0
	root.add_child(
		box(Vector3(0.15, height, side), Vector3(-half.x, height / 2, -half.y + side / 2), WALL)
	)
	root.add_child(
		box(Vector3(0.15, height, side), Vector3(-half.x, height / 2, half.y - side / 2), WALL)
	)
	root.add_child(door(Vector3(-half.x, 0, 0)))
	return root


## A door frame at [param at] in a wall along z.
static func door(at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = &"Door"
	root.position = at
	root.add_child(box(Vector3(0.2, 0.2, 1.2), Vector3(0, 2.1, 0), METAL))
	return root


## A desk with a screen at [param at].
static func desk(at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.add_child(box(Vector3(1.4, 0.75, 0.7), Vector3(0, 0.375, 0), DESK))
	root.add_child(box(Vector3(0.6, 0.4, 0.05), Vector3(0, 0.98, -0.2), SCREEN, true))
	return root


## A wall console with lit screens at [param at].
static func console(at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.add_child(box(Vector3(2.0, 1.1, 0.6), Vector3(0, 0.55, 0), METAL))
	for index: int in 3:
		var x: float = -0.6 + index * 0.6
		root.add_child(box(Vector3(0.45, 0.3, 0.05), Vector3(x, 1.3, -0.1), SCREEN, true))
	return root


## Scaffolding over a [param size] floor: poles and planks.
static func scaffolding(size: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = &"Scaffolding"
	for x: float in [-size.x / 3.0, 0.0, size.x / 3.0]:
		for z: float in [-size.y / 3.0, size.y / 3.0]:
			root.add_child(box(Vector3(0.08, 2.6, 0.08), Vector3(x, 1.3, z), SCAFFOLD))
	for y: float in [1.0, 2.0]:
		root.add_child(box(Vector3(size.x * 0.75, 0.06, 0.5), Vector3(0, y, 0), SCAFFOLD))
	return root


## A simple standing figure of [param role]: a body and a head, its shape by role as on the
## plan's tokens (scientist round, engineer square, analyst narrow).
static func figure(role: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = &"Figure"
	var colour: Color = ROLE_COLOURS.get(role, Color("#b0b0a8"))
	var body := CylinderMesh.new()
	body.height = 1.1
	body.top_radius = 0.18
	body.bottom_radius = 0.22
	body.radial_segments = (
		4 if role == &"engineer" else (3 if role in [&"analyst", &"intruder"] else 8)
	)
	body.material = material(colour)
	var body_node := MeshInstance3D.new()
	body_node.mesh = body
	body_node.position = Vector3(0, 0.55, 0)
	root.add_child(body_node)
	var head := SphereMesh.new()
	head.radius = 0.13
	head.height = 0.26
	head.radial_segments = 8
	head.rings = 4
	head.material = material(Color("#d9b99b"))
	var head_node := MeshInstance3D.new()
	head_node.mesh = head
	head_node.position = Vector3(0, 1.28, 0)
	root.add_child(head_node)
	return root
