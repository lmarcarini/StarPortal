## Tests for DigLevelCommand, digging in ConstructionSystem and cancelling a dig.
## Bible: docs/content/m2-base.md section 4
extends GdUnitTestSuite


func test_dig_pays_takes_its_days_and_extends_the_lift() -> void:
	var game := ConstructionFixture.state()
	assert_bool(ConstructionFixture.run(game, DigLevelCommand.new()).is_ok).is_true()
	assert_int(game.budget.funds_k).is_equal(12000 - 3000)
	assert_int(game.base.level_count).is_equal(4)
	game.events.drain()
	var system := ConstructionSystem.new()
	ConstructionFixture.advance(game, system, 20 * 1440 - 1)
	assert_int(game.base.digging_level()).is_equal(4)
	ConstructionFixture.advance(game, system, 1)
	assert_int(game.base.digging_level()).is_equal(0)
	ConstructionFixture.advance(game, system, 5)
	assert_array(ConstructionFixture.event_names(game)).is_equal([&"level_dug"])
	var lifts: Array[RoomState] = BaseRules.rooms_on_level(game.base, 4)
	assert_int(lifts.size()).is_equal(1)
	assert_that(lifts[0].origin).is_equal(StartingBase.LIFT_ORIGIN)
	assert_bool(lifts[0].is_built()).is_true()


func test_one_dig_at_a_time_and_two_extra_levels() -> void:
	var game := ConstructionFixture.state()
	game.budget.funds_k = 100000
	ConstructionFixture.run(game, DigLevelCommand.new())
	assert_str(DigLevelCommand.new().validate(game).error_code).is_equal("dig_running")
	var system := ConstructionSystem.new()
	ConstructionFixture.advance(game, system, 20 * 1440)
	assert_bool(ConstructionFixture.run(game, DigLevelCommand.new()).is_ok).is_true()
	assert_int(game.budget.funds_k).is_equal(100000 - 3000 - 4500)
	ConstructionFixture.advance(game, system, 30 * 1440)
	assert_str(DigLevelCommand.new().validate(game).error_code).is_equal("level_limit")


func test_dig_needs_money() -> void:
	var game := ConstructionFixture.state()
	game.budget.funds_k = 2999
	assert_str(DigLevelCommand.new().validate(game).error_code).is_equal("insufficient_funds")


func test_cancel_dig_refunds_half() -> void:
	var game := ConstructionFixture.state()
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
	assert_int(game.budget.funds_k).is_equal(12000 - 3000 + 1500)
	assert_int(game.base.level_count).is_equal(3)
	var again := CancelBuildCommand.create(CancelBuildCommand.DIG_TARGET).validate(game)
	assert_str(again.error_code).is_equal("no_dig")


func test_save_mid_dig_keeps_progress() -> void:
	var game := ConstructionFixture.state()
	ConstructionFixture.run(game, DigLevelCommand.new())
	ConstructionFixture.advance(game, ConstructionSystem.new(), 100)
	var data: Dictionary = JSON.parse_string(JSON.stringify(game.base.to_dict()))
	var loaded := BaseState.from_dict(data)
	assert_int(loaded.levels[3].dig_ticks_left).is_equal(20 * 1440 - 100)
