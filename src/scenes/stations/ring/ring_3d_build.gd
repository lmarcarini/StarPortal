class_name Ring3DBuild
extends RefCounted
## The parts of [Ring3D], built once: the band, glyphs and clamps with their materials, the
## eight seal lamps, the horizon disc and the Shutter's iris blades.
## Bible: docs/content/interface-reference.md sections 5 and 7

## Lamp materials: lit amber (glowing), dark glass.
static var lamp_on: StandardMaterial3D = _lamp(true)
static var lamp_off: StandardMaterial3D = _lamp(false)


## Adds the band, the glyph strokes and the clamps to [param ring].
static func body(ring: Node3D) -> void:
	var stone: StandardMaterial3D = StandardMaterial3D.new()
	stone.albedo_color = Color(0.36, 0.35, 0.32)
	stone.roughness = 0.75
	stone.metallic = 0.25
	var carved: StandardMaterial3D = stone.duplicate() as StandardMaterial3D
	carved.albedo_color = Color(0.5, 0.48, 0.43)
	var steel: StandardMaterial3D = StandardMaterial3D.new()
	steel.albedo_color = Color(0.22, 0.22, 0.21)
	steel.metallic = 0.4
	steel.roughness = 0.45
	var defs: Array[GlyphDef] = []
	for i: int in GateAddress.GLYPH_COUNT:
		defs.append(Registry.get_def(StringName(GlyphIcon.GLYPH_ID_FORMAT % i)) as GlyphDef)
	var parts: Dictionary[String, Array] = {
		"Band": [RingMesh.band(), stone],
		"Glyphs": [RingMesh.glyphs(defs), carved],
		"Clamps": [RingMesh.clamps(), steel],
	}
	for part: String in parts:
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.name = part
		mesh.mesh = parts[part][0]
		mesh.material_override = parts[part][1]
		ring.add_child(mesh)


## Adds the eight seal lamps to [param ring]; returns them in seal order.
static func lamps(ring: Node3D) -> Array[MeshInstance3D]:
	var bulb: SphereMesh = SphereMesh.new()
	bulb.radius = 0.16
	bulb.height = 0.32
	var out: Array[MeshInstance3D] = []
	for i: int in 8:
		var lamp: MeshInstance3D = MeshInstance3D.new()
		lamp.name = "SealLamp%d" % i
		lamp.mesh = bulb
		lamp.position = RingMesh.lamp_position(i)
		lamp.material_override = lamp_off
		ring.add_child(lamp)
		out.append(lamp)
	return out


## A flat unit disc facing +z, UV 0..1, with rings for the surge to bend.
static func disc() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: int = 16
	var spokes: int = 64
	for r: int in rings:
		for s: int in spokes:
			var pts: Array[Vector2] = []
			for corner: Vector2i in [
				Vector2i(r, s), Vector2i(r + 1, s), Vector2i(r + 1, s + 1), Vector2i(r, s + 1)
			]:
				var a: float = TAU * corner.y / spokes
				pts.append(Vector2(sin(a), cos(a)) * float(corner.x) / rings)
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.set_uv(pts[k] * 0.5 + Vector2(0.5, 0.5))
				st.add_vertex(Vector3(pts[k].x, pts[k].y, 0))
	return st.commit()


## Adds [param count] iris blades round the hole to [param ring]; returns their pivots.
static func iris(ring: Node3D, count: int) -> Array[Node3D]:
	var blade: BoxMesh = BoxMesh.new()
	blade.size = Vector3(RingMesh.R_IN * 1.25, RingMesh.R_IN * 0.95, 0.05)
	var steel: StandardMaterial3D = StandardMaterial3D.new()
	steel.albedo_color = Color(0.28, 0.28, 0.27)
	steel.metallic = 0.5
	steel.roughness = 0.4
	var out: Array[Node3D] = []
	for i: int in count:
		var pivot: Node3D = Node3D.new()
		pivot.name = "IrisBlade%d" % i
		pivot.rotation.z = TAU * i / count
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.mesh = blade
		mesh.material_override = steel
		pivot.add_child(mesh)
		pivot.visible = false
		ring.add_child(pivot)
		out.append(pivot)
	return out


## Closes the iris [param blades] to [param amount] (0 open, 1 closed): each blade slides in
## from beyond the rim toward the centre.
static func set_iris(blades: Array[Node3D], amount: float) -> void:
	for i: int in blades.size():
		var pivot: Node3D = blades[i]
		pivot.set_meta(&"amount", amount)
		pivot.visible = amount > 0.0
		var mesh: Node3D = pivot.get_child(0) as Node3D
		var out: float = lerpf(RingMesh.R_IN * 1.6, RingMesh.R_IN * 0.45, amount)
		mesh.position = Vector3(0, out, 0.25 + 0.01 * i)
		mesh.rotation.z = lerpf(0.0, 0.35, amount)


## Whether the failure flash is on now for [param ring].
static func flash_on(ring: RingLayer) -> bool:
	return ring.is_flashing_failure() and int(Time.get_ticks_msec() / 100) % 2 == 0


static func _lamp(on: bool) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.7, 0.28) if on else Color(0.16, 0.12, 0.07)
	m.roughness = 0.2
	if on:
		m.emission_enabled = true
		m.emission = Color(1.0, 0.62, 0.22)
		m.emission_energy_multiplier = 0.6
	return m
