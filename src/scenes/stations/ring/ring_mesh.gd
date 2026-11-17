class_name RingMesh
extends RefCounted
## Builds the Ring's 3D mesh in code (M5-03), centred on the origin, facing +z: the thick
## band (an annulus with a front, back, inner and outer face), the game's own 36 glyphs
## engraved as raised strokes on its front face, and eight wedge clamps. Pure: returns
## ArrayMeshes, one surface each.
## Bible: docs/content/interface-reference.md sections 5 and 7

## Band radii and depth, in metres.
const R_IN: float = 2.9
const R_OUT: float = 3.7
const DEPTH: float = 0.7
## Segments round the band.
const SEGMENTS: int = 96
## Glyph stroke width and relief, in metres; glyph square side.
const STROKE: float = 0.035
const RELIEF: float = 0.025
const GLYPH_SIDE: float = 0.42
## Clamp size (radial, tangential, depth).
const CLAMP: Vector3 = Vector3(0.95, 0.75, 1.0)


## The band.
static func band() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = DEPTH * 0.5
	for i: int in SEGMENTS:
		var a0: float = TAU * i / SEGMENTS
		var a1: float = TAU * (i + 1) / SEGMENTS
		_quad(st, _p(R_IN, a0, half), _p(R_OUT, a0, half), _p(R_OUT, a1, half), _p(R_IN, a1, half))
		_quad(
			st, _p(R_OUT, a0, -half), _p(R_IN, a0, -half), _p(R_IN, a1, -half), _p(R_OUT, a1, -half)
		)
		_quad(
			st, _p(R_OUT, a0, half), _p(R_OUT, a0, -half), _p(R_OUT, a1, -half), _p(R_OUT, a1, half)
		)
		_quad(st, _p(R_IN, a0, -half), _p(R_IN, a0, half), _p(R_IN, a1, half), _p(R_IN, a1, -half))
	st.generate_normals()
	return st.commit()


## The 36 glyphs of [param glyphs] (GlyphDef by index) as raised strokes round the front face.
static func glyphs(glyphs: Array[GlyphDef]) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mid: float = (R_IN + R_OUT) * 0.5
	for i: int in glyphs.size():
		var angle: float = TAU * (i + 0.5) / glyphs.size()
		var basis: Basis = Basis(Vector3.BACK, -angle)
		var centre: Vector3 = _p(mid, angle, DEPTH * 0.5)
		_glyph(st, glyphs[i], Transform3D(basis, centre))
	st.generate_normals()
	return st.commit()


## The eight clamps, at 45 degree steps from the top.
static func clamps() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 8:
		var angle: float = TAU * i / 8.0
		var at: Vector3 = _p(R_OUT - 0.15, angle, 0.1)
		_box(st, Transform3D(Basis(Vector3.BACK, -angle), at), CLAMP)
	st.generate_normals()
	return st.commit()


## Where clamp [param i]'s lamp sits (in front of the clamp, mid band).
static func lamp_position(i: int) -> Vector3:
	return _p((R_IN + R_OUT) * 0.5 + 0.35, TAU * i / 8.0, DEPTH * 0.5 + 0.55)


static func _glyph(st: SurfaceTool, glyph: GlyphDef, at: Transform3D) -> void:
	if glyph == null:
		return
	for pair: int in range(0, glyph.lines.size() - 1, 2):
		var a: Vector2 = _glyph_point(glyph, glyph.lines[pair])
		var b: Vector2 = _glyph_point(glyph, glyph.lines[pair + 1])
		var length: float = a.distance_to(b)
		if length < 0.001:
			continue
		var mid: Vector2 = (a + b) * 0.5
		var turn: Basis = Basis(Vector3.BACK, (b - a).angle())
		var stroke: Transform3D = at * Transform3D(turn, Vector3(mid.x, mid.y, RELIEF * 0.5))
		_box(st, stroke, Vector3(length + STROKE, STROKE, RELIEF))


## Glyph point [param index] in metres, centred, y up.
static func _glyph_point(glyph: GlyphDef, index: int) -> Vector2:
	var p: Vector2 = glyph.points[index] - Vector2(0.5, 0.5)
	return Vector2(p.x, -p.y) * GLYPH_SIDE


## A point at radius [param r], angle [param a] clockwise from the top, depth [param z].
static func _p(r: float, a: float, z: float) -> Vector3:
	return Vector3(sin(a) * r, cos(a) * r, z)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v: Vector3 in [a, b, c, a, c, d]:
		st.add_vertex(v)


## A box of [param size] (x along, y across, z out) placed by [param at].
static func _box(st: SurfaceTool, at: Transform3D, size: Vector3) -> void:
	var h: Vector3 = size * 0.5
	var c: Array[Vector3] = []
	for k: int in 8:
		var sx: float = h.x if k & 1 else -h.x
		var sy: float = h.y if k & 2 else -h.y
		var sz: float = h.z if k & 4 else -h.z
		c.append(at * Vector3(sx, sy, sz))
	var faces: Array[PackedInt32Array] = [
		[4, 5, 7, 6], [1, 0, 2, 3], [5, 1, 3, 7], [0, 4, 6, 2], [6, 7, 3, 2], [0, 1, 5, 4]
	]
	for f: PackedInt32Array in faces:
		_quad(st, c[f[0]], c[f[1]], c[f[2]], c[f[3]])
