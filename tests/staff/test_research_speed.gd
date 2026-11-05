## Tests for research speed from staff (ResearchRules.speed(), ResearchSystem): max(25%, total
## skill ÷ 6), at most 200%, pooled across the labs that are on, for the one active project;
## exact tick counts, and the time left matching them.
## Bible: docs/content/m26-staff-and-money.md section 3
extends GdUnitTestSuite

const DAY: int = TimeMath.TICKS_PER_DAY
## Excavation survey: 2 days at 100%.
const SURVEY: StringName = &"excavation_survey"

var _game: GameState
var _lab: RoomState


func before_test() -> void:
	_game = ResearchFixture.state(false)
	_lab = PowerFixture.lab(_game)


## Starts the survey and checks the time left at the start equals the ticks it then takes.
func _finish_survey() -> int:
	assert_bool(ConstructionFixture.run(_game, StartResearchCommand.create(SURVEY)).is_ok).is_true()
	var expected: int = ResearchRules.ticks_left(_game)
	var system := ResearchSystem.new()
	var ticks: int = 0
	while _game.research.is_running() and ticks < 20 * DAY:
		system.tick(_game)
		_game.clock.tick += 1
		ticks += 1
	assert_int(ticks).is_equal(expected)
	return ticks


func test_empty_lab_runs_at_a_quarter() -> void:
	assert_int(ResearchRules.speed_percent(_game)).is_equal(25)
	assert_int(_finish_survey()).is_equal(8 * DAY)


func test_one_scientist_skill_3_is_half_speed() -> void:
	StaffFixture.scientists(_game, _lab, [3])
	assert_int(ResearchRules.speed_percent(_game)).is_equal(50)
	assert_int(_finish_survey()).is_equal(4 * DAY)


func test_one_scientist_skill_1_keeps_the_floor() -> void:
	StaffFixture.scientists(_game, _lab, [1])
	assert_int(ResearchRules.speed_percent(_game)).is_equal(25)
	assert_int(_finish_survey()).is_equal(8 * DAY)


func test_standard_crew_takes_the_listed_time() -> void:
	StaffFixture.scientists(_game, _lab, [3, 3])
	assert_int(_finish_survey()).is_equal(2 * DAY)


func test_skill_8_takes_a_day_and_a_half() -> void:
	StaffFixture.scientists(_game, _lab, [5, 3])
	assert_int(ResearchRules.speed_percent(_game)).is_equal(133)
	assert_int(_finish_survey()).is_equal(DAY + DAY / 2)


func test_speed_is_capped_at_200_percent() -> void:
	StaffFixture.scientists(_game, _lab, [5, 5, 5, 5])
	assert_int(ResearchRules.speed_percent(_game)).is_equal(200)
	assert_int(_finish_survey()).is_equal(DAY)


## Two labs pool their scientists into the one project; a lab that is off adds nothing, and
## the cap holds for the pooled total.
func test_two_labs_pool_and_an_off_lab_adds_nothing() -> void:
	StaffFixture.scientists(_game, _lab, [3, 3])
	var second: RoomState = _game.base.add_room(ResearchRules.LAB_DEF, 1, Vector2i(5, 5))
	StaffFixture.scientists(_game, second, [3, 3])
	assert_int(ResearchRules.speed_percent(_game)).is_equal(200)
	second.powered_on = false
	assert_int(ResearchRules.speed_percent(_game)).is_equal(100)
	second.powered_on = true
	StaffFixture.scientists(_game, second, [5, 5])
	assert_int(ResearchRules.speed_percent(_game)).is_equal(200)
	assert_int(_finish_survey()).is_equal(DAY)


## Mid-project, at an odd clock phase, the time left still equals the ticks it takes; with
## the lab off it shows the time the lab's crew would need.
func test_time_left_mid_project_and_paused() -> void:
	StaffFixture.scientists(_game, _lab, [5, 3])
	_game.clock.tick = 7
	ConstructionFixture.run(_game, StartResearchCommand.create(SURVEY))
	var system := ResearchSystem.new()
	for i: int in 333:
		system.tick(_game)
		_game.clock.tick += 1
	var left: int = ResearchRules.ticks_left(_game)
	_lab.powered_on = false
	assert_int(ResearchRules.ticks_left(_game)).is_equal(left)
	_lab.powered_on = true
	var ticks: int = 0
	while _game.research.is_running():
		system.tick(_game)
		_game.clock.tick += 1
		ticks += 1
	assert_int(ticks).is_equal(left)


## Skill 2 is above the floor: a third of the standard crew's speed.
func test_one_scientist_skill_2_is_a_third() -> void:
	StaffFixture.scientists(_game, _lab, [2])
	assert_int(ResearchRules.speed_percent(_game)).is_equal(33)
	assert_int(_finish_survey()).is_equal(6 * DAY)
