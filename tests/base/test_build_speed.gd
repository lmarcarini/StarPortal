## Tests for the Workshop's effect (BuildSpeed) with a standard crew (two skill-3 engineers):
## while built and on, sites and digs progress 25% faster, exactly (a bonus tick every fourth clock
## tick); nothing while it is off, building or coming down; a second Workshop adds nothing;
## demolition is not sped up.
## Bible: docs/content/m25-lean-start.md sections 4 and 5
extends GdUnitTestSuite

const LAB: StringName = &"room_research_lab"

var _game: GameState
var _system: ConstructionSystem


func before_test() -> void:
	_game = ConstructionFixture.grown()
	_system = ConstructionSystem.new()


## A built, switched-on Workshop on Level 3 (placement unchecked), staffed by two skill-3
## engineers (25%) when [param staffed].
func _workshop(column: int = 4, staffed: bool = true) -> RoomState:
	var room: RoomState = _game.base.add_room(BuildSpeed.WORKSHOP_DEF, 3, Vector2i(column, 16))
	if staffed:
		StaffFixture.engineers(_game, room, [3, 3])
	return room


## Ticks the system and the clock until [param done] is true; returns the ticks taken.
func _ticks_until(done: Callable) -> int:
	var ticks: int = 0
	while not done.call() and ticks < 100000:
		_system.tick(_game)
		_game.clock.tick += 1
		ticks += 1
	return ticks


func _place_lab() -> RoomState:
	ConstructionFixture.run(_game, PlaceRoomCommand.create(LAB, 2, Vector2i(20, 16)))
	return _game.base.rooms[-1]


## An 8-hour lab (480 ticks) takes 384 ticks with a Workshop on: 6.4 hours.
func test_site_is_a_quarter_faster_with_a_workshop_on() -> void:
	_workshop()
	var lab: RoomState = _place_lab()
	assert_int(_ticks_until(lab.is_built)).is_equal(384)


func test_no_effect_without_or_with_the_workshop_off() -> void:
	var lab: RoomState = _place_lab()
	assert_int(_ticks_until(lab.is_built)).is_equal(480)
	_game.clock.tick = 0
	_workshop().powered_on = false
	var second: RoomState = _game.base.add_room(LAB, 3, Vector2i(20, 16))
	second.build_ticks_left = 480
	assert_int(_ticks_until(second.is_built)).is_equal(480)


func test_workshop_still_building_has_no_effect() -> void:
	_workshop().build_ticks_left = 100000
	var lab: RoomState = _place_lab()
	assert_int(_ticks_until(lab.is_built)).is_equal(480)


func test_second_workshop_adds_nothing() -> void:
	_workshop(4)
	_workshop(10, false)
	var lab: RoomState = _place_lab()
	assert_int(_ticks_until(lab.is_built)).is_equal(384)


## A 4-hour site takes 3.2 hours (192 ticks), as the doc says.
func test_four_hour_site_takes_3_2_hours() -> void:
	_workshop()
	var lift := _game.base.add_room(&"room_lift", 2, Vector2i(0, 0))
	lift.build_ticks_left = 240
	assert_int(_ticks_until(lift.is_built)).is_equal(192)


## Level 4 (5 days, 7,200 ticks) is dug in 5,760 ticks: 4 days.
func test_dig_is_a_quarter_faster() -> void:
	_workshop()
	assert_bool(ConstructionFixture.run(_game, DigLevelCommand.new()).is_ok).is_true()
	var level: LevelState = _game.base.levels[-1]
	assert_int(_ticks_until(level.is_dug)).is_equal(5760)


## The speed-up depends only on the clock tick and the rooms: the same at every start phase
## within one tick of 4n / 5.
func test_any_start_phase_is_within_one_tick() -> void:
	_workshop()
	for phase: int in 4:
		_game.clock.tick = phase
		var lab: RoomState = _game.base.add_room(LAB, 3, Vector2i(20, 16))
		lab.build_ticks_left = 480
		assert_int(_ticks_until(lab.is_built)).is_between(383, 384)
		_game.base.remove_room(lab.id)


func test_demolition_is_not_sped_up() -> void:
	_workshop()
	var lab: RoomState = _game.base.add_room(LAB, 3, Vector2i(20, 16))
	assert_bool(ConstructionFixture.run(_game, DemolishRoomCommand.create(lab.id)).is_ok).is_true()
	var gone: Callable = func() -> bool: return _game.base.find_room(lab.id) == null
	assert_int(_ticks_until(gone)).is_equal(120)
