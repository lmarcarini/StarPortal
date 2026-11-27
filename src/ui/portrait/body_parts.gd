class_name BodyParts
extends RefCounted
## The body layer of the full-body sprite: legs and boots, torso and uniform, arms and hands,
## in the uniform colours of the portrait (PortraitPartsOutfit) and with the limb styles the
## pose table names ("arms": "hang" or "forward"; "legs": "stand"). Head, hair and face are
## in BodyPartsHead. Layers, back to front: far limbs, torso, uniform details, head, near
## limbs; from the back, working arms show elbows out and the forearms go in behind.
## Bible: docs/content/portraits.md ("Uniform variant by field")

const CX: int = BodyPainter.CX
const BOOT := "#24221f"
const BELT := "#2a2622"
const BRASS := "#c9a35a"
const SHIRT := "#d9d4c8"
## Top colour, trouser colour and top saturation of each uniform variant, by field.
const OUTFITS: Dictionary[String, Dictionary] = {
	"military":
	{
		"standard": ["#4b5135", "#4b5135", 1.0],
		"officer": ["#3b4232", "#3b4232", 1.0],
		"expedition": ["#5d5a3e", "#5d5a3e", 1.0],
		"casual": ["#24282c", "#4b5135", 1.0],
		"command": ["#2b3446", "#2b3446", 1.0],
	},
	"science":
	{
		"labcoat": ["#d9d6cc", "#3a3f48", 0.5],
		"shirt_tie": ["#8fa6b8", "#3a3f48", 0.7],
		"overalls": ["#56636b", "#56636b", 1.0],
		"casual": ["#6b5a4a", "#3a3f48", 1.0],
	},
	"engineering":
	{
		"coverall": ["#6d5a3c", "#6d5a3c", 1.0],
		"vest": ["#4a4f55", "#3a3d40", 1.0],
		"jacket": ["#3a3d40", "#3a3d40", 1.0],
		"casual": ["#4a4f55", "#3a3f48", 1.0],
	},
	"office":
	{
		"suit": ["#2c3546", "#2c3546", 1.0],
		"shirt_tie": ["#d6d2c6", "#3a3f48", 0.6],
		"sweater": ["#5a4a5e", "#3a3f48", 1.0],
		"blazer": ["#5c4a3a", "#3a3632", 1.0],
	},
	"medicine":
	{
		"scrubs": ["#3f6e6a", "#3f6e6a", 1.0],
		"labcoat": ["#d9d6cc", "#3a3f48", 0.5],
		"fatigues": ["#4b5135", "#4b5135", 1.0],
	},
}
const TIES: Array[String] = ["officer", "command", "suit", "shirt_tie", "blazer"]
const ZIPS: Array[String] = ["standard", "expedition", "coverall", "fatigues", "jacket"]
const PATCHES: Array[String] = ["standard", "expedition", "coverall", "fatigues", "jacket"]


## Draws the whole figure of [param c] for its direction and frame.
static func draw(c: BodyPainter) -> void:
	var side: bool = c.direction == "side"
	if side:
		_leg(c, "r", _darker(_hex(c, 1)))
		_arm(c, "r", _darker(_hex(c, 0)))
		_leg(c, "l", _hex(c, 1))
	else:
		_leg(c, "l", _hex(c, 1))
		_leg(c, "r", _hex(c, 1))
	BodyPartsHead.draw_neck(c)
	_torso(c)
	_details(c)
	BodyPartsHead.draw(c)
	if side:
		_arm(c, "l", _hex(c, 0))
	else:
		_arm(c, "l", _hex(c, 0))
		_arm(c, "r", _hex(c, 0))


## [top hex, trouser hex, top saturation] of the record's uniform.
static func _outfit(c: BodyPainter) -> Array:
	var field: Dictionary = OUTFITS.get(c.trait_of("field"), OUTFITS["office"])
	var found: Array = field.get(c.trait_of("variant"), field.values()[0])
	return found


