class_name StationConsole
extends Control
## The console plate of every station but the Gate (interface-reference.md section 4,
## station_console): a steel plate where that station's own controls go when its phase
## rebuilds it. Empty until then.
## Bible: docs/content/interface-reference.md section 4


func _init() -> void:
	name = &"StationConsole"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	RefPaint.steel_plate(self, Rect2(Vector2.ZERO, size), false, true)
