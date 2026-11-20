class_name StaffEffect
extends RefCounted
## What assigning a person changes, for the Assign… list of the Personnel tab
## (docs/content/m26-staff-and-money.md section 6): "speed 100% to 150%" for a Research Lab,
## "building +22% to +27%" for a Workshop, "" for any other room or a person already there. Read
## from ResearchRules and BuildSpeed; pure, never changes the state.
## Bible: docs/content/m26-staff-and-money.md sections 3 and 6


## The effect line of assigning [param person] to [param room] in [param state], or "".
static func of_assign(state: GameState, room: RoomState, person: PersonState) -> String:
	if person.room_id == room.id:
		return ""
	var gain: int = person.skill
	var leaving: RoomState = state.base.find_room(person.room_id)
	if leaving != null and leaving.def_id == room.def_id:
		gain = 0
	if room.def_id == ResearchRules.LAB_DEF:
		var skill: int = ResearchSpeed.skill(state, room)
		if leaving == room:
			return ""
		return _line(&"STAFF_EFFECT_SPEED", _speed(skill), _speed(skill + person.skill))
	match room.def_id:
		BuildSpeed.WORKSHOP_DEF:
			var crew: int = _engineer_skill(state)
			return _line(&"STAFF_EFFECT_BUILD", _bonus(crew), _bonus(crew + gain))
	return ""


static func _speed(skill: int) -> int:
	if skill <= 0:
		return 0
	var rate: int = clampi(
		ResearchSpeed.SPEED_PER_SKILL * skill, ResearchSpeed.MIN_SPEED, ResearchSpeed.MAX_SPEED
	)
	return rate * 100 / ResearchSpeed.SPEED_DENOMINATOR


static func _bonus(skill: int) -> int:
	var bonus: int = mini(
		BuildSpeed.MAX_BONUS, BuildSpeed.EMPTY_BONUS + BuildSpeed.BONUS_PER_SKILL * skill
	)
	return bonus * 100 / BuildSpeed.DENOMINATOR


static func _engineer_skill(state: GameState) -> int:
	var total: int = 0
	for room: RoomState in state.base.rooms:
		if room.def_id == BuildSpeed.WORKSHOP_DEF and PowerRules.is_standing(room):
			for person: PersonState in StaffRules.assigned(state, room):
				total += person.skill
	return total


static func _line(key: StringName, before: int, after: int) -> String:
	return TranslationServer.translate(key).format({"before": before, "after": after})