## Top (0) or trouser (1) colour of the record's uniform.
static func _hex(c: BodyPainter, index: int) -> String:
	var hex: String = _outfit(c)[index]
	return hex


static func _sat(c: BodyPainter) -> float:
	var sat: float = _outfit(c)[2]
	return sat


static func _top(c: BodyPainter) -> Array[Color]:
	return PortraitRamp.ramp(_hex(c, 0), _sat(c))


static func _darker(hex: String) -> String:
	return Color.html(hex).darkened(0.25).to_html(false)


static func _coat(c: BodyPainter) -> bool:
	return c.trait_of("variant") == "labcoat"


## Row of the shoulders and of the waist (belt bottom) this frame.
static func shoulder_y(c: BodyPainter) -> int:
	return 29 + c.up


static func waist_y(c: BodyPainter) -> int:
	return 70 + c.up


## One leg and boot; [param hex] is the trouser colour.
static func _leg(c: BodyPainter, limb: String, hex: String) -> void:
	var lift: int = c.value("lift_" + limb)
	var top: int = waist_y(c) - 3
	var ankle: int = 114 - lift
	var floor_y: int = BodyPainter.BASELINE - lift
	var boot: PackedByteArray
	var shape: PackedByteArray
	if c.direction == "side":
		var foot: int = CX + c.value("step_" + limb)
		var points: Array[Vector2i] = [
			Vector2i(CX - c.leg - 2, top),
			Vector2i(CX + c.leg + 2, top),
			Vector2i(foot + 4, ankle + 1),
			Vector2i(foot - 3, ankle + 1),
		]
		shape = BodyPainter.poly(points)
		boot = BodyPainter.union(
			BodyPainter.rect(foot - 3, ankle, foot + 3, floor_y),
			BodyPainter.rect(foot - 3, floor_y - 4, foot + 6, floor_y)
		)
	else:
		var x: int = CX + c.screen_side(limb) * (c.leg + 2)
		shape = BodyPainter.rect(x - c.leg, top, x + c.leg, ankle)
		boot = BodyPainter.rect(x - c.leg, ankle, x + c.leg + 1, floor_y)
	c.shaded(shape, PortraitRamp.ramp(hex))
	c.shaded(boot, PortraitRamp.ramp(BOOT))


## The torso, the coat skirt of a lab coat, and the belt.
static func _torso(c: BodyPainter) -> void:
	var sy: int = shoulder_y(c)
	var hem: int = waist_y(c) + (22 if _coat(c) else 0)
	var half: int = c.depth if c.direction == "side" else c.shoulder
	var low: int = c.depth - 1 if c.direction == "side" else c.hip
	var flare: int = 2 if _coat(c) else 0
	var points: Array[Vector2i] = [
		Vector2i(CX - half + 1, sy),
		Vector2i(CX + half, sy),
		Vector2i(CX + half + 1, sy + 2),
		Vector2i(CX + low + 1 + flare, hem + 1),
		Vector2i(CX - low - flare, hem + 1),
		Vector2i(CX - half, sy + 2),
	]
	c.shaded(BodyPainter.poly(points), _top(c), 3)
	var belt_x: int = (c.depth - 1) if c.direction == "side" else c.hip
	if _coat(c):
		return
	var belt: PackedByteArray = BodyPainter.rect(
		CX - belt_x, waist_y(c) - 3, CX + belt_x, waist_y(c)
	)
	c.shaded(belt, PortraitRamp.ramp(BELT), 1)
	if c.direction == "front":
		c.dot(CX, waist_y(c) - 2, PortraitRamp.ramp(BRASS)[PortraitRamp.LIGHT])


