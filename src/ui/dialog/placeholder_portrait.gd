class_name PlaceholderPortrait
extends PortraitRenderer
## A head-and-shoulders figure drawn in code, until real portraits exist (M4.8-05): skin, hair,
## clothing and accent colours and a build from the PortraitDef, lit with the faction's accent.
## Idle: slow breathing and an occasional blink. Talking: the mouth moves. Mood changes the
## brows, the posture and the tint of the light. A still shows the same figure fixed.
## Bible: docs/content/dialogue-screen.md section 3

## Seconds of one breath.
const BREATH_SECONDS: float = 4.0
## Seconds a blink lasts, and the range of seconds between blinks.
const BLINK_SECONDS: float = 0.14
const BLINK_GAP: Vector2 = Vector2(2.5, 6.0)
## Seconds between mouth shapes while talking.
const MOUTH_STEP: float = 0.09
## Per mood: brow tilt (positive is angry: inward and down), in head-heights.
const TILT: Dictionary[StringName, float] = {
	&"neutral": 0.0, &"pleased": -0.12, &"wary": 0.18, &"angry": 0.45
}
## Per mood: brow lift, in head-heights.
const LIFT: Dictionary[StringName, float] = {
	&"neutral": 0.0, &"pleased": 0.05, &"wary": -0.02, &"angry": -0.06
}
## Per mood: posture, the head's offset in portrait units (leaning back, forward).
const LEAN: Dictionary[StringName, Vector2] = {
	&"neutral": Vector2.ZERO,
	&"pleased": Vector2(0, -0.03),
	&"wary": Vector2(0.05, -0.05),
	&"angry": Vector2(0, 0.06),
}
## Per mood: mouth curve (positive smiles).
const SMILE: Dictionary[StringName, float] = {
	&"neutral": 0.0, &"pleased": 0.6, &"wary": -0.2, &"angry": -0.6
}
## Per mood: the light's tint and how far it pulls the faction accent towards it.
const LIGHT: Dictionary[StringName, Color] = {
	&"neutral": Color(1, 1, 1),
	&"pleased": Color(1.0, 0.85, 0.55),
	&"wary": Color(0.55, 0.75, 1.0),
	&"angry": Color(1.0, 0.35, 0.3),
}
const LIGHT_PULL: Dictionary[StringName, float] = {
	&"neutral": 0.0, &"pleased": 0.25, &"wary": 0.2, &"angry": 0.4
}

var _time: float = 0.0
var _next_blink: float = 3.0
var _blink_left: float = 0.0
var _mouth: float = 0.0
var _mouth_timer: float = 0.0


func _process(delta: float) -> void:
	advance(delta)


## Moves the animation on by [param delta] seconds (tests call it directly).
func advance(delta: float) -> void:
	if animated:
		_time += delta
		_next_blink -= delta
		_blink_left = maxf(_blink_left - delta, 0.0)
		if _next_blink <= 0.0:
			_blink_left = BLINK_SECONDS
			_next_blink = rng.randf_range(BLINK_GAP.x, BLINK_GAP.y)
	if talking:
		_mouth_timer -= delta
		if _mouth_timer <= 0.0:
			_mouth_timer = MOUTH_STEP
			_mouth = rng.randf_range(0.15, 1.0)
	else:
		_mouth = 0.0
	queue_redraw()


## How open the mouth is now, 0 to 1.
func mouth_open() -> float:
	return _mouth


## How far the figure has risen with its breath now, in pixels.
func breath_offset() -> float:
	return sin(_time * TAU / BREATH_SECONDS) * size.y * 0.008 if animated else 0.0


## True while the eyes are shut.
func is_blinking() -> bool:
	return _blink_left > 0.0


func _draw() -> void:
	if def == null or size.x <= 0.0:
		return
	var shown: StringName = mood if TILT.has(mood) else &"neutral"
	_draw_light(shown)
	var unit: float = minf(size.x, size.y)
	var breath: float = breath_offset()
	var centre := Vector2(size.x * 0.5, size.y * 0.42 + breath * 0.6)
	centre += LEAN[shown] * unit
	_draw_shoulders(unit, breath)
	_draw_head(centre, unit, shown)


