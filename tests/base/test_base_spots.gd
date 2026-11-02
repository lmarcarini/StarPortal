## Tests for BaseSpots: the gap between areas, the nearest valid spot to a target (fits,
## touches a connector, closest, ties broken top-most then left-most) and no spot at all.
## Bible: docs/content/m2-base.md sections 4 and 6
extends GdUnitTestSuite

var _defs: Dictionary = {}


func before_test() -> void:
	_defs = {}
	for def: DefBase in Registry.get_all_of(RoomDef):
		_defs[def.id] = def


## One dug level of [param size] cells with a corridor row at [param row] from column 0 to 9.
func _base(size: Vector2i, row: int) -> BaseState:
	var base := BaseState.new()
	base.grid_size = size
	base.levels.append(LevelState.new())
	for column: int in 10:
		base.add_room(StartingBase.CORRIDOR_DEF, 1, Vector2i(column, row))
	return base


func test_gap_counts_empty_cells_between() -> void:
	var a := Rect2i(0, 0, 2, 2)
	assert_int(BaseSpots.gap(a, Rect2i(2, 0, 1, 1))).is_equal(0)
	assert_int(BaseSpots.gap(a, Rect2i(1, 1, 3, 3))).is_equal(0)
	assert_int(BaseSpots.gap(a, Rect2i(5, 0, 1, 1))).is_equal(3)
	assert_int(BaseSpots.gap(a, Rect2i(4, 5, 1, 1))).is_equal(5)
	assert_int(BaseSpots.gap(Rect2i(4, 5, 1, 1), a)).is_equal(5)


func test_nearest_spot_touches_a_corridor_and_is_closest() -> void:
	var base := _base(Vector2i(10, 10), 5)
	var bank: StringName = StartingBase.CAPACITOR_BANK_DEF
	# Target far right below the corridor: the bank sits under the corridor's right end.
	var spot: Vector2i = BaseSpots.nearest_spot(base, _defs, bank, 1, Rect2i(9, 9, 1, 1))
	assert_vector(Vector2(spot)).is_equal(Vector2(7, 6))
	# Target top left: above the corridor's left end.
	spot = BaseSpots.nearest_spot(base, _defs, bank, 1, Rect2i(0, 0, 1, 1))
	assert_vector(Vector2(spot)).is_equal(Vector2(0, 3))


func test_ties_go_top_most_then_left_most() -> void:
	var base := _base(Vector2i(10, 10), 5)
	# A target across the corridor: (3, 3), (4, 3), (3, 6) and (4, 6) tie; top left wins.
	var spot: Vector2i = BaseSpots.nearest_spot(
		base, _defs, StartingBase.CAPACITOR_BANK_DEF, 1, Rect2i(0, 4, 10, 3)
	)
	assert_vector(Vector2(spot)).is_equal(Vector2(3, 3))


func test_no_spot_without_a_connector_or_room() -> void:
	var base := BaseState.new()
	base.grid_size = Vector2i(10, 10)
	base.levels.append(LevelState.new())
	var bank: StringName = StartingBase.CAPACITOR_BANK_DEF
	var target := Rect2i(0, 0, 1, 1)
	assert_vector(Vector2(BaseSpots.nearest_spot(base, _defs, bank, 1, target))).is_equal(
		Vector2(BaseSpots.NO_SPOT)
	)
	var tight := _base(Vector2i(10, 2), 0)
	assert_vector(Vector2(BaseSpots.nearest_spot(tight, _defs, bank, 1, target))).is_equal(
		Vector2(BaseSpots.NO_SPOT)
	)
	assert_vector(Vector2(BaseSpots.bank_spot(base, _defs))).is_equal(Vector2(BaseSpots.NO_SPOT))
