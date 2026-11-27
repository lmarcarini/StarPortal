class_name BodyPartsHead
extends RefCounted
## The head of the full-body sprite: neck, head, face (eyes, nose, mouth, facial hair), hair
## style and accessory (glasses, eye patch), in the portrait's skin and hair ramps, from the
## front, back and right side. Small enough that only the shape of each style shows.
## Bible: docs/content/portraits.md ("The appearance record")

const CX: int = BodyPainter.CX


## The neck, under the collar.
static func draw_neck(c: BodyPainter) -> void:
	var sy: int = BodyParts.shoulder_y(c)
	var x: int = CX + (1 if c.direction == "side" else 0)
	c.shaded(BodyPainter.rect(x - 3, sy - 7, x + 3, sy + 1), c.skin, 1)


## Head, face, hair and accessory.
static func draw(c: BodyPainter) -> void:
	var cy: int = head_y(c)
	var side: bool = c.direction == "side"
	var rx: int = 6 if c.female else 7
	var x: int = CX + (1 if side else 0)
	c.shaded(BodyPainter.ellipse(x, cy, rx, 9), c.skin, 2)
	match c.direction:
		"front":
			_face_front(c, cy)
		"side":
			_face_side(c, cy)
	_hair(c, cy, rx)
	_accessory(c, cy)


## Row of the eyes (head centre) this frame.
static func head_y(c: BodyPainter) -> int:
	return 17 + c.up


static func _face_front(c: BodyPainter, cy: int) -> void:
	c.dot(CX - 3, cy, BodyPainter.INK)
	c.dot(CX + 3, cy, BodyPainter.INK)
	c.dot(CX, cy + 3, c.skin[PortraitRamp.SHADOW])
	c.hline(CX - 1, CX + 1, cy + 5, c.skin[PortraitRamp.OUTLINE])
	_facial_hair(c, cy, CX - 4, CX + 4)


static func _face_side(c: BodyPainter, cy: int) -> void:
	c.dot(CX + 5, cy, BodyPainter.INK)
	c.dot(CX + 8, cy + 2, c.skin[PortraitRamp.MID])
	c.dot(CX + 8, cy + 3, c.skin[PortraitRamp.OUTLINE])
	c.hline(CX + 5, CX + 6, cy + 5, c.skin[PortraitRamp.OUTLINE])
	_facial_hair(c, cy, CX + 1, CX + 7)


static func _facial_hair(c: BodyPainter, cy: int, x0: int, x1: int) -> void:
	match c.trait_of("facial_hair"):
		"beard":
			for y: int in range(cy + 4, cy + 9):
				var inset: int = maxi(0, y - cy - 6)
				c.hline(x0 + inset, x1 - inset, y, c.hair[PortraitRamp.SHADOW])
			c.hline(x1 - 5, x1 - 3, cy + 5, c.skin[PortraitRamp.OUTLINE])
		"moustache":
			c.hline(x1 - 6, x1 - 2, cy + 4, c.hair[PortraitRamp.SHADOW])
		"stubble":
			for y: int in range(cy + 5, cy + 8):
				for x: int in range(x0 + (y % 2), x1 + 1, 2):
					c.dot(x, y, c.skin[PortraitRamp.SHADOW])


## The hair style's shape for this direction, shaded in the hair ramp.
static func _hair(c: BodyPainter, cy: int, rx: int) -> void:
	var style: String = c.trait_of("hair")
	if style == "bald":
		return
	var shape: PackedByteArray
	match c.direction:
		"front":
			shape = _hair_front(style, cy, rx)
		"back":
			shape = _hair_back(style, cy, rx)
		_:
			shape = _hair_side(style, cy, rx)
	c.shaded(shape, c.hair, 1)


static func _cap(cy: int, rx: int, short: bool) -> PackedByteArray:
	var cap: PackedByteArray = BodyPainter.ellipse(CX, cy - 3, rx + 1, 8)
	var top_rows: int = cy - (4 if short else 3)
	cap = BodyPainter.minus(cap, BodyPainter.rect(0, top_rows, BodyPainter.W, BodyPainter.H))
	if short:
		return cap
	for s: int in [-1, 1]:
		var x: int = CX + s * rx
		cap = BodyPainter.union(cap, BodyPainter.rect(x - 1, cy - 4, x + 1, cy))
	return cap


