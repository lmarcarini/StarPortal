class_name BodyPartsHead
extends RefCounted
## The head of the full-body sprite: neck, head, face (eyes, nose, mouth, facial hair), hair
## style and accessory (glasses, eye patch), in the portrait's skin and hair ramps, from the
## front, back and right side. Small enough that only the shape of each style shows.
## Bible: docs/content/portraits.md ("The appearance record")

const CX: int = BodyPainter.CX
## Head half-width (15 px across).
const RX: int = 7
const EYE_WHITE := Color8(232, 228, 220)
const FRAME := Color8(30, 30, 34)


## The neck, under the collar.
static func draw_neck(c: BodyPainter) -> void:
	var sy: int = BodyParts.shoulder_y(c)
	var x: int = CX + (1 if c.direction == "side" else 0)
	c.shaded(BodyPainter.rect(x - 3, sy - 6, x + 3, sy + 1), c.skin, 1)


## Head, face, hair and accessory.
static func draw(c: BodyPainter) -> void:
	var cy: int = head_y(c)
	var x: int = CX + (1 if c.direction == "side" else 0)
	c.shaded(BodyPainter.ellipse(x, cy, RX, 9), c.skin, 2)
	match c.direction:
		"front":
			_face_front(c, cy)
		"side":
			_face_side(c, cy)
	_hair(c, cy)
	_accessory(c, cy)


## Row of the eyes (head centre) this frame.
static func head_y(c: BodyPainter) -> int:
	return 15 + c.up


static func _face_front(c: BodyPainter, cy: int) -> void:
	var brow: Color = c.hair[PortraitRamp.OUTLINE]
	for s: int in [-1, 1]:
		c.hline(CX + s * 2, CX + s * 4, cy - 2, brow)
		c.dot(CX + s * 3, cy, BodyPainter.INK)
		c.dot(CX + s * 4, cy, EYE_WHITE)
	c.vline(CX, cy + 1, cy + 3, c.skin[PortraitRamp.SHADOW])
	c.hline(CX - 2, CX + 2, cy + 5, c.skin[PortraitRamp.OUTLINE])
	_facial_hair(c, cy, CX - RX + 1, CX + RX - 1)


static func _face_side(c: BodyPainter, cy: int) -> void:
	c.hline(CX + 4, CX + 6, cy - 2, c.hair[PortraitRamp.OUTLINE])
	c.dot(CX + 5, cy, BodyPainter.INK)
	c.dot(CX + 9, cy + 1, c.skin[PortraitRamp.MID])
	c.dot(CX + 9, cy + 2, c.skin[PortraitRamp.SHADOW])
	c.dot(CX + 9, cy, c.skin[PortraitRamp.OUTLINE])
	c.dot(CX + 10, cy + 2, c.skin[PortraitRamp.OUTLINE])
	c.hline(CX + 6, CX + 7, cy + 5, c.skin[PortraitRamp.OUTLINE])
	_facial_hair(c, cy, CX + 1, CX + 8)


## Beard, moustache or stubble as a block on the lower face between [param x0] and [param x1].
static func _facial_hair(c: BodyPainter, cy: int, x0: int, x1: int) -> void:
	var kind: String = c.trait_of("facial_hair")
	if kind == "moustache":
		c.hline(x1 - 7, x1 - 2, cy + 4, c.hair[PortraitRamp.SHADOW])
		c.hline(x1 - 6, x1 - 3, cy + 3, c.hair[PortraitRamp.MID])
		return
	if kind != "beard" and kind != "stubble":
		return
	var colour: Color = c.hair[PortraitRamp.SHADOW]
	if kind == "stubble":
		colour = c.skin[PortraitRamp.OUTLINE].lerp(c.skin[PortraitRamp.SHADOW], 0.6)
	for y: int in range(cy + 3, cy + 10):
		var inset: int = maxi(0, y - cy - 6)
		c.hline(x0 + inset, x1 - inset, y, colour)
	c.hline(x1 - 7, x1 - 3, cy + 5, c.skin[PortraitRamp.OUTLINE])


## The hair style's shape for this direction, shaded in the hair ramp.
static func _hair(c: BodyPainter, cy: int) -> void:
	var style: String = c.trait_of("hair")
	if style == "bald":
		return
	var shape: PackedByteArray
	match c.direction:
		"front":
			shape = _hair_front(style, cy)
		"back":
			shape = _hair_back(style, cy)
		_:
			shape = _hair_side(style, cy)
	c.shaded(shape, c.hair, 1)


static func _above(shape: PackedByteArray, row: int) -> PackedByteArray:
	return BodyPainter.minus(shape, BodyPainter.rect(0, row, BodyPainter.W, BodyPainter.H))


