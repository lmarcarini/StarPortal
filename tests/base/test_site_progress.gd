## Tests for SiteProgress and BuildSpeed.ticks_to_finish: a site's, demolition's and dig's
## fraction done and real ticks left, with the Workshop's 25%, and a queued site.
## Bible: docs/content/m2-base.md sections 4 and 6, docs/content/m25-lean-start.md section 4
extends GdUnitTestSuite

const LAB: StringName = &"room_research_lab"

var _game: GameState


func before_test() -> void:
	_game = ConstructionFixture.grown()


## The closed form agrees with ticking the system one tick at a time, at every phase.
func test_ticks_to_finish_matches_the_system() -> void:
	for work: int in [1, 2, 3, 4, 5, 6, 9, 240, 481]:
		for start: int in 4:
			var left: int = work
			var ticks: int = 0
			while left > 0:
				left -= 2 if (start + ticks) % 4 == 3 else 1
				ticks += 1
			assert_int(BuildSpeed.ticks_to_finish(work, start, true)).is_equal(ticks)
			assert_int(BuildSpeed.ticks_to_finish(work, start, false)).is_equal(work)
	assert_int(BuildSpeed.ticks_to_finish(240, 0, true)).is_equal(192)
	assert_int(BuildSpeed.ticks_to_finish(0, 0, true)).is_equal(0)


func test_a_site_reports_its_fraction_and_real_ticks_left() -> void:
	var lab: RoomState = _place_lab(Vector2i(20, 16))
	lab.build_ticks_left = 120
	var progress: SiteProgress = SiteProgress.of_room(_game, lab)
	assert_int(progress.kind).is_equal(SiteProgress.Kind.BUILDING)
	assert_float(progress.fraction).is_equal_approx(0.75, 0.001)
	assert_int(progress.ticks_left).is_equal(120)
	_game.base.add_room(BuildSpeed.WORKSHOP_DEF, 3, Vector2i(4, 16))
	_game.clock.tick = 0
	assert_int(SiteProgress.of_room(_game, lab).ticks_left).is_equal(96)


func test_a_site_past_the_slots_is_queued_with_an_empty_bar() -> void:
	var sites: Array[RoomState] = []
	for column: int in [4, 9, 14, 19]:
		sites.append(_place_lab(Vector2i(column, 16)))
	var found: Dictionary = SiteProgress.for_rooms(_game, _game.base.rooms)
	var queued: SiteProgress = found[sites[3].id]
	assert_int(queued.kind).is_equal(SiteProgress.Kind.QUEUED)
	assert_float(queued.fraction).is_equal(0.0)
	assert_int(queued.queue_place).is_equal(1)
	var first: SiteProgress = found[sites[0].id]
	assert_int(first.kind).is_equal(SiteProgress.Kind.BUILDING)
	assert_bool(found.has(_game.base.rooms[0].id)).is_false()


func test_a_corridor_run_counts_its_longest_cell() -> void:
	var cells: Array[Vector2i] = [Vector2i(4, 16), Vector2i(5, 16), Vector2i(6, 16)]
	ConstructionFixture.run(_game, PaintCorridorCommand.create(2, cells))
	var last: RoomState = _game.base.rooms[-1]
	var first: RoomState = _game.base.rooms[-3]
	var progress: SiteProgress = SiteProgress.of_room(_game, first)
	assert_float(progress.fraction).is_equal(0.0)
	assert_int(progress.ticks_left).is_equal(last.build_ticks_left)


func test_demolition_and_dig_progress() -> void:
	var lab: RoomState = _game.base.add_room(LAB, 2, Vector2i(20, 16))
	lab.demolish_ticks_left = 60
	var demolition: SiteProgress = SiteProgress.of_room(_game, lab)
	assert_int(demolition.kind).is_equal(SiteProgress.Kind.DEMOLISHING)
	assert_float(demolition.fraction).is_equal_approx(0.5, 0.001)
	assert_int(demolition.ticks_left).is_equal(60)
	assert_int(SiteProgress.of_dig(_game).kind).is_equal(SiteProgress.Kind.NONE)
	_game.base.start_dig(1000)
	var level: int = _game.base.digging_level()
	_game.base.levels[level - 1].dig_ticks_left = 250
	var dig: SiteProgress = SiteProgress.of_dig(_game)
	assert_int(dig.kind).is_equal(SiteProgress.Kind.DIGGING)
	assert_int(dig.ticks_left).is_equal(250)
	assert_float(dig.fraction).is_between(0.0, 1.0)


func _place_lab(origin: Vector2i) -> RoomState:
	var result: CommandResult = ConstructionFixture.run(
		_game, PlaceRoomCommand.create(LAB, 2, origin)
	)
	assert_bool(result.is_ok).override_failure_message(result.detail).is_true()
	return _game.base.rooms[-1]
