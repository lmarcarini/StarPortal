## Tests for the Workshop's staffed bonus (BuildSpeed): 10% empty plus 2.5% per engineer skill
## point, at most 35%; sites and digs, exact tick counts, the time left and determinism across
## a save and load mid-site.
## Bible: docs/content/m26-staff-and-money.md section 3
extends GdUnitTestSuite

const LAB: StringName = &"room_research_lab"

var _game: GameState
var _system: ConstructionSystem


func before_test() -> void:
	_game = ConstructionFixture.grown()
	_system = ConstructionSystem.new()


func _workshop(skills: Array[int]) -> RoomState:
	var room: RoomState = _game.base.add_room(BuildSpeed.WORKSHOP_DEF, 3, Vector2i(4, 16))
	StaffFixture.engineers(_game, room, skills)
	return room


## Ticks an 8-hour (480-tick) lab site to the end; checks the time left at the start.
func _build_lab(game: GameState = _game) -> int:
	var lab: RoomState = game.base.add_room(LAB, 3, Vector2i(20, 16))
	lab.build_ticks_left = 480
	var expected: int = SiteProgress.of_room(game, lab).ticks_left
	var ticks: int = _run_until(game, lab.is_built)
	assert_int(ticks).is_equal(expected)
	return ticks


func _run_until(game: GameState, done: Callable) -> int:
	var ticks: int = 0
	while not done.call() and ticks < 100000:
		_system.tick(game)
		game.clock.tick += 1
		ticks += 1
	return ticks


func test_no_workshop() -> void:
	assert_int(BuildSpeed.bonus(_game)).is_equal(0)
	assert_int(_build_lab()).is_equal(480)


func test_empty_workshop_is_ten_percent() -> void:
	_workshop([])
	assert_int(BuildSpeed.bonus_percent(_game)).is_equal(10)
	assert_int(_build_lab()).is_equal(437)


func test_one_skill_1_engineer() -> void:
	_workshop([1])
	assert_int(BuildSpeed.bonus_percent(_game)).is_equal(12)
	assert_int(_build_lab()).is_equal(427)


## The starting engineers (skill 3 and 2): 22.5%.
func test_starting_engineers() -> void:
	_workshop([3, 2])
	assert_int(BuildSpeed.bonus(_game)).is_equal(9)
	assert_int(_build_lab()).is_equal(392)


func test_standard_crew_is_25_percent() -> void:
	_workshop([3, 3])
	assert_int(BuildSpeed.bonus_percent(_game)).is_equal(25)
	assert_int(_build_lab()).is_equal(384)


func test_bonus_is_capped_at_35_percent() -> void:
	_workshop([5, 5])
	assert_int(BuildSpeed.bonus_percent(_game)).is_equal(35)
	assert_int(_build_lab()).is_equal(356)


## A Workshop that is off gives nothing, its engineers idle.
func test_workshop_off_gives_nothing() -> void:
	_workshop([3, 3]).powered_on = false
	assert_int(_build_lab()).is_equal(480)


## A dig (Level 4, 7,200 ticks) with two skill-4 engineers (30%): 5,539 ticks.
func test_dig_with_engineers() -> void:
	_workshop([4, 4])
	assert_bool(ConstructionFixture.run(_game, DigLevelCommand.new()).is_ok).is_true()
	var level: LevelState = _game.base.levels[-1]
	var expected: int = SiteProgress.of_dig(_game).ticks_left
	assert_int(expected).is_equal(5539)
	assert_int(_run_until(_game, level.is_dug)).is_equal(expected)


## Saving and loading mid-site changes nothing: both copies finish on the same tick in the
## same state.
func test_save_and_load_mid_site_is_deterministic() -> void:
	_workshop([3, 2])
	var lab: RoomState = _game.base.add_room(LAB, 3, Vector2i(20, 16))
	lab.build_ticks_left = 480
	_game.clock.tick = 3
	_run_until(_game, func() -> bool: return lab.build_ticks_left <= 301)
	var data: Dictionary = JSON.parse_string(JSON.stringify(_game.to_dict()))
	var copy: GameState = GameState.from_dict(data)
	copy.balance = _game.balance
	copy.room_defs = _game.room_defs
	var copy_lab: RoomState = copy.base.find_room(lab.id)
	var left: int = _run_until(_game, lab.is_built)
	assert_int(_run_until(copy, copy_lab.is_built)).is_equal(left)
	assert_dict(copy.to_dict()).is_equal(_game.to_dict())
