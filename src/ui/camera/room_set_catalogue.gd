class_name RoomSetCatalogue
extends RefCounted
## Which camera set each room type uses; the generic set for any room without its own.
## Bible: docs/content/interface-pass.md section 5 (Camera inset)


## A new set for a room of [param def_id].
static func for_room(def_id: StringName) -> RoomSet:
	match def_id:
		&"room_gate":
			return GateRoomSet.new()
		&"room_control":
			return ControlRoomSet.new()
	return GenericRoomSet.new()


## True when [param def_id] has a set of its own.
static func has_own_set(def_id: StringName) -> bool:
	return def_id == &"room_gate" or def_id == &"room_control"