## One arm and hand in the frame's arm style; [param hex] is the sleeve colour.
static func _arm(c: BodyPainter, limb: String, hex: String) -> void:
	var sleeve: Array[Color] = PortraitRamp.ramp(hex, _sat(c))
	if c.pose.get("arms") == "forward":
		_arm_forward(c, limb, sleeve)
		return
	var sy: int = shoulder_y(c)
	var swing: int = c.value("swing_" + limb)
	var hand: Vector2i
	var points: Array[Vector2i]
	if c.direction == "side":
		hand = Vector2i(CX + swing, 65 + c.up - (absi(swing) >> 1))
		points = [
			Vector2i(CX - 3, sy + 1),
			Vector2i(CX + 3, sy + 1),
			Vector2i(hand.x + 3, hand.y),
			Vector2i(hand.x - 2, hand.y),
		]
	else:
		var s: int = c.screen_side(limb)
		var w: int = c.shoulder
		hand = Vector2i(CX + s * (w + 3), 65 + c.up - (swing >> 1))
		points = [
			Vector2i(CX + s * w, sy),
			Vector2i(CX + s * (w + 4), sy + 1),
			Vector2i(CX + s * (w + 6), sy + 4),
			Vector2i(CX + s * (w + 6), hand.y),
			Vector2i(CX + s * w, hand.y),
		]
	c.shaded(BodyPainter.poly(points), sleeve)
	_hand(c, hand.x, hand.y)


## A 3×4 skin hand hanging from ([param x], [param y]), shadowed underneath.
static func _hand(c: BodyPainter, x: int, y: int) -> void:
	c.fill(BodyPainter.rect(x - 1, y, x + 1, y + 3), c.skin[PortraitRamp.MID])
	c.hline(x - 1, x + 1, y + 3, c.skin[PortraitRamp.SHADOW])
	c.vline(x + 1, y, y + 3, c.skin[PortraitRamp.SHADOW])


## An arm bent forward at chest height, hand moved by the frame's "hand_" value.
static func _arm_forward(c: BodyPainter, limb: String, sleeve: Array[Color]) -> void:
	var sy: int = shoulder_y(c)
	var dy: int = c.value("hand_" + limb)
	var elbow: Vector2i
	var hand: Vector2i
	var upper: Array[Vector2i]
	if c.direction == "side":
		var reach: int = 0 if limb == "l" else 2
		elbow = Vector2i(CX + 1, 50 + c.up)
		hand = Vector2i(CX + 16 + reach, 46 + c.up + dy)
		upper = [
			Vector2i(CX - 3, sy + 1),
			Vector2i(CX + 3, sy + 1),
			Vector2i(elbow.x + 3, elbow.y + 2),
			Vector2i(elbow.x - 3, elbow.y + 2),
		]
	else:
		var s: int = c.screen_side(limb)
		var back: bool = c.direction == "back"
		elbow = Vector2i(CX + s * (c.shoulder + (5 if back else 3)), 50 + c.up)
		hand = Vector2i(CX + s * (c.shoulder - 3 if back else 6), 47 + c.up + dy)
		upper = [
			Vector2i(CX + s * c.shoulder, sy),
			Vector2i(CX + s * (c.shoulder + 5), sy + 2),
			Vector2i(elbow.x + s * 2, elbow.y + 2),
			Vector2i(elbow.x - s * 4, elbow.y + 2),
		]
	var fore: Array[Vector2i] = [
		Vector2i(elbow.x, elbow.y - 2),
		Vector2i(hand.x, hand.y - 2),
		Vector2i(hand.x, hand.y + 3),
		Vector2i(elbow.x, elbow.y + 3),
	]
	c.shaded(BodyPainter.union(BodyPainter.poly(upper), BodyPainter.poly(fore)), sleeve)
	if c.direction != "back":
		_hand(c, hand.x, hand.y - 1)


