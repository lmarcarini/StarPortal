class_name FigureSprite
extends RefCounted
## A code-drawn figure (soldier, scientist, intruder) with a four-frame walk cycle, a small
## shadow and an optional blue rim near the horizon. Draws on any CanvasItem; takes a texture
## sheet later when the owner supplies one.
## Bible: docs/content/interface-rethink.md section 2 (Show it happening)

## Figure kinds.
enum Kind { SOLDIER, SCIENTIST, INTRUDER }

## Height at scale 1, in screen pixels at 1080p.
const HEIGHT: float = 64.0
const _BODY: Dictionary[Kind, Color] = {
	Kind.SOLDIER: Color("#4b5a3c"),
	Kind.SCIENTIST: Color("#c9c4b4"),
	Kind.INTRUDER: Color("#5a2a26")
}
const _SKIN: Color = Color("#b48a6a")


## Draws a [param kind] figure as [param pose] says.
static func draw(ci: CanvasItem, kind: Kind, pose: ActorPose) -> void:
	var feet: Vector2 = pose.at
	var alpha: float = pose.alpha
	var h: float = HEIGHT * pose.scale
	var swing: float = sin(pose.phase * 9.0) * h * 0.08
	var body: Color = Color(_BODY[kind], alpha)
	ci.draw_set_transform(feet + Vector2(0, -2), 0.0, Vector2(1.0, 0.3))
	ci.draw_circle(Vector2.ZERO, h * 0.18, Color(0, 0, 0, 0.35 * alpha))
	ci.draw_set_transform(Vector2.ZERO)
	var hip: Vector2 = feet + Vector2(0, -h * 0.45)
	ci.draw_line(hip, feet + Vector2(swing, 0), body.darkened(0.3), h * 0.09)
	ci.draw_line(hip, feet + Vector2(-swing, 0), body.darkened(0.3), h * 0.09)
	var chest: Rect2 = Rect2(hip + Vector2(-h * 0.11, -h * 0.36), Vector2(h * 0.22, h * 0.4))
	ci.draw_rect(chest, body)
	ci.draw_circle(hip + Vector2(0, -h * 0.45), h * 0.08, Color(_SKIN, alpha))
	if pose.rim > 0.0:
		ci.draw_rect(chest.grow(1.5), Color(UiPalette.RING, pose.rim * alpha), false, 2.0)
