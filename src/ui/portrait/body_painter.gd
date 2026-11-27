class_name BodyPainter
extends RefCounted
## Paints the 64×128 full-body sprite of an appearance record (docs/content/portraits.md,
## "Full body"), one frame at a time from the pose table (BodyFrames), on a transparent
## background. Same skin, hair, uniform variant and accessories as the portrait; the build
## (slim, average, broad) and height come from the record's "build" and "height" (M8-05), so
## the same record always gives the same pixels. Feet stand on BASELINE in every frame and every
## offset is a whole pixel. An instance is the canvas of one frame: the image, the person's
## colours and measures, and the shape and shading operations the parts draw with.
## Bible: docs/content/portraits.md

## Sprite size, in pixels.
const W: int = 64
const H: int = 128
## Centre column.
const CX: int = 32
## Lowest row of the boots in every frame.
const BASELINE: int = 123
## Shoulder half-width of each build (men: 26, 30, 34 px across; women 4 px narrower).
const BUILDS: Array[int] = [13, 15, 17]
## A shape is W×H bytes (1 inside) followed by its box: x0, y0, x1, y1.
const BOX: int = W * H
## Outline colour of drawn features (eyes, glasses).
const INK := Color8(30, 26, 24)

## The pixels.
var image: Image = null
## The appearance record painted.
var record: Dictionary = {}
var female: bool = false
## "front", "back" or "side".
var direction: String = "front"
## The frame drawn (BodyFrames.frame()).
var pose: Dictionary = {}
## Shoulder half-width, hip half-width, torso half-depth (side), leg half-width.
var shoulder: int = 15
var hip: int = 11
var depth: int = 8
var leg: int = 4
## Rows the upper body sits below the tallest height (HEIGHT_MAX - "height"), plus the bob.
var drop: int = 0
var up: int = 0
var skin: Array[Color] = []
var hair: Array[Color] = []


## A clear canvas for [param look] seen from [param direction] in [param frame_data].
func _init(look: Dictionary, view: String, frame_data: Dictionary) -> void:
	record = look
	direction = view
	pose = frame_data
	female = str(look.get("sex", "")) == "female"
	var build: int = maxi(0, AppearanceRules.BUILDS.find(str(look.get("build", "average"))))
	shoulder = BUILDS[build] - (2 if female else 0)
	hip = shoulder - (0 if female else 2)
	depth = 8 + build
	leg = 3
	var saved_height: Variant = look.get("height", 0)
	var height: int = saved_height if saved_height is int else 0
	drop = (
		AppearanceRules.HEIGHT_MAX
		- clampi(height, AppearanceRules.HEIGHT_MIN, AppearanceRules.HEIGHT_MAX)
	)
	var bob: int = frame_data.get("bob", 0)
	up = drop + bob
	skin = PortraitRamp.ramp(_pick(PortraitRamp.SKINS, look.get("skin", 0)))
	hair = PortraitRamp.ramp(_pick(PortraitRamp.HAIRS, look.get("hair_colour", 0)))
	image = Image.create_empty(W, H, false, Image.FORMAT_RGBA8)


## Frame [param index] of [param pose_name] of [param record] seen from [param view].
static func paint(record: Dictionary, pose_name: String, view: String, index: int) -> Image:
	var canvas := BodyPainter.new(record, view, BodyFrames.frame(pose_name, index))
	BodyParts.draw(canvas)
	return canvas.image


