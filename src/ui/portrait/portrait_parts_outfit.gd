class_name PortraitPartsOutfit
extends RefCounted
## The uniform layer of a portrait, by the record's "field" and "variant"
## (docs/content/portraits.md, "Uniform variant by field"), each with its field's accent:
## Military red patch, Science blue, Engineering orange, Office brass, Medicine pale badge.
## Ported from the prototype's mil/sci/eng/off/med (tools/portraits/pixel_portraits.py).
## Bible: docs/content/portraits.md

const CX: int = PortraitCanvas.CX
const RED_CROSS := Color8(150, 40, 36)
const PEN := Color8(40, 60, 120)
const TUBE := Color8(40, 44, 48)
const _MILITARY_BASE: Dictionary[String, String] = {
	"standard": "#4b5135",
	"officer": "#3b4232",
	"expedition": "#5d5a3e",
	"casual": "#24282c",
	"command": "#2b3446"
}
const _ENGINEERING_BASE: Dictionary[String, String] = {
	"coverall": "#6d5a3c", "vest": "#4a4f55", "jacket": "#3a3d40", "casual": "#4a4f55"
}
const _OFFICE_BASE: Dictionary[String, String] = {
	"suit": "#2c3546", "shirt_tie": "#d6d2c6", "sweater": "#5a4a5e", "blazer": "#5c4a3a"
}


## Paints the record's uniform on the torso.
static func draw(canvas: PortraitCanvas) -> void:
	var torso: PortraitMask = PortraitOutfitKit.torso(canvas)
	var variant: String = canvas.trait_of("variant")
	match canvas.trait_of("field"):
		"military":
			_military(canvas, torso, variant)
		"science":
			_science(canvas, torso, variant)
		"engineering":
			_engineering(canvas, torso, variant)
		"medicine":
			_medicine(canvas, torso, variant)
		_:
			_office(canvas, torso, variant)


static func _military(canvas: PortraitCanvas, torso: PortraitMask, variant: String) -> void:
	var base: String = _MILITARY_BASE.get(variant, _MILITARY_BASE["standard"])
	var shades: Array[Color] = PortraitRamp.ramp(base)
	PortraitOutfitKit.body(canvas, torso, shades)
	if variant == "casual":
		PortraitOutfitKit.crew_neck(canvas, shades[3])
		return
	if variant == "officer" or variant == "command":
		PortraitOutfitKit.shirt_v(canvas, "#c9c3b0")
		PortraitOutfitKit.tie(canvas, "#262a22")
		PortraitOutfitKit.lapels(canvas, base)
		PortraitOutfitKit.epaulettes(canvas, base, "#c9a35a")
		if variant == "command":
			var ribbons: Array[String] = ["#7a2e24", "#2f5f86", "#c9a35a"]
			for i: int in 3:
				var bar: PortraitMask = PortraitMask.rect(CX + 18 + i * 4, 80, CX + 20 + i * 4, 82)
				canvas.shaded(bar, PortraitRamp.ramp(ribbons[i]), 0, false)
		return
	PortraitOutfitKit.stand_collar(canvas, base)
	PortraitOutfitKit.zipper(canvas, base)
	PortraitOutfitKit.pockets(canvas, base)
	PortraitOutfitKit.epaulettes(canvas, base)
	PortraitOutfitKit.patch(canvas, PortraitRamp.ACCENTS["military"])
	if variant == "expedition":
		PortraitOutfitKit.straps(canvas, "#3a3a2c")
		canvas.shaded(PortraitMask.rect(CX + 14, 74, CX + 19, 84), PortraitRamp.ramp("#2a2a2a"), 1)


static func _science(canvas: PortraitCanvas, torso: PortraitMask, variant: String) -> void:
	var accent: String = PortraitRamp.ACCENTS["science"]
	match variant:
		"labcoat":
			PortraitOutfitKit.body(canvas, torso, PortraitRamp.ramp("#d9d6cc", 0.5))
			PortraitOutfitKit.shirt_v(canvas, "#2b3340", 30, 11)
			PortraitOutfitKit.lapels(canvas, "#d9d6cc")
			var points: Array[Vector2i] = [
				Vector2i(CX - 7, 64), Vector2i(CX, 72), Vector2i(CX + 7, 64)
			]
			canvas.shaded(PortraitMask.poly(points), PortraitRamp.ramp(accent), 1)
			canvas.shaded(
				PortraitMask.rect(CX + 18, 84, CX + 26, 92), PortraitRamp.ramp("#d9d6cc", 0.5), 1
			)
			canvas.dot(CX + 20, 84, PEN)
			canvas.dot(CX + 20, 85, PEN)
		"shirt_tie":
			PortraitOutfitKit.body(canvas, torso, PortraitRamp.ramp("#8fa6b8", 0.7))
			PortraitOutfitKit.stand_collar(canvas, "#a9bccb")
			PortraitOutfitKit.tie(canvas, accent, 69)
		"overalls":
			PortraitOutfitKit.body(canvas, torso, PortraitRamp.ramp("#56636b"))
			PortraitOutfitKit.vneck(canvas, 8)
			PortraitOutfitKit.straps(canvas, "#3e4950")
			PortraitOutfitKit.patch(canvas, accent, 74, 84)
		_:
			PortraitOutfitKit.body(canvas, torso, PortraitRamp.ramp("#6b5a4a"))
			canvas.shaded(
				PortraitMask.rect(CX - 9, 60, CX + 9, 68), PortraitRamp.ramp("#4a3e34"), 1
			)


