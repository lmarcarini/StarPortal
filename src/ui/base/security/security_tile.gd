class_name SecurityTile
extends Button
## A tile of the SECURITY tray (M6-06, BUILD's card layout): a squad (shield icon, "SQUAD 1",
## soldiers standing over total in amber, its order dim) or a blast door (door icon, "DOOR L1",
## its cell, OPEN or SEALED). The picked squad and a sealed door are outlined amber.
## Bible: docs/content/interface-reference.md section 8

var icon_id: StringName = &"threat"
var title: String = ""
var value: String = ""
var detail: String = ""
var lit: bool = false


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = RoomCardKey.SIZE
	RefKeyLook.clear_boxes(self)
	add_theme_color_override(&"font_color", Color(0, 0, 0, 0))
	for event: Signal in [focus_entered, focus_exited, mouse_entered, mouse_exited]:
		event.connect(queue_redraw)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_polygon(RefPaint.rounded(rect, 4.0), [Color8(40, 41, 36)])
	RefPaint.outline(self, rect, RefPaint.AMBER if lit else RefPaint.EDGE, 3.0 if lit else 2.0)
	var ink: Color = RefPaint.DIM if disabled else RefPaint.TEXT
	RefIcons.draw(
		self, icon_id, Rect2(size.x * 0.5 - 16, 18, 32, 32), RefPaint.AMBER if lit else ink
	)
	RefText.make(RefText.LABEL, 15, ink, 1.0).draw(self, Vector2(size.x * 0.5, 68), title, "mm")
	RefText.make(RefText.MONO_BOLD, 15, RefPaint.AMBER).draw(
		self, Vector2(size.x * 0.5, 90), value, "mm"
	)
	RefText.make(RefText.MONO, 13, RefPaint.DIM).draw(
		self, Vector2(size.x * 0.5, 110), detail, "mm"
	)
	if is_hovered() and not disabled:
		draw_polygon(RefPaint.rounded(rect, 4.0), [Color(1, 1, 1, 0.05)])
	if has_focus():
		RefPaint.outline(self, rect.grow(3.0), RefPaint.AMBER_HI, 2.0)
