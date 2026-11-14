class_name StaffToken
extends RefCounted
## One person on the base plan: a small token whose shape and letter give the role
## (scientist circle S, engineer square E, analyst triangle A, soldier diamond G, medic cross
## M), at a position in plan pixels on a level. Data and drawing only; the layer places it.
## Bible: docs/content/interface-pass.md section 5 (Staff tokens)

## Radius in plan pixels.
const RADIUS: float = 5.5

## The person.
var person_id: StringName = &""
## Display name and role id.
var name: String = ""
var role: StringName = &""
## Room the person works in, &"" when unassigned.
var room_id: StringName = &""
## Level the token stands on.
var level: int = 1
## Position in plan pixels (the plan's own canvas, before zoom and pan).
var position: Vector2 = Vector2.ZERO
## Where the token belongs (walkers move [member position] toward it).
var home: Vector2 = Vector2.ZERO


## The shape of [param role]: circle, square, triangle, diamond or cross.
static func shape_of(role: StringName) -> StringName:
	match role:
		&"role_scientist":
			return &"circle"
		&"role_engineer":
			return &"square"
		&"role_analyst":
			return &"triangle"
		&"role_soldier":
			return &"diamond"
		&"role_medic":
			return &"cross"
	return &"circle"


## The letter of [param role].
static func letter_of(role: StringName) -> String:
	match role:
		&"role_scientist":
			return "S"
		&"role_engineer":
			return "E"
		&"role_analyst":
			return "A"
		&"role_soldier":
			return "G"
		&"role_medic":
			return "M"
	return "?"


## Draws [param token] on [param canvas] (plan pixels); [param lit] draws it selected.
static func draw(canvas: CanvasItem, token: StaffToken, font: Font, lit: bool) -> void:
	var at: Vector2 = token.position
	var r: float = RADIUS
	var fill: Color = UiPalette.SELECT if lit else UiPalette.TEXT
	var ink: Color = UiPalette.GROUND
	match shape_of(token.role):
		&"square":
			canvas.draw_rect(Rect2(at - Vector2(r, r) * 0.9, Vector2(r, r) * 1.8), fill)
		&"triangle":
			var tri := PackedVector2Array(
				[
					at + Vector2(0, -r * 1.15),
					at + Vector2(r * 1.1, r * 0.8),
					at + Vector2(-r * 1.1, r * 0.8)
				]
			)
			canvas.draw_colored_polygon(tri, fill)
		&"diamond":
			var diamond := PackedVector2Array(
				[
					at + Vector2(0, -r * 1.2),
					at + Vector2(r * 1.2, 0),
					at + Vector2(0, r * 1.2),
					at + Vector2(-r * 1.2, 0)
				]
			)
			canvas.draw_colored_polygon(diamond, fill)
		&"cross":
			canvas.draw_rect(Rect2(at - Vector2(r * 0.4, r), Vector2(r * 0.8, r * 2)), fill)
			canvas.draw_rect(Rect2(at - Vector2(r, r * 0.4), Vector2(r * 2, r * 0.8)), fill)
		_:
			canvas.draw_circle(at, r, fill)
	var size: int = 8
	var text: String = letter_of(token.role)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(font, at + Vector2(-width / 2.0, size * 0.36), text, 0, -1, size, ink)
