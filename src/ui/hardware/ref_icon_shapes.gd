class_name RefIconShapes
extends RefCounted
## The strokes of each reference icon, in half-size units (tools/reference/render_ref.py
## draw_icon). Pure drawing.
## Bible: docs/content/interface-reference.md section 3 (Icons)


## Every icon, as {id: Callable(pen: RefPen)}.
static func drawers() -> Dictionary[StringName, Callable]:
	return {
		&"gate": gate,
		&"down": down,
		&"base": base,
		&"lab": lab,
		&"office": office,
		&"funds": funds,
		&"power": power,
		&"charge": charge,
		&"confidence": confidence,
		&"phone": phone,
		&"clock": clock,
		&"pause": pause,
		&"play": play,
		&"fast": fast,
		&"gear": gear,
		&"eye": eye,
		&"person": person,
		&"threat": threat,
		&"arrow": arrow,
		&"check": check,
		&"cross": cross,
		&"plus": plus,
		&"list": list,
		&"candidate": person,
		&"camera": camera,
		&"canister": canister,
		&"moth": moth,
		&"team": team,
		&"hail": hail,
		&"specimen": specimen,
	}


static func gate(p: RefPen) -> void:
	p.ellipse(Vector2(-1, -1), Vector2(1, 1))
	p.ellipse(Vector2(-0.62, -0.62), Vector2(0.62, 0.62))
	for a: int in range(0, 360, 45):
		var t: float = deg_to_rad(a)
		p.line([Vector2(sin(t), -cos(t)) * 0.62, Vector2(sin(t), -cos(t))])


static func base(p: RefPen) -> void:
	p.box(Vector2(-1, -0.2), Vector2(1, 1))
	p.line([Vector2(-1, -0.2), Vector2(0, -1), Vector2(1, -0.2)])
	p.box(Vector2(-0.3, 0.3), Vector2(0.3, 1))


static func lab(p: RefPen) -> void:
	p.line([Vector2(-0.35, -1), Vector2(0.35, -1)])
	p.line(
		[
			Vector2(-0.2, -1),
			Vector2(-0.2, -0.2),
			Vector2(-1, 1),
			Vector2(1, 1),
			Vector2(0.2, -0.2),
			Vector2(0.2, -1)
		]
	)
	p.line([Vector2(-0.6, 0.35), Vector2(0.6, 0.35)])


static func office(p: RefPen) -> void:
	p.box(Vector2(-1, -0.5), Vector2(1, 1))
	p.line([Vector2(-1, -0.5), Vector2(-0.6, -1), Vector2(-0.05, -1), Vector2(0.2, -0.5)])


static func funds(p: RefPen) -> void:
	var style: RefText = RefText.make(RefText.LABEL, roundi(p.r * 2.2), p.ink)
	style.draw(p.item, p.c, "$", "mm")


static func power(p: RefPen) -> void:
	p.fill(
		[
			Vector2(0.15, -1),
			Vector2(-0.55, 0.1),
			Vector2(-0.05, 0.1),
			Vector2(-0.2, 1),
			Vector2(0.55, -0.15),
			Vector2(0.05, -0.15)
		]
	)


static func charge(p: RefPen) -> void:
	p.box(Vector2(-0.75, -0.55), Vector2(0.6, 0.55))
	p.solid(Vector2(0.6, -0.2), Vector2(0.85, 0.2))
	p.solid(Vector2(-0.55, -0.35), Vector2(0.15, 0.35))


static func confidence(p: RefPen) -> void:
	p.shape(
		[
			Vector2(-0.8, -0.7),
			Vector2(0.8, -0.7),
			Vector2(0.8, 0.1),
			Vector2(0, 1),
			Vector2(-0.8, 0.1)
		]
	)
	p.line([Vector2(-0.35, -0.05), Vector2(-0.05, 0.3), Vector2(0.4, -0.35)])


static func phone(p: RefPen) -> void:
	var w: float = p.width
	p.width = w + 3.0
	p.arc(Vector2(-1, -0.4), Vector2(1, 1.2), 200, 340)
	p.width = w
	p.box(Vector2(-0.65, -0.05), Vector2(0.65, 1))


static func clock(p: RefPen) -> void:
	p.ellipse(Vector2(-1, -1), Vector2(1, 1))
	p.line([Vector2(0, 0), Vector2(0, -0.6)])
	p.line([Vector2(0, 0), Vector2(0.45, 0.2)])


## A specimen jar: lid, body and a sprig inside.
static func specimen(p: RefPen) -> void:
	p.box(Vector2(-0.5, -1), Vector2(0.5, -0.7))
	p.box(Vector2(-0.7, -0.7), Vector2(0.7, 1))
	p.line([Vector2(0, 0.7), Vector2(0, -0.2)])
	p.line([Vector2(0, 0.2), Vector2(-0.35, -0.1)])
	p.line([Vector2(0, 0.0), Vector2(0.35, -0.3)])


