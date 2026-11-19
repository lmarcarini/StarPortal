class_name StaffDragLine
extends Control
## The dashed amber line of a STAFF drag (interface-reference.md section 8): from the face tile
## being dragged to the pointer, with an amber ring on the slot under it. Drawn over the whole
## Base view; never takes the mouse. One per view; [method begin] finds it from the tile.
## Bible: docs/content/interface-reference.md section 8

const GROUP: StringName = &"staff_drag_line"

var _from: Control = null
var _to: Vector2 = Vector2.ZERO
var _fixed: bool = false


func _init() -> void:
	name = &"StaffDragLine"
	z_index = 3
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(GROUP)


## Starts a line from [param tile] (its drag began).
static func begin(tile: Control) -> void:
	for node: Node in tile.get_tree().get_nodes_in_group(GROUP):
		(node as StaffDragLine).follow(tile)


## Follows the pointer from [param tile].
func follow(tile: Control) -> void:
	_from = tile
	_fixed = false


## Shows a still line from [param tile] to global point [param to] (screenshots, tests).
func show_line(tile: Control, to: Vector2) -> void:
	_from = tile
	_to = to
	_fixed = true
	queue_redraw()


## The tile shown now for the same person as [param old] (the tray rebuilds its tiles).
func _current_tile(old: Control) -> Control:
	var id: StringName = (old as StaffFaceKey).person_id if old is StaffFaceKey else &""
	for node: Node in get_parent().find_children("*", "StaffFaceKey", true, false):
		if (node as StaffFaceKey).person_id == id and node.is_inside_tree():
			return node as Control
	return null


## True while a line shows.
func is_showing() -> bool:
	return _from != null


func _process(_delta: float) -> void:
	if _from == null:
		return
	if not _fixed:
		if not get_viewport().gui_is_dragging():
			_from = null
		else:
			_to = get_global_mouse_position()
	queue_redraw()


func _draw() -> void:
	if _from == null or not is_instance_valid(_from):
		return
	if not _from.is_inside_tree():
		_from = _current_tile(_from)
		if _from == null:
			return
	var a: Vector2 = _from.get_global_rect().get_center() - global_position
	var b: Vector2 = _to - global_position
	draw_dashed_line(a, b, RefPaint.AMBER, 3.0, 12.0)
	draw_arc(b, 11.0, 0.0, TAU, 24, RefPaint.AMBER, 3.0, true)