## Collar, tie, zipper, straps, vest panels, coat opening, epaulettes and shoulder patch.
static func _details(c: BodyPainter) -> void:
	var variant: String = c.trait_of("variant")
	var sy: int = shoulder_y(c)
	var top: Array[Color] = _top(c)
	var accent_hex: String = PortraitRamp.ACCENTS.get(c.trait_of("field"), BRASS)
	var accent: Array[Color] = PortraitRamp.ramp(accent_hex)
	if variant == "vest":
		_vest(c, accent)
	if c.direction == "back":
		c.hline(CX - 3, CX + 3, sy, top[PortraitRamp.OUTLINE])
		if _coat(c):
			c.vline(CX, waist_y(c), waist_y(c) + 21, top[PortraitRamp.SHADOW])
		return
	if c.direction == "side":
		if variant in PATCHES:
			c.shaded(BodyPainter.rect(CX - 1, sy + 6, CX + 2, sy + 9), accent, 1)
		return
	_front_details(c, variant, accent)


static func _front_details(c: BodyPainter, variant: String, accent: Array[Color]) -> void:
	var sy: int = shoulder_y(c)
	var top: Array[Color] = _top(c)
	if _coat(c):
		var under: String = "#3f6e6a" if c.trait_of("field") == "medicine" else "#2b3340"
		var v: Array[Vector2i] = [
			Vector2i(CX - 5, sy), Vector2i(CX + 1, sy + 18), Vector2i(CX + 6, sy)
		]
		c.shaded(BodyPainter.poly(v), PortraitRamp.ramp(under), 1)
		c.vline(CX, sy + 18, waist_y(c) + 21, top[PortraitRamp.SHADOW])
	elif variant in TIES:
		var v: Array[Vector2i] = [
			Vector2i(CX - 4, sy), Vector2i(CX + 1, sy + 10), Vector2i(CX + 5, sy)
		]
		c.shaded(BodyPainter.poly(v), PortraitRamp.ramp(SHIRT, 0.5), 1)
		var tie_hex: String = "#7a2e24" if variant == "shirt_tie" else "#262a22"
		if c.trait_of("field") == "office" and variant != "shirt_tie":
			tie_hex = PortraitRamp.ACCENTS["office"]
		c.vline(CX, sy + 1, sy + 14, PortraitRamp.ramp(tie_hex)[PortraitRamp.SHADOW])
	elif variant == "scrubs" or variant == "sweater":
		var v: Array[Vector2i] = [
			Vector2i(CX - 4, sy), Vector2i(CX + 1, sy + 6), Vector2i(CX + 5, sy)
		]
		c.shaded(BodyPainter.poly(v), c.skin, 1)
	if variant in ZIPS:
		c.vline(CX, sy + 2, waist_y(c) - 4, top[PortraitRamp.OUTLINE])
	if variant == "expedition" or variant == "overalls":
		for s: int in [-1, 1]:
			c.vline(CX + s * 7, sy + 1, waist_y(c) - 4, top[PortraitRamp.OUTLINE])
	if variant == "officer" or variant == "command":
		for s: int in [-1, 1]:
			c.hline(CX + s * (c.shoulder - 3), CX + s * (c.shoulder - 1), sy + 1, accent[3])
	if variant in PATCHES:
		var x: int = CX - c.shoulder - 4
		c.shaded(BodyPainter.rect(x, sy + 7, x + 3, sy + 10), accent, 1)


static func _vest(c: BodyPainter, accent: Array[Color]) -> void:
	var sy: int = shoulder_y(c)
	var bottom: int = waist_y(c) - 4
	if c.direction == "side":
		c.shaded(BodyPainter.rect(CX - c.depth + 2, sy + 2, CX + c.depth - 2, bottom), accent, 1)
		return
	if c.direction == "back":
		c.shaded(BodyPainter.rect(CX - c.hip + 1, sy + 2, CX + c.hip - 1, bottom), accent, 1)
		return
	for s: int in [-1, 1]:
		var inner: int = CX + s * 3
		var outer: int = CX + s * (c.hip - 1)
		c.shaded(
			BodyPainter.rect(mini(inner, outer), sy + 2, maxi(inner, outer), bottom), accent, 1
		)
