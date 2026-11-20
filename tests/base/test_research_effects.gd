## One test per M2.5 research effect, each reached by finishing the project through
## ResearchSystem: dig Level 2 and Stairs; Lift; dig Levels 3-4; more plants; fuel upkeep;
## three banks; Workshop. Effects that can touch power keep the cache equal to a fresh sum.
## Bible: docs/content/m25-lean-start.md section 3
extends GdUnitTestSuite


func _can_build(game: GameState, def_id: StringName) -> bool:
	return BaseRules.can_build_room(game, def_id).is_ok


## The power totals cached on [param game] equal a fresh sum over the same rooms.
func _assert_cache_fresh(game: GameState) -> void:
	var cached: PackedFloat64Array = PowerRules.totals(game)
	var fresh := GameState.from_dict(game.to_dict())
	fresh.room_defs = game.room_defs
	assert_array(Array(PowerRules.totals(fresh))).is_equal(Array(cached))


## R1: Level 2 may be dug and Stairs built.
func test_excavation_survey() -> void:
	var game: GameState = ResearchFixture.state()
	assert_bool(BaseRules.can_dig(game).is_ok).is_false()
	assert_bool(_can_build(game, &"room_stairs")).is_false()
	ResearchFixture.finish(game, &"excavation_survey")
	assert_bool(BaseRules.can_dig(game).is_ok).is_true()
	assert_bool(_can_build(game, &"room_stairs")).is_true()


## R2: Lifts may be built.
func test_lift_shaft() -> void:
	var game: GameState = ResearchFixture.state()
	ResearchFixture.finish(game, &"excavation_survey")
	assert_bool(_can_build(game, &"room_lift")).is_false()
	ResearchFixture.finish(game, &"lift_shaft")
	assert_bool(_can_build(game, &"room_lift")).is_true()


## R3: Levels 3 and 4 may be dug, not 5.
func test_deep_excavation() -> void:
	var game: GameState = ResearchFixture.state()
	ResearchFixture.finish(game, &"excavation_survey")
	ResearchFixture.finish(game, &"lift_shaft")
	game.base.levels.append(LevelState.new())
	assert_that(BaseRules.can_dig(game).error_code).is_equal(&"needs_research")
	ResearchFixture.finish(game, &"deep_excavation")
	assert_int(game.unlocks.dig_depth).is_equal(4)
	assert_bool(BaseRules.can_dig(game).is_ok).is_true()


## R4: more Power Plants may be built; a built one adds 30 MW and the cache agrees.
func test_second_plant() -> void:
	var game: GameState = ResearchFixture.state()
	var supply: float = PowerRules.supply_mw(game)
	assert_bool(_can_build(game, &"room_power_plant")).is_false()
	ResearchFixture.finish(game, &"second_plant")
	_assert_cache_fresh(game)
	assert_bool(_can_build(game, &"room_power_plant")).is_true()
	game.base.add_room(&"room_power_plant", 1, Vector2i(5, 12))
	assert_float(PowerRules.supply_mw(game)).is_equal(supply + 30.0)
	_assert_cache_fresh(game)


## R5: every diesel plant's upkeep drops from $150k to $100k per 30 days.
func test_fuel_contracts() -> void:
	var game: GameState = ResearchFixture.state()
	var before: int = EconomySystem.upkeep_k(game.base, game.room_defs, game.unlocks)
	ResearchFixture.finish(game, &"second_plant")
	ResearchFixture.finish(game, &"fuel_contracts")
	var after: int = EconomySystem.upkeep_k(game.base, game.room_defs, game.unlocks)
	assert_int(before - after).is_equal(50)
	_assert_cache_fresh(game)


## R6: up to 3 Capacitor Banks (was 1).
func test_bank_array() -> void:
	var game: GameState = ResearchFixture.state()
	PowerFixture.add_bank(game)
	assert_that(BaseRules.can_build_room(game, &"room_capacitor_bank").error_code).is_equal(
		&"bank_cap"
	)
	ResearchFixture.finish(game, &"bank_array")
	assert_bool(_can_build(game, &"room_capacitor_bank")).is_true()
	assert_int(game.unlocks.bank_cap).is_equal(3)


## The Workshop is known from the start (M7-02: Engineering opens at the start).
func test_workshop_from_the_start() -> void:
	var game: GameState = ResearchFixture.state()
	assert_bool(_can_build(game, &"room_workshop")).is_true()
