class_name SteelPanel
extends PanelContainer
## A riveted steel plate (or, recessed, a sunk well) that holds hardware controls.
## Bible: docs/content/interface-rethink.md section 7 (riveted steel plates)

## Whether the plate is sunk instead of raised.
@export var recessed: bool = false:
	set(value):
		recessed = value
		theme_type_variation = &"RecessedPanel" if value else &"SteelPanel"


func _init() -> void:
	theme_type_variation = &"SteelPanel"
