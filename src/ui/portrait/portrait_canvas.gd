class_name PortraitCanvas
extends RefCounted
## The 96×96 image a portrait is painted on, with the person being painted (the record and
## the values drawn from it) and the painting operations of the prototype's Canvas
## (tools/portraits/pixel_portraits.py): the smooth navy background, flat fills, and shaded
## masks lit from the upper left with a dark outline. Masks are written run by run.
## Bible: docs/content/portraits.md ("Style")

## Canvas side, in pixels.
const SIZE: int = PortraitMask.SIZE
## Centre of the face.
const CX: int = 48
const CY: int = 38
## Face half-width and half-height of each head shape.
const HEADS: Dictionary[String, Vector2i] = {
	"round": Vector2i(19, 21),
	"oval": Vector2i(17, 23),
	"square": Vector2i(19, 22),
	"long": Vector2i(16, 25)
}

static var _background: Image = null
static var _bit_index: Dictionary[int, int] = {}

## The pixels.
var image: Image = null
## The appearance record painted.
var record: Dictionary = {}
var female: bool = false
var face_w: int = 0
var face_h: int = 0
var skin: Array[Color] = []
var hair: Array[Color] = []
var eye: Array[Color] = []
## Seeded from the record, so the same record gives the same stubble and strands.
var rng := RandomNumberGenerator.new()


## A canvas with the background painted, ready for [param look] (an AppearanceRules record).
func _init(look: Dictionary) -> void:
	record = look
	female = str(look.get("sex", "")) == "female"
	var head: Vector2i = HEADS.get(str(look.get("head", "")), HEADS["oval"])
	var offset: int = _whole(look.get("face_width", 0))
	face_w = head.x - (1 if female else 0) + offset
	face_h = head.y
	skin = PortraitRamp.ramp(_pick(PortraitRamp.SKINS, look.get("skin", 0)))
	hair = PortraitRamp.ramp(_pick(PortraitRamp.HAIRS, look.get("hair_colour", 0)))
	eye = PortraitRamp.ramp(_pick(PortraitRamp.EYES, look.get("eye_colour", 0)))
	rng.seed = hash(JSON.stringify(look, "", true))
	image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	image.copy_from(background())


## The record's string value for [param key].
func trait_of(key: String) -> String:
	return str(record.get(key, ""))


## Paints every pixel of [param mask] [param colour].
func fill(mask: PortraitMask, colour: Color) -> void:
	for y: int in SIZE:
		_runs(y, mask.rows[y * 2], mask.rows[y * 2 + 1], colour)


## Shades [param mask] with [param shades] (a PortraitRamp): highlight top-left, shadow
## bottom-right and on the right fifth of its width, outline round the edge when [param rim].
## [param depth] is how far the light and shadow bands reach in.
func shaded(mask: PortraitMask, shades: Array[Color], depth: int = 3, rim: bool = true) -> void:
	_shade(mask, shades, Vector3(depth, 1.0 if rim else 0.0, 0.2))


## As shaded() with an outline, the shadowed right side [param side] of the width (0..1).
func shaded_side(mask: PortraitMask, shades: Array[Color], depth: int, side: float) -> void:
	_shade(mask, shades, Vector3(depth, 1.0, side))


## [param how]: depth, rim (1 or 0), side.
func _shade(mask: PortraitMask, shades: Array[Color], how: Vector3) -> void:
	var depth: int = int(how.x)
	var rim: int = int(how.y)
	var side: float = snappedf(how.z, 0.001)
	var cols: Vector2i = mask.column_range()
	if cols.x < 0:
		return
	var threshold: int = floori(cols.x + (cols.y - cols.x) * (1.0 - side)) + 1
	for y: int in SIZE:
		if mask.rows[y * 2] == 0 and mask.rows[y * 2 + 1] == 0:
			continue
		for half: int in 2:
			var side_bits: int = PortraitMask.span_bits(
				threshold, SIZE - 1, half * PortraitMask.WORD
			)
			_shade_word(mask, Vector4i(y, half, depth, rim), side_bits, shades)


## Paints the pixel ([param x], [param y]) when it is on the canvas.
func dot(x: int, y: int, colour: Color) -> void:
	if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
		image.set_pixel(x, y, colour)


