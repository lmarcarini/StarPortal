class_name FloorPaths3D
extends RefCounted
## The fixed 3D paths of the Gate floor, from the hall's markers (Marker3D door_left,
## blast_door, console_left, console_right, horizon; Path3D ramp, crossing): the team's walk
## from the blast door up the ramp into the horizon, the ramp alone, the crossing and the idle
## spots. Also the low-poly props. Pure, apart from reading the markers.
## Bible: docs/content/interface-reference.md section 7

## Prop sizes and colours by Props.Kind (MOTH, CANISTER, CAMERA_ARM, CRATE).
const PROP_SIZES: Dictionary[int, Vector3] = {
	Props.Kind.MOTH: Vector3(0.9, 0.2, 0.6),
	Props.Kind.CANISTER: Vector3(0.4, 0.6, 0.4),
	Props.Kind.CAMERA_ARM: Vector3(0.15, 0.15, 2.2),
	Props.Kind.CRATE: Vector3(0.8, 0.6, 0.6),
}


## The world path of [param route] (for STAND, the spot [param spot]).
static func path_of(view: Station3D, route: Actor.Route, spot: StringName) -> PackedVector3Array:
	var ramp: PackedVector3Array = _ramp(view)
	var door: Vector3 = _at(view, &"door_left", Vector3(-13, 0, 2))
	var hole: Vector3 = _at(view, &"horizon", ramp[0] + Vector3(0, 0, -1.4))
	match route:
		Actor.Route.OUT:
			return PackedVector3Array([door, ramp[1], ramp[0], hole])
		Actor.Route.IN:
			return PackedVector3Array([hole, ramp[0], ramp[1], door])
		Actor.Route.RAMP_UP:
			return PackedVector3Array([ramp[1], ramp[0], hole])
		Actor.Route.RAMP_DOWN:
			return PackedVector3Array([hole, ramp[0], ramp[1]])
		Actor.Route.CROSS:
			return _points(view.marker(&"crossing") as Path3D, [door, ramp[1]])
	var spot_name: StringName = &"door_left" if spot == &"blast_door" else spot
	var stand: Vector3 = _at(view, spot_name, door)
	if spot == &"blast_door":
		stand += Vector3(1.6, 0, 0.4)
	stand.y = 0.0
	return PackedVector3Array([stand + Vector3(0, 0, 0.9)])


## The point [param t] (0 to 1) along [param path] by length.
static func along(path: PackedVector3Array, t: float) -> Vector3:
	if path.size() < 2:
		return path[0] if not path.is_empty() else Vector3.ZERO
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	var want: float = clampf(t, 0.0, 1.0) * total
	for i: int in range(1, path.size()):
		var seg: float = path[i - 1].distance_to(path[i])
		if want <= seg and seg > 0.0:
			return path[i - 1].lerp(path[i], want / seg)
		want -= seg
	return path[path.size() - 1]


## A low-poly prop for [param kind] (a Props.Kind).
static func prop_mesh(kind: int) -> MeshInstance3D:
	var box: BoxMesh = BoxMesh.new()
	box.size = PROP_SIZES.get(kind, Vector3.ONE * 0.5)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var crate: bool = kind == Props.Kind.CRATE
	material.albedo_color = Color(0.3, 0.33, 0.22) if crate else Color(0.5, 0.48, 0.42)
	material.metallic = 0.4
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "Prop%d" % kind
	mesh.mesh = box
	mesh.material_override = material
	return mesh


static func _ramp(view: Station3D) -> PackedVector3Array:
	var path: PackedVector3Array = _points(view.marker(&"ramp") as Path3D, [])
	if path.size() < 2:
		return PackedVector3Array([Vector3(0, 0.9, 1.1), Vector3(0, 0, 8.1)])
	return path


static func _points(path: Path3D, fallback: Array[Vector3]) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array(fallback)
	if path == null or path.curve == null:
		return out
	out.clear()
	for i: int in path.curve.point_count:
		out.append(path.global_transform * path.curve.get_point_position(i))
	return out


static func _at(view: Station3D, marker_name: StringName, fallback: Vector3) -> Vector3:
	var node: Node3D = view.marker(marker_name)
	return node.global_position if node != null else fallback
