class_name PortraitPartsHair
extends RefCounted
## The hair layers of a portrait: the back layer (long hair, ponytail, a woman's curly
## volume) painted before the body, and the front cap over the head. Ported from the
## prototype (tools/portraits/pixel_portraits.py), with its known gap fixed: the cap gets an
## irregular silhouette (tufts and notches along the top) and strand clusters instead of
## reading like a cap. Tufts, notches and strands come from the canvas's seeded generator.
## Bible: docs/content/portraits.md ("Known gaps in the prototype")

const CX: int = PortraitCanvas.CX
const CY: int = PortraitCanvas.CY
## Styles with no silhouette noise (too short or none).
const SMOOTH_STYLES: Array[String] = ["buzz", "bald", "military"]
## Strand clusters drawn on a cap.
const CLUSTERS: int = 5


## Paints the hair that sits behind the head and shoulders.
static func draw_back(canvas: PortraitCanvas) -> void:
	var w: int = canvas.face_w
	var h: int = canvas.face_h
	match canvas.trait_of("hair"):
		"long":
			var points: Array[Vector2i] = [
				Vector2i(CX - w - 4, CY - 8),
				Vector2i(CX + w + 4, CY - 8),
				Vector2i(CX + w + 6, CY + h + 14),
				Vector2i(CX - w - 6, CY + h + 14),
			]
			canvas.shaded(_ragged_bottom(canvas, PortraitMask.poly(points)), canvas.hair)
		"ponytail":
			canvas.shaded(PortraitMask.ellipse(CX + w + 3, CY + 6, 5, 13), canvas.hair)
		"curly":
			if canvas.female:
				var volume: PortraitMask = PortraitMask.ellipse(CX, CY + 4, w + 8, h + 4)
				canvas.shaded(volume.intersect(PortraitMask.band(0, CY + 15)), canvas.hair)


## Paints the hair over the head ([param head] is the head mask).
static func draw_front(canvas: PortraitCanvas, head: PortraitMask) -> void:
	var style: String = canvas.trait_of("hair")
	if style == "bald":
		return
	var cap: PortraitMask = cap_mask(canvas)
	var shades: Array[Color] = canvas.hair
	if style == "buzz":
		var stubble: Array[Color] = [shades[0], shades[1], shades[1], shades[2], shades[2]]
		canvas.shaded(cap.intersect(head), stubble, 2, false)
		return
	if style not in SMOOTH_STYLES:
		cap = _ragged_top(canvas, cap)
	canvas.shaded(cap, shades, 3)
	if style == "bun":
		canvas.shaded(PortraitMask.ellipse(CX, CY - canvas.face_h - 3, 7, 5), shades)
	_draw_strands(canvas, cap)


## The front cap of the record's hair style, before any silhouette noise.
static func cap_mask(canvas: PortraitCanvas) -> PortraitMask:
	var w: int = canvas.face_w
	var h: int = canvas.face_h
	var style: String = canvas.trait_of("hair")
	var line: int = {"receding": 14, "military": 11, "buzz": 11}.get(style, 10)
	var hairline: PortraitMask = PortraitMask.above_v(CX, CY - line, 0.45)
	var temples: PortraitMask = PortraitMask.outside(CX, w - 3, CY - 2)
	var puff: int = {"military": 1, "buzz": 0, "messy": 3, "curly": 3}.get(style, 2)
	var dome: PortraitMask = PortraitMask.ellipse(CX, CY - 3, w + puff, h + puff - 1)
	var cap: PortraitMask = dome.intersect(hairline.union(temples))
	match style:
		"receding":
			cap = cap.minus(PortraitMask.ellipse(CX, CY - h + 2, 9, 7))
			cap = cap.intersect(PortraitMask.ellipse(CX, CY - 3, w + 1, h))
		"side":
			var sweep: Array[Vector2i] = [
				Vector2i(CX - w, CY - 10), Vector2i(CX + 6, CY - 14), Vector2i(CX - w + 1, CY - 3)
			]
			var fringe: PortraitMask = PortraitMask.poly(sweep)
			cap = cap.union(fringe.intersect(PortraitMask.ellipse(CX, CY, w + 2, h + 2)))
		"messy":
			cap = cap.union(_spikes(w, h))
		"curly":
			cap = cap.union(_curls(w, h))
		"long":
			var part: Array[Vector2i] = [
				Vector2i(CX - w - 2, CY - 8), Vector2i(CX + 2, CY - 14), Vector2i(CX - w, CY + 2)
			]
			var frame: PortraitMask = PortraitMask.ellipse(CX, CY, w + 4, h + 4)
			frame = frame.minus(PortraitMask.ellipse(CX, CY + 3, w - 1, h))
			cap = cap.union(PortraitMask.poly(part)).union(
				frame.intersect(PortraitMask.band(0, CY + 11))
			)
	return cap


