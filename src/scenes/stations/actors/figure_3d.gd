class_name Figure3D
extends Node3D
## A low-poly mannequin for the 3D Gate hall (M5-04): capsule body, sphere head, box limbs,
## coloured by kind (soldier olive drab with a pack, scientist off-white coat, intruder dark
## red), with a walk bob and arm and leg swing. A character model can replace it later by
## changing figure_3d.tscn (the scene [FloorActors3D] instances), keeping [method set_kind]
## and [method set_pose].
## Bible: docs/content/interface-reference.md section 7

## Body colours by FigureSprite.Kind.
const COLOURS: Array[Color] = [
	Color(0.25, 0.29, 0.19), Color(0.72, 0.7, 0.64), Color(0.33, 0.12, 0.1)
]
const SKIN: Color = Color(0.62, 0.46, 0.35)
## Height in metres.
const HEIGHT: float = 1.8

var _body: StandardMaterial3D = StandardMaterial3D.new()
var _limbs: Dictionary[String, Node3D] = {}
var _pack: MeshInstance3D = null


func _init() -> void:
	var skin: StandardMaterial3D = StandardMaterial3D.new()
	skin.albedo_color = SKIN
	_body.roughness = 0.8
	_part("Torso", _capsule(0.2, 0.75), Vector3(0, 1.15, 0), _body, self)
	_part("Head", _sphere(0.12), Vector3(0, 1.66, 0), skin, self)
	for side: float in [-1.0, 1.0]:
		var key: String = "L" if side < 0 else "R"
		_limbs["arm" + key] = _limb(Vector3(side * 0.26, 1.42, 0), Vector3(0.09, 0.62, 0.09))
		_limbs["leg" + key] = _limb(Vector3(side * 0.1, 0.86, 0), Vector3(0.12, 0.84, 0.12))
	_pack = _part("Pack", _box(Vector3(0.32, 0.4, 0.16)), Vector3(0, 1.2, -0.2), _body, self)


## Colours the figure as [param kind] (a FigureSprite.Kind).
func set_kind(kind: int) -> void:
	_body.albedo_color = COLOURS[clampi(kind, 0, COLOURS.size() - 1)]
	_pack.visible = kind == FigureSprite.Kind.SOLDIER


## Poses the figure: walk [param phase] seconds in when [param walking], else standing.
func set_pose(phase: float, walking: bool) -> void:
	var swing: float = sin(phase * 7.0) * 0.6 if walking else 0.0
	_limbs["armL"].rotation.x = swing
	_limbs["armR"].rotation.x = -swing
	_limbs["legL"].rotation.x = -swing * 0.8
	_limbs["legR"].rotation.x = swing * 0.8
	position.y = absf(sin(phase * 7.0)) * 0.04 if walking else 0.0


func _limb(pivot: Vector3, size: Vector3) -> Node3D:
	var hinge: Node3D = Node3D.new()
	hinge.position = pivot
	add_child(hinge)
	_part("Limb", _box(size), Vector3(0, -size.y * 0.5, 0), _body, hinge)
	return hinge


static func _part(
	n: String, mesh: Mesh, at: Vector3, m: Material, parent: Node3D
) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = n
	part.mesh = mesh
	part.position = at
	part.material_override = m
	parent.add_child(part)
	return part


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 3
	return mesh


static func _sphere(radius: float) -> SphereMesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	return mesh


static func _box(size: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return mesh