static func _engineering(canvas: PortraitCanvas, torso: PortraitMask, variant: String) -> void:
	var base: String = _ENGINEERING_BASE.get(variant, _ENGINEERING_BASE["casual"])
	var accent: String = PortraitRamp.ACCENTS["engineering"]
	PortraitOutfitKit.body(canvas, torso, PortraitRamp.ramp(base))
	match variant:
		"coverall":
			PortraitOutfitKit.stand_collar(canvas, base)
			PortraitOutfitKit.zipper(canvas, base)
			PortraitOutfitKit.pockets(canvas, base)
			PortraitOutfitKit.patch(canvas, accent)
		"vest":
			PortraitOutfitKit.vneck(canvas, 8)
			var stripe: Color = PortraitRamp.ramp("#d8d2c4")[3]
			for s: int in [-1, 1]:
				var points: Array[Vector2i] = [
					Vector2i(CX + s * 9, 66),
					Vector2i(CX + s * 24, 66),
					Vector2i(CX + s * 26, 96),
					Vector2i(CX + s * 6, 96)
				]
				canvas.shaded(PortraitMask.poly(points), PortraitRamp.ramp(accent), 2)
				canvas.hline(CX + s * 7, CX + s * 25, 86, stripe)
		"jacket":
			PortraitOutfitKit.stand_collar(canvas, base)
			PortraitOutfitKit.zipper(canvas, base, 69)
			var band: Color = PortraitRamp.ramp(accent)[2]
			for s: int in [-1, 1]:
				canvas.hline(CX + s * 2, CX + s * 40, 78, band)
		_:
			PortraitOutfitKit.crew_neck(canvas, PortraitRamp.ramp(base)[3])
			canvas.shaded(PortraitMask.rect(CX - 26, 80, CX - 16, 86), PortraitRamp.ramp(accent), 1)


static func _office(canvas: PortraitCanvas, torso: PortraitMask, variant: String) -> void:
	var base: String = _OFFICE_BASE.get(variant, _OFFICE_BASE["suit"])
	var accent: String = PortraitRamp.ACCENTS["office"]
	PortraitOutfitKit.body(
		canvas, torso, PortraitRamp.ramp(base, 0.6 if variant == "shirt_tie" else 1.0)
	)
	match variant:
		"shirt_tie":
			PortraitOutfitKit.stand_collar(canvas, "#e2ded4")
			PortraitOutfitKit.tie(canvas, "#7a2e24", 69)
		"sweater":
			PortraitOutfitKit.shirt_v(canvas, "#d9d4c8", 16, 9)
			var points: Array[Vector2i] = [
				Vector2i(CX - 5, 64), Vector2i(CX, 70), Vector2i(CX + 5, 64)
			]
			canvas.shaded(PortraitMask.poly(points), PortraitRamp.ramp("#d9d4c8", 0.5), 1)
		"blazer":
			PortraitOutfitKit.shirt_v(canvas, "#24262a", 26, 11)
			PortraitOutfitKit.lapels(canvas, base)
			canvas.shaded(
				PortraitMask.rect(CX - 8, 60, CX + 8, 67), PortraitRamp.ramp("#24262a"), 1
			)
		_:
			PortraitOutfitKit.shirt_v(canvas, "#d9d4c8")
			PortraitOutfitKit.tie(canvas, accent)
			PortraitOutfitKit.lapels(canvas, base)


static func _medicine(canvas: PortraitCanvas, torso: PortraitMask, variant: String) -> void:
	if variant == "fatigues":
		var olive: String = "#4b5135"
		PortraitOutfitKit.body(canvas, torso, PortraitRamp.ramp(olive))
		PortraitOutfitKit.stand_collar(canvas, olive)
		PortraitOutfitKit.zipper(canvas, olive)
		PortraitOutfitKit.pockets(canvas, olive)
		PortraitOutfitKit.patch(canvas, PortraitRamp.ACCENTS["medicine"])
		canvas.hline(9, 14, 85, RED_CROSS)
		canvas.hline(9, 14, 86, RED_CROSS)
		for y: int in [83, 84, 87, 88]:
			canvas.dot(11, y, RED_CROSS)
			canvas.dot(12, y, RED_CROSS)
		return
	var coat: bool = variant == "labcoat"
	PortraitOutfitKit.body(
		canvas, torso, PortraitRamp.ramp("#d9d6cc", 0.5) if coat else PortraitRamp.ramp("#3f6e6a")
	)
	if coat:
		PortraitOutfitKit.shirt_v(canvas, "#3f6e6a", 30, 11)
		PortraitOutfitKit.lapels(canvas, "#d9d6cc")
	PortraitOutfitKit.vneck(canvas, 12)
	canvas.shaded(
		PortraitMask.rect(CX + 16, 82, CX + 27, 87),
		PortraitRamp.ramp(PortraitRamp.ACCENTS["medicine"]),
		1
	)
	if not coat:
		for k: int in 14:
			canvas.dot(CX - 12 + k / 4, 66 + k, TUBE)
			canvas.dot(CX + 12 - k / 4, 66 + k, TUBE)