func _draw_light(shown: StringName) -> void:
	var accent: Color = def.colour("accent", UiPalette.TEXT_DIM)
	var tint: Color = accent.lerp(LIGHT[shown], LIGHT_PULL[shown])
	draw_rect(Rect2(Vector2.ZERO, size), tint.darkened(0.8))
	draw_circle(
		Vector2(size.x * 0.5, size.y * 0.45), minf(size.x, size.y) * 0.42, tint.darkened(0.6)
	)


func _draw_shoulders(unit: float, breath: float) -> void:
	var clothing: Color = def.colour("clothing", Color(0.25, 0.27, 0.3))
	var width: float = unit * lerpf(0.62, 0.9, def.build())
	var top: float = size.y * 0.72 + breath
	var points := PackedVector2Array(
		[
			Vector2(size.x * 0.5 - width * 0.5, size.y),
			Vector2(size.x * 0.5 - width * 0.42, top + unit * 0.05),
			Vector2(size.x * 0.5 - width * 0.18, top - unit * 0.02),
			Vector2(size.x * 0.5 + width * 0.18, top - unit * 0.02),
			Vector2(size.x * 0.5 + width * 0.42, top + unit * 0.05),
			Vector2(size.x * 0.5 + width * 0.5, size.y),
		]
	)
	draw_colored_polygon(points, clothing)
	var neck := Rect2(size.x * 0.5 - unit * 0.06, top - unit * 0.1, unit * 0.12, unit * 0.12)
	draw_rect(neck, def.colour("skin", Color(0.7, 0.55, 0.45)).darkened(0.15))


func _draw_head(centre: Vector2, unit: float, shown: StringName) -> void:
	var skin: Color = def.colour("skin", Color(0.7, 0.55, 0.45))
	var radius := Vector2(unit * 0.16, unit * 0.2)
	draw_set_transform(centre, 0.0, radius / radius.x)
	draw_circle(Vector2.ZERO, radius.x, skin)
	draw_set_transform(Vector2.ZERO)
	var hair: Color = def.colour("hair", Color(0.2, 0.18, 0.16))
	draw_arc(centre, radius.x * 1.1, PI * 1.05, TAU * 0.98, 24, hair, radius.y * 0.3)
	_draw_face(centre, radius, shown)


func _draw_face(centre: Vector2, radius: Vector2, shown: StringName) -> void:
	var dark := Color(0.08, 0.07, 0.07)
	var tilt: float = TILT[shown]
	var lift: float = LIFT[shown] * radius.y * 2.0
	for side: float in [-1.0, 1.0]:
		var eye := centre + Vector2(side * radius.x * 0.4, -radius.y * 0.08)
		if is_blinking():
			draw_line(
				eye - Vector2(radius.x * 0.12, 0), eye + Vector2(radius.x * 0.12, 0), dark, 2.0
			)
		else:
			draw_circle(eye, radius.x * 0.08, dark)
		var inner := (
			eye + Vector2(-side * radius.x * 0.16, -radius.y * 0.2 - lift + tilt * radius.y * 0.2)
		)
		var outer := (
			eye + Vector2(side * radius.x * 0.2, -radius.y * 0.22 - lift - tilt * radius.y * 0.08)
		)
		draw_line(inner, outer, dark, maxf(radius.x * 0.06, 1.5))
	var mouth := centre + Vector2(0, radius.y * 0.5)
	var half: float = radius.x * 0.3
	var curve: float = SMILE[shown] * radius.y * 0.1
	var open: float = _mouth * radius.y * 0.16
	draw_line(mouth + Vector2(-half, -curve), mouth, dark, 2.0)
	draw_line(mouth, mouth + Vector2(half, -curve), dark, 2.0)
	if open > 0.5:
		draw_rect(Rect2(mouth - Vector2(half * 0.6, 0), Vector2(half * 1.2, open)), dark)
