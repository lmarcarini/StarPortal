class_name ThreeColumn
extends HBoxContainer
## The shared layout of management screens: choose on the left, the board in the centre,
## the selection and its actions on the right. Put on a screen's columns container whose
## children are the board then the detail; it adds the left column in front of them.
## Widths are 240 and 360 px at 1080p, times the UI scale.
## Bible: docs/content/interface-pass.md section 4

## Left and right column widths at 100% UI scale.
const LEFT_WIDTH: float = 240.0
const DETAIL_WIDTH: float = 360.0

## The left column: lists, filters, sub-tabs.
var left := VBoxContainer.new()


func _init() -> void:
	left.name = &"Left"
	left.add_theme_constant_override(&"separation", 8)
	add_child(left)


func _ready() -> void:
	move_child(left, 0)
	Settings.setting_changed.connect(_on_setting_changed)
	_apply_widths()


func _exit_tree() -> void:
	if Settings.setting_changed.is_connected(_on_setting_changed):
		Settings.setting_changed.disconnect(_on_setting_changed)


## The centre column (the board).
func board() -> Control:
	return get_child(1) as Control


## The right column (selection and actions).
func detail() -> Control:
	return get_child(2) as Control


## Moves [param controls] into the left column, in order.
func put_left(controls: Array[Control]) -> void:
	for control: Control in controls:
		if control.get_parent() != null:
			control.get_parent().remove_child(control)
		left.add_child(control)


func _apply_widths() -> void:
	var scale: float = Settings.get_float(&"display", &"ui_scale")
	left.custom_minimum_size.x = LEFT_WIDTH * scale
	if get_child_count() > 2:
		detail().custom_minimum_size.x = DETAIL_WIDTH * scale


func _on_setting_changed(section: StringName, key: StringName, _value: Variant) -> void:
	if section == &"display" and key == &"ui_scale":
		_apply_widths()