static func pause(p: RefPen) -> void:
	p.solid(Vector2(-0.55, -0.7), Vector2(-0.15, 0.7))
	p.solid(Vector2(0.15, -0.7), Vector2(0.55, 0.7))


static func play(p: RefPen) -> void:
	p.fill([Vector2(-0.45, -0.7), Vector2(0.6, 0), Vector2(-0.45, 0.7)])


static func fast(p: RefPen) -> void:
	p.fill([Vector2(-0.8, -0.6), Vector2(0, 0), Vector2(-0.8, 0.6)])
	p.fill([Vector2(0, -0.6), Vector2(0.8, 0), Vector2(0, 0.6)])


static func gear(p: RefPen) -> void:
	for a: int in range(0, 360, 45):
		var t: float = deg_to_rad(a)
		p.line([Vector2(cos(t), sin(t)) * 0.55, Vector2(cos(t), sin(t))])
	p.ellipse(Vector2(-0.62, -0.62), Vector2(0.62, 0.62))
	p.ellipse(Vector2(-0.22, -0.22), Vector2(0.22, 0.22))


static func eye(p: RefPen) -> void:
	p.arc(Vector2(-1, -0.9), Vector2(1, 0.9), 200, 340)
	p.arc(Vector2(-1, -0.9), Vector2(1, 0.9), 20, 160)
	p.item.draw_circle(p.c, p.r * 0.25, p.ink)


static func person(p: RefPen) -> void:
	p.ellipse(Vector2(-0.35, -1), Vector2(0.35, -0.3))
	p.arc(Vector2(-0.75, -0.1), Vector2(0.75, 1.6), 180, 360)


static func threat(p: RefPen) -> void:
	p.shape([Vector2(0, -1), Vector2(1, 0.8), Vector2(-1, 0.8)])
	p.line([Vector2(0, -0.3), Vector2(0, 0.25)])
	p.item.draw_circle(p.at(0, 0.52), 2.0, p.ink)


static func arrow(p: RefPen) -> void:
	p.line([Vector2(-0.7, 0), Vector2(0.7, 0)])
	p.line([Vector2(0.2, -0.5), Vector2(0.7, 0), Vector2(0.2, 0.5)])


static func check(p: RefPen) -> void:
	p.line([Vector2(-0.7, 0), Vector2(-0.15, 0.55), Vector2(0.75, -0.55)])


static func cross(p: RefPen) -> void:
	p.line([Vector2(-0.6, -0.6), Vector2(0.6, 0.6)])
	p.line([Vector2(-0.6, 0.6), Vector2(0.6, -0.6)])


static func plus(p: RefPen) -> void:
	p.line([Vector2(-0.7, 0), Vector2(0.7, 0)])
	p.line([Vector2(0, -0.7), Vector2(0, 0.7)])


static func list(p: RefPen) -> void:
	for k: float in [-0.5, 0.0, 0.5]:
		p.line([Vector2(-0.7, k), Vector2(0.7, k)])


static func camera(p: RefPen) -> void:
	p.box(Vector2(-1, -0.55), Vector2(0.45, 0.55))
	p.line([Vector2(0.45, -0.2), Vector2(1, -0.5), Vector2(1, 0.5), Vector2(0.45, 0.2)])
	p.ellipse(Vector2(-0.55, -0.3), Vector2(0.05, 0.3))


static func canister(p: RefPen) -> void:
	p.box(Vector2(-0.45, -1), Vector2(0.45, 1))
	p.line([Vector2(-0.45, -0.35), Vector2(0.45, -0.35)])
	p.line([Vector2(-0.45, 0.35), Vector2(0.45, 0.35)])


static func moth(p: RefPen) -> void:
	p.line([Vector2(0, -0.6), Vector2(0, 0.8)])
	p.shape([Vector2(0, -0.2), Vector2(-1, -0.7), Vector2(-0.75, 0.35), Vector2(0, 0.15)])
	p.shape([Vector2(0, -0.2), Vector2(1, -0.7), Vector2(0.75, 0.35), Vector2(0, 0.15)])


static func team(p: RefPen) -> void:
	for dx: float in [-0.45, 0.45]:
		p.ellipse(Vector2(dx - 0.28, -0.85), Vector2(dx + 0.28, -0.3))
		p.arc(Vector2(dx - 0.55, -0.1), Vector2(dx + 0.55, 1.5), 180, 360)


static func hail(p: RefPen) -> void:
	p.arc(Vector2(-1, -1), Vector2(1, 1), 200, 340)
	p.arc(Vector2(-0.6, -0.6), Vector2(0.6, 0.6), 200, 340)
	p.ellipse(Vector2(-0.18, -0.05), Vector2(0.18, 0.3))
	p.line([Vector2(0, 0.3), Vector2(0, 1)])


static func down(p: RefPen) -> void:
	p.line([Vector2(0, -0.7), Vector2(0, 0.7)])
	p.line([Vector2(-0.5, 0.2), Vector2(0, 0.7), Vector2(0.5, 0.2)])
