## Tests for UnlockRules: effects, projects, and the build and dig refusals with their reasons.
## Bible: docs/content/m25-lean-start.md sections 1-3
extends GdUnitTestSuite

var _game: GameState = null


func before_test() -> void:
	_game = ConstructionFixture.state()


func _code(def_id: StringName) -> String:
	return String(BaseRules.can_build_room(_game, def_id).error_code)


## At the start only the bank, the lab and the corridor are buildable; the rest say why.
func test_start_locks() -> void:
	for def_id: StringName in [&"room_capacitor_bank", &"room_research_lab", &"room_corridor"]:
		assert_bool(BaseRules.can_build_room(_game, def_id).is_ok).is_true()
	var cases: Dictionary = {
		&"room_stairs": "excavation_survey",
		&"room_lift": "lift_shaft",
		&"room_power_plant": "second_plant",
		&"room_workshop": "field_engineering",
	}
	for def_id: StringName in cases:
		var result: CommandResult = BaseRules.can_build_room(_game, def_id)
		assert_str(String(result.error_code)).is_equal("needs_research")
		assert_str(result.detail).is_equal(cases[def_id])
	assert_str(_code(&"room_quarters")).is_equal("needs_staff")
	assert_str(_code(&"room_infirmary")).is_equal("needs_staff")
	assert_str(_code(&"room_gate")).is_equal("not_buildable")
	assert_str(_code(&"room_nope")).is_equal("unknown_room")


## Placing a locked room is refused by the command with the same reason, before placement.
func test_place_room_uses_it() -> void:
	var result: CommandResult = (
		PlaceRoomCommand.create(&"room_workshop", 1, Vector2i(0, 11)).validate(_game)
	)
	assert_str(String(result.error_code)).is_equal("needs_research")
	assert_str(result.detail).is_equal("field_engineering")


## A second bank is refused at cap 1 until Bank array; then three, and no fourth.
func test_bank_cap() -> void:
	var first: PlaceRoomCommand = PowerFixture.build_first_bank(_game)
	assert_bool(ConstructionFixture.run(_game, first).is_ok).is_true()
	var second: CommandResult = BaseRules.can_build_room(_game, &"room_capacitor_bank")
	assert_str(String(second.error_code)).is_equal("bank_cap")
	assert_str(second.detail).is_equal("bank_array")
	UnlockRules.apply_project(_game.unlocks, &"bank_array")
	_game.base.add_room(&"room_capacitor_bank", 1, Vector2i(0, 0))
	assert_bool(BaseRules.can_build_room(_game, &"room_capacitor_bank").is_ok).is_true()
	var third: RoomState = _game.base.add_room(&"room_capacitor_bank", 1, Vector2i(4, 0))
	var fourth: CommandResult = BaseRules.can_build_room(_game, &"room_capacitor_bank")
	assert_str(String(fourth.error_code)).is_equal("bank_cap")
	assert_str(fourth.detail).is_empty()
	third.demolish_ticks_left = 5
	assert_bool(BaseRules.can_build_room(_game, &"room_capacitor_bank").is_ok).is_true()


## Digging: Level 2 after Excavation survey, Levels 3 and 4 after Deep excavation, then none.
func test_can_dig() -> void:
	assert_str(BaseRules.can_dig(_game).detail).is_equal("excavation_survey")
	UnlockRules.apply_project(_game.unlocks, &"excavation_survey")
	assert_bool(BaseRules.can_dig(_game).is_ok).is_true()
	_game.base.levels.append(LevelState.new())
	assert_str(BaseRules.can_dig(_game).detail).is_equal("deep_excavation")
	UnlockRules.apply_project(_game.unlocks, &"deep_excavation")
	_game.base.levels.append(LevelState.new())
	assert_bool(BaseRules.can_dig(_game).is_ok).is_true()
	_game.base.levels.append(LevelState.new())
	assert_str(String(BaseRules.can_dig(_game).error_code)).is_equal("level_limit")


## apply() takes each effect, never lowers a number, and refuses unknown effects or bad
## values without changing anything.
func test_apply_effects() -> void:
	var unlocks := UnlockState.new()
	assert_bool(UnlockRules.apply(unlocks, UnlockRules.EFFECT_UNLOCK_ROOM, "room_lift")).is_true()
	assert_bool(UnlockRules.apply(unlocks, UnlockRules.EFFECT_UNLOCK_ROOM, &"room_lift")).is_true()
	assert_array(unlocks.rooms).is_equal([&"room_lift"])
	assert_bool(UnlockRules.apply(unlocks, UnlockRules.EFFECT_DIG_DEPTH, 4)).is_true()
	assert_bool(UnlockRules.apply(unlocks, UnlockRules.EFFECT_DIG_DEPTH, 2)).is_true()
	assert_int(unlocks.dig_depth).is_equal(4)
	assert_bool(UnlockRules.apply(unlocks, UnlockRules.EFFECT_BANK_CAP, 3.0)).is_true()
	assert_int(unlocks.bank_cap).is_equal(3)
	assert_bool(UnlockRules.apply(unlocks, UnlockRules.EFFECT_PLANT_UPKEEP, 100)).is_true()
	assert_int(unlocks.upkeep_overrides[&"room_power_plant"]).is_equal(100)
	var before: Dictionary = unlocks.to_dict()
	assert_bool(UnlockRules.apply(unlocks, &"nope", 1)).is_false()
	assert_bool(UnlockRules.apply(unlocks, UnlockRules.EFFECT_BANK_CAP, -1)).is_false()
	assert_bool(UnlockRules.apply(unlocks, UnlockRules.EFFECT_BANK_CAP, 2.5)).is_false()
	assert_bool(UnlockRules.apply(unlocks, UnlockRules.EFFECT_UNLOCK_ROOM, "")).is_false()
	assert_bool(UnlockRules.apply_project(unlocks, &"nope")).is_false()
	assert_dict(unlocks.to_dict()).is_equal(before)


## The seven projects of section 3, and every project has a translated name.
func test_projects() -> void:
	(
		assert_array(UnlockRules.PROJECTS.keys())
		. is_equal(
			[
				&"excavation_survey",
				&"lift_shaft",
				&"deep_excavation",
				&"second_plant",
				&"fuel_contracts",
				&"bank_array",
				&"field_engineering",
			]
		)
	)
	for project_id: StringName in UnlockRules.PROJECTS:
		var key: StringName = UnlockRules.project_name_key(project_id)
		assert_str(TranslationServer.translate(key)).is_not_equal(String(key))


## The refusal text names the project (en): the doc's examples.
func test_reason_text() -> void:
	var dig: String = BuildText.reason(BaseRules.can_dig(_game), _game, 0)
	assert_str(dig).is_equal("Needs research: Excavation survey.")
	_game.base.add_room(&"room_capacitor_bank", 1, Vector2i(0, 0))
	var bank: String = BuildText.reason(
		BaseRules.can_build_room(_game, &"room_capacitor_bank"), _game, 0
	)
	assert_str(bank).is_equal("Up to 1 Capacitor Bank until Bank array.")
