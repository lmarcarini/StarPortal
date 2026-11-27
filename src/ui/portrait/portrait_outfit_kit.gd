class_name PortraitOutfitKit
extends RefCounted
## The garment pieces the uniforms are built from: torso with rounded shoulders, arm
## creases, necklines, collar, tie, lapels, zipper, pockets, epaulettes, patches and straps.
## Ported from the prototype (tools/portraits/pixel_portraits.py); the torso is new: the
## prototype's shoulders read as a flat slab, so here they are taller domes, lit along their
## top curve and shadowed round their outer side.
## Bible: docs/content/portraits.md ("Known gaps in the prototype")

const CX: int = PortraitCanvas.CX
const S: int = PortraitCanvas.SIZE
## Shoulder dome radii and the row of their centres.
const SHOULDER_RX: int = 21
const SHOULDER_RY: int = 17
const SHOULDER_Y: int = 83


## The torso mask; men's shoulders are 3 px broader each side.
static func torso(canvas: PortraitCanvas) -> PortraitMask:
	var wide: int = 0 if canvas.female else 3
	var points: Array[Vector2i] = [
		Vector2i(0, 96),
		Vector2i(2, 84),
		Vector2i(14 - wide, 70),
		Vector2i(82 + wide, 70),
		Vector2i(94, 84),
		Vector2i(96, 96)
	]
	var body: PortraitMask = PortraitMask.poly(points)
	for s: int in [-1, 1]:
		var centre: int = CX + s * (26 + wide)
		body = body.union(PortraitMask.ellipse(centre, SHOULDER_Y, SHOULDER_RX, SHOULDER_RY))
	return body.intersect(PortraitMask.band(64, S))


## Paints [param mask] (the torso) in [param shades] with rounded shoulders and arm creases.
static func body(canvas: PortraitCanvas, mask: PortraitMask, shades: Array[Color]) -> void:
	canvas.shaded(mask, shades, 4)
	var wide: int = 0 if canvas.female else 3
	for s: int in [-1, 1]:
		var centre: int = CX + s * (26 + wide)
		_shoulder_curve(
			canvas, mask, centre, shades[PortraitRamp.LIGHT if s < 0 else PortraitRamp.MID]
		)
		_crease(canvas, centre - s * 6, s, shades[PortraitRamp.SHADOW])


## A skin V neckline [param depth] deep.
static func vneck(canvas: PortraitCanvas, depth: int = 14) -> void:
	var points: Array[Vector2i] = [
		Vector2i(CX - 9, 64), Vector2i(CX, 64 + depth), Vector2i(CX + 9, 64)
	]
	canvas.shaded(PortraitMask.poly(points), canvas.skin, 2)


## A shirt V of [param colour] (desaturated), [param depth] deep and [param w] half-wide.
static func shirt_v(canvas: PortraitCanvas, colour: String, depth: int = 22, w: int = 10) -> void:
	var points: Array[Vector2i] = [
		Vector2i(CX - w, 64), Vector2i(CX, 64 + depth), Vector2i(CX + w, 64)
	]
	canvas.shaded(PortraitMask.poly(points), PortraitRamp.ramp(colour, 0.6), 2)


## A tie from row [param top] down.
static func tie(canvas: PortraitCanvas, colour: String, top: int = 68) -> void:
	var shades: Array[Color] = PortraitRamp.ramp(colour)
	var points: Array[Vector2i] = [
		Vector2i(CX - 2, top), Vector2i(CX + 2, top), Vector2i(CX + 3, 96), Vector2i(CX - 3, 96)
	]
	canvas.shaded(PortraitMask.poly(points), shades, 1)
	canvas.hline(CX - 2, CX + 2, top + 2, shades[0])


