## The M4c save shapes (M4c-02): each new state round-trips through JSON, rejects bad data,
## and an older save migrates with empty sections and loads identically after a save.
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


func test_an_old_save_migrates_and_reloads_identically() -> void:
	var state := GameState.new_game(8, Registry.balance())
	GameSetup.build_new(state, GameDefs.from_registry(Registry))
	state.base.rooms[0].damaged = true
	var door := DoorState.new()
	door.cell = Vector2i(24, 9)
	state.base.doors.append(door)
	state.incursion = _sample_incursion()
	var data: Dictionary = _json(state.to_dict())
	assert_array(GameState.validate_dict(data)).is_empty()
	assert_dict(_json(GameState.from_dict(data).to_dict())).is_equal(data)
	var old: Dictionary = {"format_version": 18, "state": data.duplicate(true)}
	var old_state: Dictionary = old["state"]
	for key: String in ["incursion", "security", "outcome"]:
		old_state.erase(key)
	var old_base: Dictionary = old_state["base"]
	old_base.erase("doors")
	var migrated: Result = SaveMigrator.migrate(old)
	assert_bool(migrated.is_ok).is_true()
	var root: Dictionary = migrated.value
	var new_state: Dictionary = root["state"]
	assert_array(GameState.validate_dict(new_state)).is_empty()
	var loaded: GameState = GameState.from_dict(new_state)
	assert_bool(loaded.incursion.is_active()).is_false()
	assert_array(loaded.base.doors).is_empty()
	var resaved: Dictionary = _json(loaded.to_dict())
	assert_dict(_json(GameState.from_dict(resaved).to_dict())).is_equal(resaved)
