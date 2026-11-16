class_name CrtMonitor
extends PanelContainer
## A green CRT screen with a thick bezel and scanlines drawn over whatever it holds. Labels
## inside take the phosphor green.
## Bible: docs/content/interface-rethink.md section 7 (green CRT)


func _init() -> void:
	theme_type_variation = &"CrtScreen"
	add_theme_color_override(&"font_color", UiThemeHardware.CRT_GREEN)


func _ready() -> void:
	var lines: _Scanlines = _Scanlines.new()
	lines.name = "Scanlines"
	add_child(lines)


func _notification(what: int) -> void:
	if what == NOTIFICATION_CHILD_ORDER_CHANGED and is_node_ready():
		var lines: Node = get_node_or_null("Scanlines")
		if lines != null and lines.get_index() != get_child_count() - 1:
			move_child.call_deferred(lines, -1)


## Scanlines over the screen's contents.
class _Scanlines:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 1

	func _draw() -> void:
		var y: float = 0.0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.22), 1.0)
			y += 3.0