## Jacket lapels from row [param top].
static func lapels(canvas: PortraitCanvas, colour: String, top: int = 64) -> void:
	for s: int in [-1, 1]:
		var points: Array[Vector2i] = [
			Vector2i(CX + s * 10, top),
			Vector2i(CX + s * 3, top + 14),
			Vector2i(CX + s * 9, 96),
			Vector2i(CX + s * 16, 96),
			Vector2i(CX + s * 15, top + 2),
		]
		canvas.shaded(PortraitMask.poly(points), PortraitRamp.ramp(colour), 2)


## A stand collar round the neck.
static func stand_collar(canvas: PortraitCanvas, colour: String) -> void:
	var points: Array[Vector2i] = [
		Vector2i(CX - 12, 60), Vector2i(CX + 12, 60), Vector2i(CX + 14, 69), Vector2i(CX - 14, 69)
	]
	canvas.shaded(PortraitMask.poly(points), PortraitRamp.ramp(colour), 2)


## A centre zipper from row [param top].
static func zipper(canvas: PortraitCanvas, colour: String, top: int = 70) -> void:
	var dark: Color = PortraitRamp.ramp(colour)[0]
	for y: int in range(top, S):
		canvas.dot(CX, y, dark)


## Two chest pockets at row [param y].
static func pockets(canvas: PortraitCanvas, colour: String, y: int = 82) -> void:
	var shades: Array[Color] = PortraitRamp.ramp(colour)
	for s: int in [-1, 1]:
		var x: int = CX + s * 21
		canvas.shaded(PortraitMask.rect(x - 6, y, x + 6, y + 9), shades, 1)
		canvas.hline(x - 6, x + 6, y + 2, shades[1])


## Shoulder boards, with three pips of [param pip] when given.
static func epaulettes(canvas: PortraitCanvas, colour: String, pip: String = "") -> void:
	for s: int in [-1, 1]:
		var x: int = CX + s * 31
		canvas.shaded(PortraitMask.rect(x - 7, 68, x + 7, 71), PortraitRamp.ramp(colour), 1)
		if not pip.is_empty():
			for k: int in [-3, 0, 3]:
				canvas.dot(x + k, 69, PortraitRamp.ramp(pip)[3])


## A square patch at ([param x], [param y]).
static func patch(canvas: PortraitCanvas, colour: String, x: int = 8, y: int = 82) -> void:
	canvas.shaded(PortraitMask.rect(x, y, x + 7, y + 7), PortraitRamp.ramp(colour), 1)


## Two vertical straps (overalls, webbing).
static func straps(canvas: PortraitCanvas, colour: String) -> void:
	for s: int in [-1, 1]:
		var x: int = CX + s * 17
		canvas.shaded(PortraitMask.rect(x - 3, 68, x + 3, 96), PortraitRamp.ramp(colour), 1)


## A round skin neckline (T-shirt).
static func crew_neck(canvas: PortraitCanvas, edge: Color) -> void:
	var neck: PortraitMask = PortraitMask.ellipse(CX, 64, 11, 6).intersect(PortraitMask.band(62, S))
	canvas.shaded(neck, canvas.skin, 1)
	canvas.hline(CX - 11, CX + 11, 66, edge)


## A lit (or mid) arc two pixels inside the top of the shoulder dome at [param centre].
static func _shoulder_curve(
	canvas: PortraitCanvas, mask: PortraitMask, centre: int, colour: Color
) -> void:
	for dx: int in range(-SHOULDER_RX + 5, SHOULDER_RX - 4):
		var t: float = 1.0 - pow(dx / float(SHOULDER_RX - 2), 2.0)
		if t <= 0.0:
			continue
		var y: int = roundi(SHOULDER_Y - (SHOULDER_RY - 2) * sqrt(t)) + 1
		if mask.has(centre + dx, y) and mask.has(centre + dx, y - 2):
			canvas.dot(centre + dx, y, colour)


## A curved arm crease near [param x] bending outward ([param s]) as it goes down.
static func _crease(canvas: PortraitCanvas, x: int, s: int, colour: Color) -> void:
	for k: int in 12:
		canvas.dot(x + s * (k * k / 40), 83 + k, colour)