## Paints row [param y] from [param x0] to [param x1].
func hline(x0: int, x1: int, y: int, colour: Color) -> void:
	var a: int = maxi(0, mini(x0, x1))
	var b: int = mini(SIZE - 1, maxi(x0, x1))
	if y >= 0 and y < SIZE and a <= b:
		image.fill_rect(Rect2i(a, y, b - a + 1, 1), colour)


## Darkens the pixel ([param x], [param y]) to [param factor] of its colour.
func darken(x: int, y: int, factor: float) -> void:
	var c: Color = image.get_pixel(x, y)
	image.set_pixel(x, y, Color8(int(c.r8 * factor), int(c.g8 * factor), int(c.b8 * factor)))


## The background every portrait starts from: dark navy, lighter at the top, a soft
## vignette (built once).
static func background() -> Image:
	if _background != null:
		return _background
	var top := Color.html("#1f2a3c")
	var bottom := Color.html("#0e1420")
	_background = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y: int in SIZE:
		var t: float = clampf(y / float(SIZE) * 1.1, 0.0, 1.0)
		for x: int in SIZE:
			var vignette: float = clampf(Vector2(x - 48, y - 40).length() / 70.0, 0.0, 1.0) * 0.35
			var k: float = clampf(t * 0.7 + vignette, 0.0, 1.0)
			_background.set_pixel(x, y, _truncated(top.lerp(bottom, k)))
	return _background


## Shades word [param at].y (0 low, 1 high) of row [param at].x of [param mask], with bands
## [param at].z deep, an outline when [param at].w is 1, and [param side_bits] the shadowed
## right side.
func _shade_word(mask: PortraitMask, at: Vector4i, side_bits: int, shades: Array[Color]) -> void:
	var y: int = at.x
	var half: int = at.y
	var depth: int = at.z
	var rim: bool = at.w == 1
	var full: int = PortraitMask.FULL
	var bits: int = mask.rows[y * 2 + half]
	if bits == 0:
		return
	var right: int = mask.shifted_word(y, 1, 0, half)
	var below: int = mask.shifted_word(y, 0, 1, half)
	var light: int = 0
	var dark: int = bits & side_bits
	if depth > 0:
		light = bits & (full ^ mask.shifted_word(y, -depth, -depth, half))
		dark |= bits & (full ^ mask.shifted_word(y, depth, depth, half))
	var high: int = light & (full ^ mask.shifted_word(y, -1, -1, half)) & right & below
	var edge: int = 0
	if rim:
		var inner: int = (
			right & below & mask.shifted_word(y, -1, 0, half) & mask.shifted_word(y, 0, -1, half)
		)
		edge = bits & (full ^ inner)
	var keep: int = full ^ edge
	var base: int = half * PortraitMask.WORD
	var unlit: int = full ^ light
	_word_runs(y, bits & (full ^ dark) & unlit & keep, base, shades[PortraitRamp.MID])
	_word_runs(y, dark & unlit & keep, base, shades[PortraitRamp.SHADOW])
	_word_runs(y, light & (full ^ high) & keep, base, shades[PortraitRamp.LIGHT])
	_word_runs(y, high & keep, base, shades[PortraitRamp.HIGHLIGHT])
	_word_runs(y, edge, base, shades[PortraitRamp.OUTLINE])


## Paints the set bits of row [param y] as horizontal runs.
func _runs(y: int, lo: int, hi: int, colour: Color) -> void:
	_word_runs(y, lo, 0, colour)
	_word_runs(y, hi, PortraitMask.WORD, colour)


func _word_runs(y: int, word: int, base: int, colour: Color) -> void:
	var bits: int = word
	while bits != 0:
		var lowest: int = bits & -bits
		var after: int = bits + lowest
		var start: int = _index_of(lowest)
		var end: int = _index_of(after & -after)
		image.fill_rect(Rect2i(base + start, y, end - start, 1), colour)
		bits &= after


static func _index_of(bit: int) -> int:
	if _bit_index.is_empty():
		for i: int in 63:
			_bit_index[1 << i] = i
	return _bit_index[bit]


static func _pick(palette: Array[String], index: Variant) -> String:
	return palette[clampi(_whole(index), 0, palette.size() - 1)]


static func _whole(value: Variant) -> int:
	if value is int or value is float:
		var number: float = value
		return int(number)
	return 0


static func _truncated(colour: Color) -> Color:
	return Color8(int(colour.r * 255.0), int(colour.g * 255.0), int(colour.b * 255.0))