static func _hair_front(style: String, cy: int) -> PackedByteArray:
	var crown: PackedByteArray = BodyPainter.ellipse(CX, cy - 2, RX + 1, 8)
	match style:
		"military", "buzz":
			return _above(crown, cy - 4)
		"receding":
			var top: PackedByteArray = _above(crown, cy - 6)
			for s: int in [-1, 1]:
				top = BodyPainter.union(
					top, BodyPainter.rect(CX + s * RX - 1, cy - 7, CX + s * RX + 1, cy - 1)
				)
			return top
	var cap: PackedByteArray = _above(crown, cy - 3)
	for s: int in [-1, 1]:
		cap = BodyPainter.union(cap, BodyPainter.rect(CX + s * RX - 1, cy - 4, CX + s * RX + 1, cy))
	match style:
		"messy":
			cap = BodyPainter.union(cap, BodyPainter.ellipse(CX, cy - 8, RX + 2, 4))
		"curly":
			var puff: PackedByteArray = _above(BodyPainter.ellipse(CX, cy - 4, RX + 3, 8), cy + 2)
			cap = BodyPainter.minus(BodyPainter.union(cap, puff), _face(cy))
		"side":
			cap = BodyPainter.union(cap, BodyPainter.ellipse(CX - 2, cy - 4, RX - 1, 2))
		"bun":
			cap = BodyPainter.union(cap, BodyPainter.ellipse(CX, cy - 11, 4, 3))
		"long":
			for s: int in [-1, 1]:
				var x: int = CX + s * (RX + 1)
				cap = BodyPainter.union(cap, BodyPainter.rect(x - 2, cy - 4, x + 1, cy + 15))
	return cap


## The face below the hairline, kept clear of hair.
static func _face(cy: int) -> PackedByteArray:
	return BodyPainter.rect(CX - RX + 2, cy - 3, CX + RX - 2, BodyPainter.H)


static func _hair_back(style: String, cy: int) -> PackedByteArray:
	var nape: int = cy + (3 if style in ["military", "buzz"] else 5)
	var back: PackedByteArray = _above(BodyPainter.ellipse(CX, cy - 1, RX + 1, 9), nape)
	match style:
		"messy":
			back = BodyPainter.union(back, BodyPainter.ellipse(CX, cy - 8, RX + 2, 4))
		"curly":
			back = BodyPainter.union(
				back, _above(BodyPainter.ellipse(CX, cy - 3, RX + 3, 9), cy + 5)
			)
		"bun":
			back = BodyPainter.union(back, BodyPainter.ellipse(CX, cy - 6, 4, 3))
		"ponytail":
			back = BodyPainter.union(back, BodyPainter.rect(CX - 2, cy, CX + 2, cy + 17))
		"long":
			back = BodyPainter.union(back, BodyPainter.rect(CX - RX - 2, cy, CX + RX + 2, cy + 16))
	return back


static func _hair_side(style: String, cy: int) -> PackedByteArray:
	var short: bool = style in ["military", "buzz"]
	var line: int = cy - (6 if style == "receding" else 3)
	var face: PackedByteArray = BodyPainter.rect(CX + 2, line, BodyPainter.W, BodyPainter.H)
	var mass: PackedByteArray = BodyPainter.ellipse(CX, cy - 1, RX + 1, 9)
	mass = _above(BodyPainter.minus(mass, face), cy + (3 if short else 5))
	match style:
		"messy":
			mass = BodyPainter.union(mass, BodyPainter.ellipse(CX - 1, cy - 8, RX + 2, 4))
		"curly":
			var puff: PackedByteArray = _above(
				BodyPainter.ellipse(CX - 1, cy - 3, RX + 3, 9), cy + 5
			)
			mass = BodyPainter.union(mass, BodyPainter.minus(puff, face))
		"bun":
			mass = BodyPainter.union(mass, BodyPainter.ellipse(CX - 7, cy - 4, 3, 3))
		"ponytail":
			mass = BodyPainter.union(mass, BodyPainter.rect(CX - RX - 3, cy - 2, CX - RX, cy + 14))
		"long":
			mass = BodyPainter.union(mass, BodyPainter.rect(CX - RX - 1, cy, CX, cy + 15))
	return mass


static func _accessory(c: BodyPainter, cy: int) -> void:
	match c.trait_of("accessory"):
		"glasses":
			_glasses(c, cy)
		"patch":
			var eye: int = CX + (5 if c.direction == "side" else 3)
			if c.direction != "back":
				c.fill(BodyPainter.rect(eye - 1, cy - 1, eye + 1, cy + 1), BodyPainter.INK)
			var strap_x: int = CX + (6 if c.direction == "side" else RX)
			c.hline(CX - RX, strap_x, cy - 3, BodyPainter.INK)


static func _glasses(c: BodyPainter, cy: int) -> void:
	if c.direction == "back":
		for s: int in [-1, 1]:
			c.dot(CX + s * RX, cy, FRAME)
		return
	var eyes: Array[int] = [CX - 3, CX + 3]
	if c.direction == "side":
		eyes = [CX + 5]
	for x: int in eyes:
		for p: Vector2i in [Vector2i(-2, -1), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]:
			c.dot(x + p.x, cy + p.y, FRAME)
			c.dot(x + p.x, cy + 1, FRAME)
		c.dot(x - 2, cy, FRAME)
		c.dot(x + 2, cy, FRAME)
	if c.direction == "side":
		c.hline(CX, CX + 3, cy - 1, FRAME)
	else:
		c.hline(CX - 1, CX + 1, cy - 1, FRAME)
