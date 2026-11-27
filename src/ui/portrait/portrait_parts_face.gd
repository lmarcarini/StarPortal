class_name PortraitPartsFace
extends RefCounted
## The face layer of a portrait: neck, ears, head shape and jaw, eyes and brows, nose, mouth,
## age lines, facial hair and the accessory (glasses, eye patch, scar). Ported from the
## prototype (tools/portraits/pixel_portraits.py); shapes follow the record's "head", "jaw",
## "eyes", "brows", "nose", "mouth", "facial_hair", "age" and "accessory".
## Bible: docs/content/portraits.md ("The appearance record")

const CX: int = PortraitCanvas.CX
const CY: int = PortraitCanvas.CY
## Eye-white tones and the lip colour of women.
const EYE_WHITE := Color8(214, 206, 196)
const EYE_WHITE_LOW := Color8(196, 188, 178)
const LIP: String = "#a8524a"
const FRAME := Color8(30, 30, 34)
const GLINT := Color8(190, 200, 210)
const STRAP := Color8(24, 24, 28)


## The head mask: a rounded top and a jaw shaped by the record's "jaw" and "head".
static func head_mask(canvas: PortraitCanvas) -> PortraitMask:
	var w: int = canvas.face_w
	var h: int = canvas.face_h
	var jaw: String = canvas.trait_of("jaw")
	var top: PortraitMask = PortraitMask.ellipse(CX, CY - 2, w, h - 2)
	var jaw_w: int = {"narrow": w - 7, "broad": w - 2, "angular": w - 4}.get(jaw, w - 4)
	var chin_w: int = {"narrow": 3, "broad": 6, "angular": 5}.get(jaw, 5)
	var drop: int = 9 if jaw == "angular" else 6
	if canvas.trait_of("head") == "round":
		drop += 2
	var points: Array[Vector2i] = [
		Vector2i(CX - w, CY),
		Vector2i(CX + w, CY),
		Vector2i(CX + jaw_w, CY + h - drop),
		Vector2i(CX + chin_w, CY + h),
		Vector2i(CX - chin_w, CY + h),
		Vector2i(CX - jaw_w, CY + h - drop),
	]
	return top.union(PortraitMask.poly(points))


## Paints the neck, shaded from the left with the jaw's shadow under the chin.
static func draw_neck(canvas: PortraitCanvas) -> void:
	canvas.shaded_side(PortraitMask.rect(CX - 8, CY + 14, CX + 8, 70), canvas.skin, 4, 0.45)
	canvas.fill(PortraitMask.rect(CX - 8, CY + 14, CX + 8, CY + 19), canvas.skin[1])


## Paints the ears and the head; returns the head mask.
static func draw_head(canvas: PortraitCanvas) -> PortraitMask:
	var w: int = canvas.face_w
	for s: int in [-1, 1]:
		canvas.shaded(PortraitMask.ellipse(CX + s * (w + 1), CY + 2, 3, 5), canvas.skin, 1)
	var head: PortraitMask = head_mask(canvas)
	canvas.shaded_side(head, canvas.skin, 3, 0.18)
	if canvas.trait_of("jaw") == "angular":
		for y: int in range(CY + 6, CY + 11):
			canvas.dot(CX + w - 5 - (y - CY - 6) / 2, y, canvas.skin[1])
	return head


## Paints eyes, brows, nose, mouth, age lines and facial hair inside [param head].
static func draw_face(canvas: PortraitCanvas, head: PortraitMask) -> void:
	var eye_y: int = CY + 1
	_draw_eyes(canvas, eye_y)
	var nose_y: int = _draw_nose(canvas, eye_y)
	var mouth_y: int = nose_y + 4
	_draw_mouth(canvas, mouth_y)
	var age: String = canvas.trait_of("age")
	if age != "young":
		for s: int in [-1, 1]:
			for k: int in 3:
				canvas.dot(CX + s * (5 + k / 2), nose_y + k, canvas.skin[1])
	if age == "older":
		canvas.hline(CX - 5, CX + 5, eye_y - 9, canvas.skin[1])
		canvas.hline(CX - 3, CX + 3, eye_y - 11, canvas.skin[1])
		for s: int in [-1, 1]:
			canvas.dot(CX + s * 11, eye_y + 1, canvas.skin[1])
			canvas.dot(CX + s * 11, eye_y + 2, canvas.skin[1])
	_draw_facial_hair(canvas, head, mouth_y)


## Paints the record's accessory over the face.
static func draw_accessory(canvas: PortraitCanvas) -> void:
	var eye_y: int = CY + 1
	match canvas.trait_of("accessory"):
		"glasses":
			for s: int in [-1, 1]:
				var ex: int = CX + s * 7
				canvas.hline(ex - 4, ex + 4, eye_y - 3, FRAME)
				canvas.hline(ex - 4, ex + 4, eye_y + 3, FRAME)
				for y: int in range(eye_y - 3, eye_y + 4):
					canvas.dot(ex - 4, y, FRAME)
					canvas.dot(ex + 4, y, FRAME)
				canvas.dot(ex - 2, eye_y - 2, GLINT)
			canvas.hline(CX - 3, CX + 3, eye_y - 2, FRAME)
		"patch":
			canvas.shaded(
				PortraitMask.ellipse(CX - 7, eye_y, 4, 4), PortraitRamp.ramp("#24242a"), 1
			)
			for i: int in range(-16, 17):
				canvas.dot(CX + i, eye_y - 6 - absi(i) / 6 + floori(i / 3.0), STRAP)
		"scar":
			for i: int in 7:
				canvas.dot(CX + 9 + i / 2, eye_y + 3 + i, canvas.skin[4])
				canvas.dot(CX + 10 + i / 2, eye_y + 3 + i, canvas.skin[1])


