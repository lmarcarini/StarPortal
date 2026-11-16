class_name HardwareTextures
extends RefCounted
## Draws the interface hardware textures (steel plate with bolts, recessed panel, hazard
## stripe, key up and down, lamp off and on, gauge face) pixel by pixel from fixed maths, so
## they regenerate identically. tools/gen_hardware_textures.gd writes them to art/ui/hardware.
## Tool code only. Bible: docs/content/interface-rethink.md section 7 (interface hardware)

## Folder the textures live in.
const OUT_DIR: String = "res://art/ui/hardware"
## Texture names, without extension.
const NAMES: Array[String] = [
	"steel_plate", "recessed", "hazard", "key_up", "key_down", "lamp_off", "lamp_on", "gauge_face"
]

const _STEEL: Color = Color("#55524b")
const _STEEL_DARK: Color = Color("#2b2a27")
const _RECESS: Color = Color("#161716")
const _HAZARD_A: Color = Color("#d9a521")
const _HAZARD_B: Color = Color("#191917")


## Every texture by name.
static func build_all() -> Dictionary[String, Image]:
	var out: Dictionary[String, Image] = {}
	out["steel_plate"] = steel_plate()
	out["recessed"] = recessed()
	out["hazard"] = hazard()
	out["key_up"] = key(6)
	out["key_down"] = key(2)
	out["lamp_off"] = lamp(false)
	out["lamp_on"] = lamp(true)
	out["gauge_face"] = gauge_face()
	return out


## Deterministic grain in 0..1 for pixel (x, y).
static func grain(x: int, y: int) -> float:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ 0x5bd1e995
	h = (h ^ (h >> 13)) * 1274126177
	return float((h >> 8) & 0xff) / 255.0


## 48 px steel plate: bevelled edges, worn grain and a bolt in each corner.
static func steel_plate() -> Image:
	var img: Image = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	for y: int in 48:
		for x: int in 48:
			var c: Color = _STEEL.darkened(0.12 * grain(x, y) + 0.1 * float(y) / 48.0)
			c = _bevel(c, x, y, 48, 3)
			img.set_pixel(x, y, c)
	for corner: Vector2i in [Vector2i(9, 9), Vector2i(38, 9), Vector2i(9, 38), Vector2i(38, 38)]:
		_bolt(img, corner)
	return img


## 48 px recessed panel: dark well with an inner shadow top and left.
static func recessed() -> Image:
	var img: Image = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	for y: int in 48:
		for x: int in 48:
			var c: Color = _RECESS.lightened(0.04 * grain(x, y))
			var edge: int = mini(x, y)
			if edge < 4:
				c = c.darkened(0.5 - 0.1 * edge)
			if x > 45 or y > 45:
				c = _STEEL.darkened(0.2)
			img.set_pixel(x, y, c)
	return img


## 32 px tileable hazard stripes at 45 degrees.
static func hazard() -> Image:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y: int in 32:
		for x: int in 32:
			var band: bool = ((x + y) / 8) % 2 == 0
			var c: Color = _HAZARD_A if band else _HAZARD_B
			img.set_pixel(x, y, c.darkened(0.15 * grain(x, y)))
	return img


## 48 px key face on a dark lip [param lip] px tall (6 up, 2 down).
static func key(lip: int) -> Image:
	var img: Image = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	var face_bottom: int = 48 - lip
	for y: int in 48:
		for x: int in 48:
			var c: Color = _STEEL_DARK.darkened(0.4)
			if y < face_bottom:
				c = _STEEL.lightened(0.08).darkened(0.08 * grain(x, y) + 0.12 * float(y) / 48.0)
				c = _bevel(c, x, y, face_bottom, 2)
			img.set_pixel(x, y, c)
	return img


## 32 px lamp: a bezel ring around glass, dark when [param on] is false, white when true
## (tinted by the control).
static func lamp(on: bool) -> Image:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y: int in 32:
		for x: int in 32:
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(Vector2(16, 16))
			var c: Color = Color(0, 0, 0, 0)
			if d < 15.5:
				c = _STEEL.darkened(0.2)
			if d < 12.0:
				c = Color(1, 1, 1).darkened(d / 30.0) if on else Color("#22231f")
			if d < 4.0 and on:
				c = Color(1, 1, 1)
			img.set_pixel(x, y, c)
	return img


## 128 px gauge face: a steel bezel round a cream dial.
static func gauge_face() -> Image:
	var img: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y: int in 128:
		for x: int in 128:
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(Vector2(64, 64))
			var c: Color = Color(0, 0, 0, 0)
			if d < 63.5:
				c = _STEEL.darkened(0.1 + 0.2 * float(y) / 128.0)
			if d < 56.0:
				c = Color("#d8d2bd").darkened(0.08 * grain(x, y) + d / 400.0)
			img.set_pixel(x, y, c)
	return img


static func _bevel(c: Color, x: int, y: int, h: int, w: int) -> Color:
	if x < w or y < w:
		return c.lightened(0.25)
	if x >= 48 - w or y >= h - w:
		return c.darkened(0.4)
	return c


static func _bolt(img: Image, centre: Vector2i) -> void:
	for dy: int in range(-4, 5):
		for dx: int in range(-4, 5):
			var d: float = Vector2(dx, dy).length()
			if d > 4.0:
				continue
			var c: Color = _STEEL.lightened(0.3 - 0.1 * float(dx + dy) / 4.0)
			if d > 3.0:
				c = _STEEL_DARK
			img.set_pixel(centre.x + dx, centre.y + dy, c)
