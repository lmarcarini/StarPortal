## The M4c save shapes (M4c-02): each new state round-trips through JSON, rejects bad data,
## and the shapes load identically after a save.
## Bible: docs/content/m4c-incursions.md section 9
extends GdUnitTestSuite


func _json(data: Dictionary) -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	return parsed


func _sample_incursion() -> IncursionState:
	var unit := UnitState.new()
	unit.unit = &"unit_raider"
	unit.health = 7
	unit.pos = Vector3i(12, 4, 1)
	var group := IntruderGroup.new()
	group.units.append(unit)
	group.target_room = &"room_3"
	group.last_seen = Vector3i(11, 4, 1)
	var state := IncursionState.new()
	state.phase = IncursionState.Phase.BREACH
	state.def_id = &"incursion_test_raid"
	state.groups.append(group)
	state.last_day[&"faction_kindred"] = 12
	return state


func test_incursion_round_trip_and_checks() -> void:
	var data: Dictionary = _json(_sample_incursion().to_dict())
	assert_array(IncursionState.validate_dict(data)).is_empty()
	assert_dict(_json(IncursionState.from_dict(data).to_dict())).is_equal(data)
	data["phase"] = "attack"
	assert_array(IncursionState.validate_dict(data)).is_not_empty()
	data = _json(_sample_incursion().to_dict())
	var groups: Array = data["groups"]
	var group: Dictionary = groups[0]
	group["last_seen"] = [1, 2]
	assert_array(IncursionState.validate_dict(data)).is_not_empty()


func test_security_round_trip_and_checks() -> void:
	var squad := SquadState.new()
	squad.post_room = &"room_7"
	squad.order = SquadState.Order.MOVE
	squad.target = Vector3i(3, 4, 2)
	var security := SecurityState.new()
	security.squads.append(squad)
	security.health[&"person_2"] = 4
	var data: Dictionary = _json(security.to_dict())
	assert_array(SecurityState.validate_dict(data)).is_empty()
	assert_dict(_json(SecurityState.from_dict(data).to_dict())).is_equal(data)
	security.squads.append(squad)
	assert_array(SecurityState.validate_dict(_json(security.to_dict()))).is_not_empty()


func test_door_and_outcome_checks() -> void:
	var door := DoorState.new()
	door.cell = Vector2i(5, 6)
	door.mode = DoorState.Mode.SEALED
	var door_data: Dictionary = _json(door.to_dict())
	assert_array(DoorState.validate_dict(door_data)).is_empty()
	assert_dict(_json(DoorState.from_dict(door_data).to_dict())).is_equal(door_data)
	door_data["mode"] = "ajar"
	assert_array(DoorState.validate_dict(door_data)).is_not_empty()
	var outcome := OutcomeState.new()
	var outcome_data: Dictionary = _json(outcome.to_dict())
	assert_array(OutcomeState.validate_dict(outcome_data)).is_empty()
	outcome_data["status"] = "failed"
	assert_array(OutcomeState.validate_dict(outcome_data)).is_not_empty()
	outcome.status = OutcomeState.Status.FAILED
	outcome.cause = &"overrun"
	outcome.tick = 40
	outcome_data = _json(outcome.to_dict())
	assert_array(OutcomeState.validate_dict(outcome_data)).is_empty()
	assert_dict(_json(OutcomeState.from_dict(outcome_data).to_dict())).is_equal(outcome_data)