static func _spikes(w: int, h: int) -> PortraitMask:
	var spikes := PortraitMask.new()
	for i: int in 7:
		var a: float = PI * (1.1 + i * 0.13)
		var tip := Vector2i(int(CX + cos(a) * (w + 5)), int(CY - 4 + sin(a) * (h + 4)))
		var left := Vector2i(int(CX + cos(a - 0.12) * w), int(CY - 4 + sin(a - 0.12) * h))
		var right := Vector2i(int(CX + cos(a + 0.12) * w), int(CY - 4 + sin(a + 0.12) * h))
		spikes = spikes.union(PortraitMask.poly([left, tip, right]))
	var lock: Array[Vector2i] = [
		Vector2i(CX - 8, CY - 12), Vector2i(CX + 2, CY - 12), Vector2i(CX - 4, CY - 6)
	]
	return spikes.union(PortraitMask.poly(lock))


static func _curls(w: int, h: int) -> PortraitMask:
	var curls := PortraitMask.new()
	for i: int in 12:
		var a: float = PI * (0.9 + i * 0.11)
		curls = curls.union(
			PortraitMask.ellipse(CX + cos(a) * (w + 1), CY - 6 + sin(a) * (h - 1), 4, 4)
		)
	return curls.intersect(PortraitMask.band(0, CY - 3))


## [param cap] with a broken top edge: small tufts above it and notches into it, in runs of
## one to three columns, so the outline reads as hair, not a helmet.
static func _ragged_top(canvas: PortraitCanvas, cap: PortraitMask) -> PortraitMask:
	var tufts := PortraitMask.new()
	var notches := PortraitMask.new()
	var x: int = 0
	while x < PortraitMask.SIZE:
		var top: int = _top_of(cap, x)
		var run: int = canvas.rng.randi_range(1, 3)
		if top > 0:
			var pick: int = canvas.rng.randi_range(0, 5)
			if pick <= 1:
				tufts.set_span(top - 1, x, x + run - 1)
				if pick == 0 and run > 1:
					tufts.set_span(top - 2, x + run / 2, x + run / 2)
			elif pick == 2:
				notches.set_span(top, x, x)
		x += run
	return cap.union(tufts.intersect(_columns_of(cap))).minus(notches)


## [param mask] with an uneven lower edge (long hair ends in locks of different lengths).
static func _ragged_bottom(canvas: PortraitCanvas, mask: PortraitMask) -> PortraitMask:
	var cut := PortraitMask.new()
	var x: int = 0
	while x < PortraitMask.SIZE:
		var run: int = canvas.rng.randi_range(2, 4)
		var depth: int = canvas.rng.randi_range(0, 3)
		for y: int in range(PortraitMask.SIZE - 1, -1, -1):
			if mask.has(x, y):
				cut = (
					cut.union(PortraitMask.rect(x, y - depth + 1, x + run - 1, y))
					if depth > 0
					else cut
				)
				break
		x += run
	return mask.minus(cut)


## Paints [constant CLUSTERS] clusters of strands spread across [param cap]: each starts just
## under the cap's top edge and runs down and away from the parting, two or three strands
## (a light line beside a dark gap) per cluster, kept inside the cap.
static func _draw_strands(canvas: PortraitCanvas, cap: PortraitMask) -> void:
	var cols: Vector2i = cap.column_range()
	if cols.y - cols.x < 12:
		return
	var span: float = (cols.y - cols.x - 8) / float(CLUSTERS - 1)
	for c: int in CLUSTERS:
		var x: int = cols.x + 4 + roundi(c * span) + canvas.rng.randi_range(-1, 1)
		var top: int = _top_of(cap, x)
		if top < 0:
			continue
		var lean: float = clampf((x - CX) / float(canvas.face_w), -1.0, 1.0) * 0.6
		var strands: int = canvas.rng.randi_range(2, 3)
		for s: int in strands:
			var origin := Vector2(x + s * 2, top + 2 + canvas.rng.randi_range(0, 2))
			_strand(canvas, cap, origin, Vector2(lean, 1.0), canvas.rng.randi_range(3, 6))


static func _strand(
	canvas: PortraitCanvas, cap: PortraitMask, origin: Vector2, step: Vector2, length: int
) -> void:
	for k: int in length:
		var p := Vector2i((origin + step * k).round())
		if cap.has(p.x, p.y) and cap.has(p.x + 1, p.y + 1):
			canvas.dot(
				p.x, p.y, canvas.hair[PortraitRamp.LIGHT if k < length - 1 else PortraitRamp.MID]
			)
			canvas.dot(p.x + 1, p.y, canvas.hair[PortraitRamp.SHADOW])


static func _top_of(mask: PortraitMask, x: int) -> int:
	for y: int in PortraitMask.SIZE:
		if mask.has(x, y):
			return y
	return -1


static func _columns_of(mask: PortraitMask) -> PortraitMask:
	var cols: Vector2i = mask.column_range()
	if cols.x < 0:
		return PortraitMask.new()
	return PortraitMask.rect(cols.x + 2, 0, cols.y - 2, PortraitMask.SIZE - 1)