static func _hair_front(style: String, cy: int, rx: int) -> PackedByteArray:
	var short: bool = style in ["military", "buzz"]
	var cap: PackedByteArray = _cap(cy, rx, short)
	match style:
		"messy":
			cap = BodyPainter.union(cap, BodyPainter.ellipse(CX, cy - 8, rx + 2, 4))
		"curly":
			cap = BodyPainter.union(cap, BodyPainter.ellipse(CX, cy - 6, rx + 3, 6))
		"side":
			cap = BodyPainter.union(cap, BodyPainter.ellipse(CX - 2, cy - 5, rx, 3))
		"receding":
			cap = BodyPainter.minus(cap, BodyPainter.ellipse(CX, cy - 10, 3, 3))
		"bun":
			cap = BodyPainter.union(cap, BodyPainter.ellipse(CX, cy - 11, 4, 3))
		"long":
			var drape: PackedByteArray = BodyPainter.rect(CX - rx - 2, cy - 5, CX + rx + 2, cy + 13)
			drape = BodyPainter.minus(
				drape, BodyPainter.rect(CX - rx + 2, cy - 3, CX + rx - 2, cy + 14)
			)
			cap = BodyPainter.union(cap, drape)
	return cap


static func _hair_back(style: String, cy: int, rx: int) -> PackedByteArray:
	var nape: int = cy + (4 if style in ["military", "buzz", "receding"] else 6)
	var back: PackedByteArray = BodyPainter.minus(
		BodyPainter.ellipse(CX, cy - 1, rx + 1, 9),
		BodyPainter.rect(0, nape, BodyPainter.W, BodyPainter.H)
	)
	match style:
		"messy", "curly":
			back = BodyPainter.union(back, BodyPainter.ellipse(CX, cy - 7, rx + 2, 5))
		"bun":
			back = BodyPainter.union(back, BodyPainter.ellipse(CX, cy - 6, 4, 3))
		"ponytail":
			back = BodyPainter.union(back, BodyPainter.rect(CX - 2, cy, CX + 2, cy + 17))
		"long":
			back = BodyPainter.union(back, BodyPainter.rect(CX - rx - 1, cy, CX + rx + 1, cy + 17))
	return back


static func _hair_side(style: String, cy: int, rx: int) -> PackedByteArray:
	var short: bool = style in ["military", "buzz", "receding"]
	var head: PackedByteArray = BodyPainter.ellipse(CX, cy - 1, rx + 1, 9)
	var face: PackedByteArray = BodyPainter.rect(
		CX + 1, cy - (4 if style == "receding" else 5), BodyPainter.W, BodyPainter.H
	)
	var shape: PackedByteArray = BodyPainter.minus(head, face)
	shape = BodyPainter.minus(
		shape, BodyPainter.rect(0, cy + (4 if short else 6), BodyPainter.W, BodyPainter.H)
	)
	match style:
		"messy", "curly":
			shape = BodyPainter.union(shape, BodyPainter.ellipse(CX - 1, cy - 7, rx + 2, 5))
		"bun":
			shape = BodyPainter.union(shape, BodyPainter.ellipse(CX - 6, cy - 5, 3, 3))
		"ponytail":
			shape = BodyPainter.union(
				shape, BodyPainter.rect(CX - rx - 3, cy - 2, CX - rx, cy + 14)
			)
		"long":
			shape = BodyPainter.union(shape, BodyPainter.rect(CX - rx - 1, cy, CX - 1, cy + 15))
	return shape


static func _accessory(c: BodyPainter, cy: int) -> void:
	match c.trait_of("accessory"):
		"glasses":
			if c.direction == "front":
				c.hline(CX - 5, CX + 5, cy, Color8(30, 30, 34))
				c.dot(CX - 3, cy - 1, Color8(150, 170, 185))
				c.dot(CX + 3, cy - 1, Color8(150, 170, 185))
			elif c.direction == "side":
				c.hline(CX - 1, CX + 7, cy, Color8(30, 30, 34))
		"patch":
			if c.direction == "front":
				c.hline(CX - 5, CX + 5, cy - 2, BodyPainter.INK)
				c.hline(CX + 2, CX + 4, cy, BodyPainter.INK)
				c.hline(CX + 2, CX + 4, cy + 1, BodyPainter.INK)
			else:
				c.hline(CX - 6, CX + 7, cy - 2, BodyPainter.INK)
