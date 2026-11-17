class_name RefKeyLook
extends RefCounted
## The interface reference's look for an IconKey: a steel key (READY steel, ACTIVE lit, USED
## and UNAVAILABLE off) or a key printed on paper (ACTIVE amber paper), an icon over the
## label, and the badge as a paper disc at the top right corner.
## Bible: docs/content/interface-reference.md sections 3 and 5 (send rail, mission sheet)

const _STYLES: Dictionary[int, RefPaint.KeyStyle] = {
	0: RefPaint.KeyStyle.STEEL,
	1: RefPaint.KeyStyle.LIT,
	2: RefPaint.KeyStyle.OFF,
	3: RefPaint.KeyStyle.OFF,
}


## Removes the theme's boxes from [param key] (it draws itself).
static func clear_boxes(key: Button) -> void:
	for box: StringName in [
		&"normal", &"hover", &"pressed", &"disabled", &"focus", &"hover_pressed"
	]:
		key.add_theme_stylebox_override(box, StyleBoxEmpty.new())


## Draws [param key] (state [param state]) on paper when [param paper], else in steel.
static func draw(key: IconKey, paper: bool, state: int) -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, key.size)
	var ink: Color = _paper(key, rect, state) if paper else RefPaint.key(key, rect, _STYLES[state])
	if key.is_hovered() and not key.disabled:
		key.draw_polygon(RefPaint.rounded(rect, 6.0), [Color(1, 1, 1, 0.06)])
	var text: String = key.tr(key.label)
	var side: float = minf(key.size.x, key.size.y) * (0.36 if paper else 0.42)
	var cy: float = key.size.y * (0.36 if paper else 0.40)
	if text.is_empty():
		cy = key.size.y * 0.5
	var box: Rect2 = Rect2(
		Vector2(key.size.x * 0.5, cy) - Vector2(side, side) * 0.5, Vector2(side, side)
	)
	RefIcons.draw(key, key.icon_id, box, ink)
	var style: RefText = RefText.make(RefText.LABEL, key.label_size, ink, 1.0 if paper else 2.0)
	style.draw(key, Vector2(key.size.x * 0.5, key.size.y - (12.0 if paper else 14.0)), text, "ms")
	if not key.badge_text.is_empty():
		_badge(key, key.badge_text)
	if key.has_focus():
		RefPaint.outline(key, rect.grow(3.0), RefPaint.AMBER_HI, 2.0)


static func _paper(key: IconKey, rect: Rect2, state: int) -> Color:
	var active: bool = state == IconKey.KeyState.ACTIVE
	var fill: Color = Color8(250, 226, 170) if active else Color8(250, 246, 232)
	key.draw_polygon(RefPaint.rounded(rect, 6.0), [fill])
	var edge: Color = Color8(150, 96, 22) if active else Color8(150, 140, 116)
	RefPaint.outline(key, rect, edge, 3.0 if active else 2.0)
	if state == IconKey.KeyState.UNAVAILABLE:
		return Color(RefPaint.INK, 0.35)
	return RefPaint.INK


static func _badge(key: IconKey, text: String) -> void:
	var centre: Vector2 = Vector2(key.size.x - 10.0, 4.0)
	key.draw_circle(centre, 15.0, RefPaint.EDGE)
	key.draw_circle(centre, 13.0, RefPaint.PAPER)
	RefText.make(RefText.MONO_BOLD, 15, RefPaint.INK).draw(key, centre, text, "mm")
