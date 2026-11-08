## Tests for InjuryRules and StaffCareSystem's recovery: light 2 days and serious 8 at 1x, 2x in
## an Infirmary that is on with room (4 patients), 3x with a medic at work in it; the injured
## are off work and go back to their rooms healed; the save keeps injuries.
## Bible: docs/content/m3-beyond-the-ring.md section 4
extends GdUnitTestSuite

const DAY: int = TimeMath.TICKS_PER_DAY

var _game: GameState
var _system: StaffCareSystem


func before_test() -> void:
	_game = ConstructionFixture.grown()
	_system = StaffCareSystem.new()


func _person(role: StringName = StartingStaff.ENGINEER) -> PersonState:
	var person := PersonState.new()
	person.name = "Test %d" % _game.staff.next_person_number
	person.role = role
	person.skill = 3
	return _game.staff.add_person(person)


func _infirmary(on: bool = true) -> RoomState:
	var room: RoomState = _game.base.add_room(ExpeditionUnlock.INFIRMARY_DEF, 2, Vector2i(4, 16))
	room.powered_on = on
	return room


## Ticks until [param person] heals; returns the ticks taken.
func _ticks_to_heal(person: PersonState) -> int:
	var ticks: int = 0
	while person.is_injured() and ticks < 20 * DAY:
		_system.tick(_game)
		_game.clock.tick += 1
		ticks += 1
	return ticks


func test_light_heals_in_2_days_at_rest() -> void:
	var person: PersonState = _person()
	InjuryRules.injure(person, PersonState.Injury.LIGHT)
	assert_int(_ticks_to_heal(person)).is_equal(2 * DAY)
	assert_bool(person.is_injured()).is_false()


func test_serious_heals_in_8_days_at_rest() -> void:
	var person: PersonState = _person()
	InjuryRules.injure(person, PersonState.Injury.SERIOUS)
	assert_int(InjuryRules.check_skill(person)).is_equal(1)
	assert_int(_ticks_to_heal(person)).is_equal(8 * DAY)


func test_infirmary_on_doubles_and_medic_triples() -> void:
	var room: RoomState = _infirmary()
	var person: PersonState = _person()
	InjuryRules.injure(person, PersonState.Injury.SERIOUS)
	assert_int(_ticks_to_heal(person)).is_equal(4 * DAY)
	StaffFixture.assign(_game, room, StartingStaff.MEDIC, [2])
	InjuryRules.injure(person, PersonState.Injury.LIGHT)
	assert_int(_ticks_to_heal(person)).is_equal(ceili(2.0 * DAY / 3))


func test_switched_off_infirmary_is_rest() -> void:
	_infirmary(false)
	var person: PersonState = _person()
	InjuryRules.injure(person, PersonState.Injury.LIGHT)
	assert_int(InjuryRules.speeds(_game)[person.id]).is_equal(1)


func test_injured_medic_does_not_count() -> void:
	var room: RoomState = _infirmary()
	var medic: PersonState = StaffFixture.assign(_game, room, StartingStaff.MEDIC, [3])[0]
	InjuryRules.injure(medic, PersonState.Injury.LIGHT)
	assert_int(InjuryRules.speeds(_game)[medic.id]).is_equal(2)


func test_fifth_patient_rests() -> void:
	_infirmary()
	var people: Array[PersonState] = []
	for index: int in 5:
		people.append(_person())
		InjuryRules.injure(people[index], PersonState.Injury.LIGHT)
	var speeds: Dictionary[StringName, int] = InjuryRules.speeds(_game)
	var got: Array[int] = []
	for person: PersonState in people:
		got.append(speeds[person.id])
	assert_array(got).is_equal([2, 2, 2, 2, 1])


func test_away_people_do_not_recover() -> void:
	var person: PersonState = _person()
	InjuryRules.injure(person, PersonState.Injury.LIGHT)
	assert_bool(InjuryRules.speeds(_game, [person.id]).has(person.id)).is_false()


func test_injured_are_off_work_and_return_healed() -> void:
	var lab: RoomState = _game.base.add_room(&"room_research_lab", 3, Vector2i(20, 16))
	var person: PersonState = StaffFixture.assign(_game, lab, StartingStaff.SCIENTIST, [4])[0]
	InjuryRules.injure(person, PersonState.Injury.LIGHT)
	assert_array(StaffRules.working(_game, lab)).is_empty()
	assert_array(StaffRules.assigned(_game, lab)).has_size(1)
	_ticks_to_heal(person)
	assert_array(StaffRules.working(_game, lab)).has_size(1)
	assert_str(String(person.room_id)).is_equal(String(lab.id))
	var names: Array[StringName] = []
	for event: SimEvent in _game.events.drain():
		names.append(event.name)
	assert_array(names).contains([StaffCareSystem.HEALED_EVENT])


func test_injury_survives_a_save() -> void:
	var person: PersonState = _person()
	InjuryRules.injure(person, PersonState.Injury.SERIOUS)
	person.recovery_left = 1234
	var data: Dictionary = JSON.parse_string(JSON.stringify(_game.staff.to_dict()))
	assert_array(StaffState.validate_dict(data)).is_empty()
	var loaded: PersonState = StaffState.from_dict(data).find_person(person.id)
	assert_int(loaded.injury).is_equal(PersonState.Injury.SERIOUS)
	assert_int(loaded.recovery_left).is_equal(1234)
	data["people"][-1]["injury"] = "broken"
	assert_str("; ".join(StaffState.validate_dict(data))).contains("'injury'")
