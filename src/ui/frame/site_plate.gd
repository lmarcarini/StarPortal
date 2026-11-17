class_name SitePlate
extends Control
## The top bar's first plate: the Ring icon, SITE CAIRN and the programme line.
## Bible: docs/content/interface-reference.md section 4 (top_site)


func _init() -> void:
	name = &"SitePlate"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _draw() -> void:
	RefPaint.steel_plate(self, Rect2(Vector2.ZERO, size), false, true)
	RefIcons.draw(self, &"gate", Rect2(19, 13, 34, 34), RefPaint.AMBER)
	var title: RefText = RefText.make(RefText.LABEL, 28, RefPaint.TEXT, 3.0)
	title.draw(self, Vector2(66, 9), tr(&"FRAME_SITE_TITLE"))
	var line: RefText = RefText.make(RefText.LABEL_MEDIUM, 15, RefPaint.DIM, 2.0)
	line.draw(self, Vector2(67, 41), tr(&"FRAME_SITE_LINE"))