## Every animation of the pose table for [param record]: "<pose>_<direction>", looping, at
## the pose's speed. Side frames face right; play them with flip_h for the left.
static func sprite_frames(record: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for pose_name: String in BodyFrames.poses():
		for view: String in BodyFrames.DIRECTIONS:
			var anim := StringName(BodyFrames.animation(pose_name, view))
			frames.add_animation(anim)
			frames.set_animation_loop(anim, true)
			frames.set_animation_speed(anim, BodyFrames.fps(pose_name))
			for i: int in BodyFrames.frame_count(pose_name):
				var image: Image = paint(record, pose_name, view, i)
				frames.add_frame(anim, ImageTexture.create_from_image(image))
	return frames


## The record's string value for [param key].
func trait_of(key: String) -> String:
	return str(record.get(key, ""))


## The frame's whole-number value for [param key].
func value(key: String) -> int:
	var number: int = pose.get(key, 0)
	return number


## Screen side (-1 left, 1 right) of the person's [param limb] ("l" or "r") from the front or
## back. From the side the person's left faces the viewer.
func screen_side(limb: String) -> int:
	var left: int = 1 if direction == "front" else -1
	return left if limb == "l" else -left


## A filled rectangle shape, corners inclusive.
static func rect(x0: int, y0: int, x1: int, y1: int) -> PackedByteArray:
	var bits: PackedByteArray = _blank(Rect2i(x0, y0, x1 - x0, y1 - y0))
	for y: int in range(maxi(0, y0), mini(H - 1, y1) + 1):
		for x: int in range(maxi(0, x0), mini(W - 1, x1) + 1):
			bits[y * W + x] = 1
	return bits


## A filled ellipse shape centred on ([param cx], [param cy]).
static func ellipse(cx: int, cy: int, rx: int, ry: int) -> PackedByteArray:
	var bits: PackedByteArray = _blank(Rect2i(cx - rx, cy - ry, rx * 2, ry * 2))
	for y: int in range(maxi(0, cy - ry), mini(H - 1, cy + ry) + 1):
		for x: int in range(maxi(0, cx - rx), mini(W - 1, cx + rx) + 1):
			var dx: float = (x - cx) / float(rx)
			var dy: float = (y - cy) / float(ry)
			if dx * dx + dy * dy <= 1.0:
				bits[y * W + x] = 1
	return bits


## A filled polygon shape through [param points] (pixel centres inside it).
static func poly(points: Array[Vector2i]) -> PackedByteArray:
	var outline := PackedVector2Array()
	var box := Rect2i(points[0], Vector2i.ZERO)
	for p: Vector2i in points:
		outline.append(Vector2(p))
		box = box.expand(p)
	var bits: PackedByteArray = _blank(box)
	for y: int in range(maxi(0, box.position.y), mini(H - 1, box.end.y) + 1):
		for x: int in range(maxi(0, box.position.x), mini(W - 1, box.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), outline):
				bits[y * W + x] = 1
	return bits


## Pixels in [param a] or [param b].
static func union(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	var out: PackedByteArray = a.duplicate()
	var box: Rect2i = _box(b)
	for y: int in range(box.position.y, box.end.y + 1):
		for x: int in range(box.position.x, box.end.x + 1):
			if b[y * W + x] != 0:
				out[y * W + x] = 1
	box = box.merge(_box(a))
	out[BOX] = box.position.x
	out[BOX + 1] = box.position.y
	out[BOX + 2] = box.end.x
	out[BOX + 3] = box.end.y
	return out


## Pixels in [param a] and not in [param b].
static func minus(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	var out: PackedByteArray = a.duplicate()
	var box: Rect2i = _box(a)
	for y: int in range(box.position.y, box.end.y + 1):
		for x: int in range(box.position.x, box.end.x + 1):
			if b[y * W + x] != 0:
				out[y * W + x] = 0
	return out


## Shades [param shape] with [param shades] (a PortraitRamp) as the prototype does: outline
## round the edge, light where the shape ends [param band] up and left, shadow where it ends
## [param band] to the right, mid elsewhere.
func shaded(shape: PackedByteArray, shades: Array[Color], band: int = 2) -> void:
	var box: Rect2i = _box(shape)
	for y: int in range(box.position.y, box.end.y + 1):
		for x: int in range(box.position.x, box.end.x + 1):
			if shape[y * W + x] == 0:
				continue
			var step: int = PortraitRamp.MID
			if not _in(shape, x + band, y):
				step = PortraitRamp.SHADOW
			if not _in(shape, x - band, y - band):
				step = PortraitRamp.LIGHT
			if not (
				_in(shape, x + 1, y)
				and _in(shape, x - 1, y)
				and _in(shape, x, y + 1)
				and _in(shape, x, y - 1)
			):
				step = PortraitRamp.OUTLINE
			image.set_pixel(x, y, shades[step])


## Paints every pixel of [param shape] [param colour].
func fill(shape: PackedByteArray, colour: Color) -> void:
	var box: Rect2i = _box(shape)
	for y: int in range(box.position.y, box.end.y + 1):
		for x: int in range(box.position.x, box.end.x + 1):
			if shape[y * W + x] != 0:
				image.set_pixel(x, y, colour)


## Paints the pixel ([param x], [param y]) when it is on the canvas.
func dot(x: int, y: int, colour: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		image.set_pixel(x, y, colour)


## Paints column [param x] from row [param y0] to [param y1].
func vline(x: int, y0: int, y1: int, colour: Color) -> void:
	for y: int in range(y0, y1 + 1):
		dot(x, y, colour)


## Paints row [param y] from column [param x0] to [param x1].
func hline(x0: int, x1: int, y: int, colour: Color) -> void:
	for x: int in range(x0, x1 + 1):
		dot(x, y, colour)


## An empty shape whose box is [param box] clipped to the canvas (end inclusive).
static func _blank(box: Rect2i) -> PackedByteArray:
	var bits := PackedByteArray()
	bits.resize(BOX + 4)
	bits[BOX] = clampi(box.position.x, 0, W - 1)
	bits[BOX + 1] = clampi(box.position.y, 0, H - 1)
	bits[BOX + 2] = clampi(box.end.x, 0, W - 1)
	bits[BOX + 3] = clampi(box.end.y, 0, H - 1)
	return bits


## The box of [param shape]: position is the first corner, end the last (inclusive).
static func _box(shape: PackedByteArray) -> Rect2i:
	var x0: int = shape[BOX]
	var y0: int = shape[BOX + 1]
	return Rect2i(x0, y0, shape[BOX + 2] - x0, shape[BOX + 3] - y0)


static func _in(shape: PackedByteArray, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H and shape[y * W + x] != 0


static func _pick(palette: Array[String], index: Variant) -> String:
	var i: int = 0
	if index is int or index is float:
		var number: float = index
		i = int(number)
	return palette[clampi(i, 0, palette.size() - 1)]
