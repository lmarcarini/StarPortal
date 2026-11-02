## Tests for DigLevelCommand, digging in ConstructionSystem and cancelling a dig, with the
## M2.5 numbers and research gate (Level 2: $1,500k, 3 days; Levels 3 and 4 after Deep
## excavation).
## Bible: docs/content/m2-base.md section 4, docs/content/m25-lean-start.md section 2
extends GdUnitTestSuite


func _surveyed() -> GameState:
	var game := ConstructionFixture.state()
	UnlockRules.apply_project(game.unlocks, &"excavation_survey")
	return game


## A new game can't dig: it needs Excavation survey.
func test_dig_needs_research() -> void:
	var game := ConstructionFixture.state()
	var result: CommandResult = DigLevelCommand.new().validate(game)
	assert_str(result.error_code).is_equal("needs_research")
	assert_str(result.detail).is_equal("excavation_survey")


## The dig pays and takes 3 days; the built lift then extends into Level 2 as a paid lift
## segment ($100k, 1 hour; m25-lean-start.md section 2).
func test_dig_pays_takes_its_days_and_extends_the_lift() -> void:
	var game := ConstructionFixture.unlock_all(ConstructionFixture.state())
	var lift: RoomState = game.base.add_room(&"room_lift", 1, Vector2i(0, 11))
	assert_bool(ConstructionFixture.run(game, DigLevelCommand.new()).is_ok).is_true()
	assert_int(game.budget.funds_k).is_equal(6000 - 1500)
	assert_int(game.base.level_count).is_equal(2)
	game.events.drain()
	var system := ConstructionSystem.new()
	ConstructionFixture.advance(game, system, 3 * 1440 - 1)
	assert_int(game.base.digging_level()).is_equal(2)
	ConstructionFixture.advance(game, system, 1)
	assert_int(game.base.digging_level()).is_equal(0)
	assert_array(ConstructionFixture.event_names(game)).is_equal(
		[&"room_build_started", &"budget_changed", &"level_dug"]
	)
	assert_int(game.budget.funds_k).is_equal(6000 - 1500 - 100)
	var lifts: Array[RoomState] = BaseRules.rooms_on_level(game.base, 2)
	assert_int(lifts.size()).is_equal(1)
	assert_that(lifts[0].origin).is_equal(lift.origin)
	assert_int(lifts[0].build_ticks_left).is_equal(60)
	ConstructionFixture.advance(game, system, 60)
	assert_bool(lifts[0].is_built()).is_true()


## Level 3 needs Deep excavation; with it, Levels 3 and 4 and no more.
func test_one_dig_at_a_time_and_three_extra_levels() -> void:
	var game := _surveyed()
	game.budget.funds_k = 100000
	ConstructionFixture.run(game, DigLevelCommand.new())
	assert_str(DigLevelCommand.new().validate(game).error_code).is_equal("dig_running")
	var system := ConstructionSystem.new()
	ConstructionFixture.advance(game, system, 3 * 1440)
	var refused: CommandResult = DigLevelCommand.new().validate(game)
	assert_str(refused.error_code).is_equal("needs_research")
	assert_str(refused.detail).is_equal("deep_excavation")
	UnlockRules.apply_project(game.unlocks, &"deep_excavation")
	assert_bool(ConstructionFixture.run(game, DigLevelCommand.new()).is_ok).is_true()
	ConstructionFixture.advance(game, system, 4 * 1440)
	assert_bool(ConstructionFixture.run(game, DigLevelCommand.new()).is_ok).is_true()
	assert_int(game.budget.funds_k).is_equal(100000 - 1500 - 2500 - 3500)
	ConstructionFixture.advance(game, system, 5 * 1440)
	assert_int(game.base.level_count).is_equal(4)
	assert_str(DigLevelCommand.new().validate(game).error_code).is_equal("level_limit")


func test_dig_needs_money() -> void:
	var game := _surveyed()
	game.budget.funds_k = 1499
	assert_str(DigLevelCommand.new().validate(game).error_code).is_equal("insufficient_funds")


func test_cancel_dig_refunds_half() -> void:
	var game := _surveyed()
	ConstructionFixture.run(game, DigLevelCommand.new())
	ConstructionFixture.advance(game, ConstructionSystem.new(), 100)
	(
		assert_bool(
			(
				ConstructionFixture
				. run(game, CancelBuildCommand.create(CancelBuildCommand.DIG_TARGET))
				. is_ok
			)
		)
		. is_true()
	)
	assert_int(game.budget.funds_k).is_equal(6000 - 1500 + 750)
	assert_int(game.base.level_count).is_equal(1)
	var again := CancelBuildCommand.create(CancelBuildCommand.DIG_TARGET).validate(game)
	assert_str(again.error_code).is_equal("no_dig")


func test_save_mid_dig_keeps_progress() -> void:
	var game := _surveyed()
	ConstructionFixture.run(game, DigLevelCommand.new())
	ConstructionFixture.advance(game, ConstructionSystem.new(), 100)
	var data: Dictionary = JSON.parse_string(JSON.stringify(game.base.to_dict()))
	var loaded := BaseState.from_dict(data)
	assert_int(loaded.levels[1].dig_ticks_left).is_equal(3 * 1440 - 100)
