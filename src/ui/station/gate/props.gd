class_name Props
extends RefCounted
## Code-drawn props for floor cues: the MOTH, the canister, the pole camera arm and a crate.
## Bible: docs/content/interface-rethink.md section 2 (Show it happening)

## Prop kinds.
enum Kind { MOTH, CANISTER, CAMERA_ARM, CRATE }

const _STEEL: Color = Color("#8e8b80")


## Draws prop [param kind] as [param pose] says (its base at pose.at).
static func draw(ci: CanvasItem, kind: Kind, pose: ActorPose) -> void:
	var at: Vector2 = pose.at
	var alpha: float = pose.alpha
	var scale: float = pose.scale
	var s: float = 24.0 * scale
	var steel: Color = Color(_STEEL, alpha)
	match kind:
		Kind.MOTH:
			var wing: PackedVector2Array = PackedVector2Array(
				[
					at,
					at + Vector2(-s, -s * 0.6),
					at + Vector2(-s * 0.7, s * 0.2),
					at + Vector2(s * 0.7, s * 0.2),
					at + Vector2(s, -s * 0.6)
				]
			)
			ci.draw_colored_polygon(wing, steel)
		Kind.CANISTER:
			ci.draw_rect(
				Rect2(at + Vector2(-s * 0.3, -s), Vector2(s * 0.6, s)),
				Color(Color("#c8a23a"), alpha)
			)
		Kind.CAMERA_ARM:
			ci.draw_line(at, at + Vector2(0, -s * 2.0), steel, 4.0 * scale)
			ci.draw_rect(Rect2(at + Vector2(-s * 0.3, -s * 2.4), Vector2(s * 0.6, s * 0.4)), steel)
		Kind.CRATE:
			var r: Rect2 = Rect2(at + Vector2(-s * 0.6, -s), Vector2(s * 1.2, s))
			ci.draw_rect(r, Color(Color("#7a5a32"), alpha))
			ci.draw_rect(r, Color(0, 0, 0, 0.5 * alpha), false, 2.0)
