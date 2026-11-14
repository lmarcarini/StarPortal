class_name ControlRoomSet
extends RoomSet
## The Control Room: a row of consoles facing a window onto the Gate Room.
## Bible: docs/content/interface-pass.md section 5 (Camera inset)


func _init() -> void:
	super()
	room_size = Vector2(9, 6)


func _build_props(props: Node3D) -> void:
	for x: float in [-2.6, 0.0, 2.6]:
		props.add_child(SetKit.console(Vector3(x, 0, -2.2)))
	var window := SetKit.box(Vector3(7.0, 1.0, 0.05), Vector3(0, 2.0, -2.9), Color("#203040"), true)
	window.name = &"Window"
	props.add_child(window)
	props.add_child(SetKit.desk(Vector3(0, 0, 0.6)))