static func _draw_eyes(canvas: PortraitCanvas, eye_y: int) -> void:
	var kind: String = canvas.trait_of("eyes")
	var gap: int = 7 if canvas.face_w >= 18 else 6
	var half: int = 3 if kind == "round" else 2
	var skin: Array[Color] = canvas.skin
	for s: int in [-1, 1]:
		var ex: int = CX + s * gap
		canvas.hline(ex - half - 1, ex + half, eye_y - 1, skin[0])
		canvas.hline(ex - half, ex + half, eye_y, EYE_WHITE)
		canvas.dot(ex, eye_y, canvas.eye[0])
		canvas.dot(ex + s, eye_y, canvas.eye[2])
		if kind == "round":
			canvas.hline(ex - half, ex + half, eye_y + 1, EYE_WHITE_LOW)
			canvas.dot(ex, eye_y + 1, canvas.eye[1])
			canvas.dot(ex - half - 1, eye_y + 1, skin[1])
		if kind == "narrow":
			canvas.hline(ex - half, ex + half, eye_y, skin[1])
			canvas.dot(ex, eye_y, canvas.eye[0])
			canvas.dot(ex + s, eye_y, canvas.eye[0])
		canvas.hline(ex - half, ex + half, eye_y + (2 if kind == "round" else 1), skin[1])
		_draw_brow(canvas, ex, eye_y - 4, s)


static func _draw_brow(canvas: PortraitCanvas, ex: int, brow_y: int, s: int) -> void:
	var kind: String = canvas.trait_of("brows")
	for i: int in range(-3, 4):
		var dy: int = 0
		if kind == "angled":
			dy = floori(i * s / 2.0) if i * s > 0 else 0
			dy = -dy + (1 if i * s < -1 else 0)
		canvas.dot(ex + i, brow_y + dy, canvas.hair[0])
		if kind == "thick":
			canvas.dot(ex + i, brow_y - 1, canvas.hair[1])
		elif kind != "angled" and absi(i) < 3:
			canvas.dot(ex + i, brow_y - 1, canvas.hair[2])


static func _draw_nose(canvas: PortraitCanvas, eye_y: int) -> int:
	var kind: String = canvas.trait_of("nose")
	var skin: Array[Color] = canvas.skin
	var length: int = {"short": 6, "long": 9, "wide": 7}.get(kind, 7)
	for y: int in range(eye_y + 2, eye_y + 2 + length):
		canvas.dot(CX + 2, y, skin[1])
	canvas.dot(CX - 1, eye_y + length - 1, skin[3])
	var base_y: int = eye_y + 2 + length
	var half: int = 3 if kind == "wide" else 2
	canvas.hline(CX - half, CX + half, base_y, skin[1])
	canvas.dot(CX - half + 1, base_y, skin[0])
	canvas.dot(CX + half - 1, base_y, skin[0])
	if kind == "wide":
		canvas.dot(CX - half - 1, base_y - 1, skin[1])
		canvas.dot(CX + half + 1, base_y - 1, skin[1])
	return base_y


static func _draw_mouth(canvas: PortraitCanvas, mouth_y: int) -> void:
	var kind: String = canvas.trait_of("mouth")
	var skin: Array[Color] = canvas.skin
	var lip: Array[Color] = PortraitRamp.ramp(LIP) if canvas.female else skin
	var half: int = {"thin": 3, "wide": 5, "neutral": 4}.get(kind, 4)
	canvas.hline(CX - half, CX + half, mouth_y, skin[0])
	if kind != "thin":
		var lower: Color = lip[2] if canvas.female else skin[1]
		canvas.hline(CX - half + 1, CX + half - 1, mouth_y + 1, lower)
	else:
		canvas.hline(CX - 2, CX + 2, mouth_y + 1, skin[1])
	if canvas.female:
		canvas.hline(CX - half + 1, CX + half - 1, mouth_y - 1, lip[1])
	canvas.hline(CX - 2, CX + 2, mouth_y + 3, skin[1])


static func _draw_facial_hair(canvas: PortraitCanvas, head: PortraitMask, mouth_y: int) -> void:
	var kind: String = canvas.trait_of("facial_hair")
	if kind == "stubble":
		var reach: int = canvas.face_w - 2
		for y: int in range(mouth_y - 4, PortraitCanvas.SIZE):
			for x: int in range(CX - reach + 1, CX + reach):
				if head.has(x, y) and canvas.rng.randf() < 0.28:
					canvas.darken(x, y, 0.8)
	if kind == "moustache" or kind == "beard":
		canvas.shaded(PortraitMask.rect(CX - 5, mouth_y - 3, CX + 5, mouth_y - 1), canvas.hair, 1)
	if kind == "beard":
		var chin: PortraitMask = head.intersect(PortraitMask.band(mouth_y - 1, PortraitCanvas.SIZE))
		canvas.shaded(
			chin.minus(PortraitMask.rect(CX - 3, mouth_y, CX + 3, mouth_y + 2)), canvas.hair, 2
		)
		canvas.hline(CX - 3, CX + 3, mouth_y + 1, canvas.skin[1])
