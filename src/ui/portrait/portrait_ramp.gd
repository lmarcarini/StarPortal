class_name PortraitRamp
extends RefCounted
## Palettes and five-step colour ramps for the portraits (docs/content/portraits.md,
## "Style"): outline, shadow, mid, light, highlight. Shadows shift cool, lights shift warm,
## and the outline is never lighter than 26 % lightness. Same maths as the prototype's
## ramp() (tools/portraits/pixel_portraits.py), in HLS. Ramps are cached by colour.
## Bible: docs/content/portraits.md

## Ramp steps.
const OUTLINE: int = 0
const SHADOW: int = 1
const MID: int = 2
const LIGHT: int = 3
const HIGHLIGHT: int = 4
## Skin tones, indexed by the record's "skin".
const SKINS: Array[String] = ["#f1c9a5", "#e0ac84", "#c68a62", "#a86b45", "#7d4a2e", "#5a3420"]
## Hair colours, indexed by the record's "hair_colour": nine natural, then three greys.
const HAIRS: Array[String] = [
	"#2a1d16",
	"#3b2618",
	"#5a3a22",
	"#7a5432",
	"#a0702e",
	"#c9a35a",
	"#8a3c1c",
	"#b0552a",
	"#1b1b1f",
	"#8d8a86",
	"#b7b3ad",
	"#d8d5cf",
]
## Eye colours, indexed by the record's "eye_colour".
const EYES: Array[String] = ["#3b5a7a", "#4d6b3a", "#5a3b22", "#2b2018", "#6b7d8a"]
## Field accent colours (docs/content/portraits.md, "Uniform variant by field").
const ACCENTS: Dictionary[String, String] = {
	"military": "#7a2e24",
	"office": "#8a6a2a",
	"science": "#2f5f86",
	"engineering": "#c27a1e",
	"medicine": "#d8d2c4",
}
## Lightness, hue and saturation shifts of the five steps.
const _STEPS: Array[Vector3] = [
	Vector3(-0.30, 0.04, 0.10),
	Vector3(-0.13, 0.02, 0.05),
	Vector3(0.0, 0.0, 0.0),
	Vector3(0.08, -0.01, -0.06),
	Vector3(0.14, -0.02, -0.15),
]
## Darkest an outline may be lifted to.
const _OUTLINE_MAX_LIGHTNESS: float = 0.26

static var _cache: Dictionary[String, Array] = {}


## The five shades of [param hex] with saturation scaled by [param sat].
static func ramp(hex: String, sat: float = 1.0) -> Array[Color]:
	var key: String = "%s/%s" % [hex, sat]
	if _cache.has(key):
		var cached: Array[Color] = []
		cached.assign(_cache[key])
		return cached
	var hls: Vector3 = rgb_to_hls(Color.html(hex))
	var out: Array[Color] = []
	for step: Vector3 in _STEPS:
		var hue: float = fposmod(hls.x + step.y, 1.0)
		var light: float = clampf(hls.y + step.x, 0.03, 0.95)
		if step.x < -0.25:
			light = minf(light, _OUTLINE_MAX_LIGHTNESS)
		var saturation: float = clampf((hls.z + step.z) * sat, 0.0, 1.0)
		out.append(_truncated(hls_to_rgb(Vector3(hue, light, saturation))))
	_cache[key] = out
	return out


## [param colour] as (hue, lightness, saturation), each 0..1 (Python's colorsys).
static func rgb_to_hls(colour: Color) -> Vector3:
	var high: float = maxf(colour.r, maxf(colour.g, colour.b))
	var low: float = minf(colour.r, minf(colour.g, colour.b))
	var light: float = (high + low) / 2.0
	if is_equal_approx(high, low):
		return Vector3(0.0, light, 0.0)
	var spread: float = high - low
	var sat: float = spread / (high + low) if light <= 0.5 else spread / (2.0 - high - low)
	var rc: float = (high - colour.r) / spread
	var gc: float = (high - colour.g) / spread
	var bc: float = (high - colour.b) / spread
	var hue: float = 0.0
	if colour.r == high:
		hue = bc - gc
	elif colour.g == high:
		hue = 2.0 + rc - bc
	else:
		hue = 4.0 + gc - rc
	return Vector3(fposmod(hue / 6.0, 1.0), light, sat)


## (hue, lightness, saturation) back to a colour (Python's colorsys).
static func hls_to_rgb(hls: Vector3) -> Color:
	if hls.z == 0.0:
		return Color(hls.y, hls.y, hls.y)
	var m2: float = hls.y * (1.0 + hls.z) if hls.y <= 0.5 else hls.y + hls.z - hls.y * hls.z
	var m1: float = 2.0 * hls.y - m2
	return Color(
		_channel(m1, m2, hls.x + 1.0 / 3.0),
		_channel(m1, m2, hls.x),
		_channel(m1, m2, hls.x - 1.0 / 3.0)
	)


static func _channel(m1: float, m2: float, hue: float) -> float:
	var h: float = fposmod(hue, 1.0)
	if h < 1.0 / 6.0:
		return m1 + (m2 - m1) * h * 6.0
	if h < 0.5:
		return m2
	if h < 2.0 / 3.0:
		return m1 + (m2 - m1) * (2.0 / 3.0 - h) * 6.0
	return m1


static func _truncated(colour: Color) -> Color:
	return Color8(int(colour.r * 255.0), int(colour.g * 255.0), int(colour.b * 255.0))
