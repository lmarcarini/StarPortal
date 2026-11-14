class_name GenericRoomSet
extends RoomSet
## The set for any room without its own: two desks and a cabinet.
## Bible: docs/content/interface-pass.md section 5 (Camera inset)


func _build_props(props: Node3D) -> void:
	props.add_child(SetKit.desk(Vector3(-1.5, 0, -1.6)))
	props.add_child(SetKit.desk(Vector3(1.2, 0, -1.6)))
	props.add_child(SetKit.box(Vector3(0.8, 1.8, 0.5), Vector3(3.3, 0.9, 0.5), SetKit.METAL))
