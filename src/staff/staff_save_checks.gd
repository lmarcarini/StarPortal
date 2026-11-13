class_name StaffSaveChecks
extends RefCounted
## Load-time checks of saved ids (card M2.6-05, M2.5 follow-up #178), run by
## GameState.validate_dict() on data whose sections are already valid: the roster against the
## base, and, given the content, every saved def id against the definitions.
## Bible: docs/content/m26-staff-and-money.md section 8, technical-architecture.md#save-system


## Errors of the roster in valid [param data] against its base and clock: a person in a room
## that does not exist, or a person still arriving who has a room.
static func roster_errors(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var base: BaseState = BaseState.from_dict(_section(data, "base"))
	var staff: StaffState = StaffState.from_dict(_section(data, "staff"))
	var now: int = ClockState.from_dict(_section(data, "clock")).tick
	for index: int in staff.people.size():
		var person: PersonState = staff.people[index]
		if not person.is_assigned():
			continue
		if base.find_room(person.room_id) == null:
			errors.append("staff: people %d is in missing room '%s'" % [index, person.room_id])
		if not person.is_on_base(now):
			errors.append("staff: people %d has a room before arriving" % index)
	return errors


## Errors of the ids in valid [param data] against [param defs]: unknown room def ids (rooms
## and auto_assign), unknown research ids (active and done), unknown role ids, and people in a
## room whose slots take another role or more people than it has slots.
static func content_errors(data: Dictionary, defs: GameDefs) -> Array[String]:
	var room_defs: Dictionary[StringName, RoomDef] = {}
	for def: RoomDef in defs.rooms:
		room_defs[def.id] = def
	var base: BaseState = BaseState.from_dict(_section(data, "base"))
	var staff: StaffState = StaffState.from_dict(_section(data, "staff"))
	var errors: Array[String] = []
	for index: int in base.rooms.size():
		if not room_defs.has(base.rooms[index].def_id):
			errors.append("base: rooms %d has unknown def '%s'" % [index, base.rooms[index].def_id])
	for def_id: StringName in staff.auto_assign:
		if not room_defs.has(def_id):
			errors.append("staff: auto_assign has unknown room def '%s'" % def_id)
	errors.append_array(_research_errors(ResearchState.from_dict(_section(data, "research")), defs))
	errors.append_array(_people_errors(staff, base, room_defs, defs))
	return errors


## Research ids the content no longer has are not errors: GameSetup.build() drops them on load
## (M4-29), so an old save still loads.
static func _research_errors(_research: ResearchState, _defs: GameDefs) -> Array[String]:
	return []


static func _people_errors(
	staff: StaffState, base: BaseState, room_defs: Dictionary[StringName, RoomDef], defs: GameDefs
) -> Array[String]:
	var roles: Dictionary[StringName, bool] = {}
	for role: RoleDef in defs.roles:
		roles[role.id] = true
	var errors: Array[String] = []
	var filled: Dictionary[StringName, int] = {}
	for index: int in staff.people.size():
		var person: PersonState = staff.people[index]
		if not roles.has(person.role):
			errors.append("staff: people %d has unknown role '%s'" % [index, person.role])
		var room: RoomState = base.find_room(person.room_id)
		var def: RoomDef = null if room == null else room_defs.get(room.def_id)
		if def == null:
			continue
		if def.staff_role != person.role:
			errors.append("staff: people %d is in a room without %s slots" % [index, person.role])
		filled[room.id] = filled.get(room.id, 0) + 1
		if filled[room.id] == def.staff_slots + 1:
			errors.append("staff: room '%s' holds more people than slots" % room.id)
	return errors


static func _section(data: Dictionary, key: String) -> Dictionary:
	var section: Dictionary = data[key]
	return section
