## Tests for BoardLayout: free grid cells in arrival order and saved positions kept.
## Bible: gate-and-address-spec.md#player-tools
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/fixtures/board_fixture.gd")


func test_unplaced_cards_take_grid_cells_in_arrival_order() -> void:
	var intel: IntelState = Fixture.state(7).intel
	var positions: Dictionary[StringName, Vector2i] = BoardLayout.positions(intel)
	for index: int in 7:
		var clue_id: StringName = StringName("clue_%04d" % (index + 1))
		assert_object(positions[clue_id]).is_equal(BoardLayout.cell_origin(index))
	assert_int(BoardLayout.cell_origin(5).y).is_greater(BoardLayout.cell_origin(0).y)


func test_a_placed_card_keeps_its_position_and_blocks_its_cell() -> void:
	var intel: IntelState = Fixture.state(3).intel
	var note: ClueNote = ClueNote.new()
	note.board_position = BoardLayout.cell_origin(0) + Vector2i(20, 10)
	intel.notes[&"clue_0001"] = note
	var positions: Dictionary[StringName, Vector2i] = BoardLayout.positions(intel)
	assert_object(positions[&"clue_0001"]).is_equal(note.board_position)
	assert_object(positions[&"clue_0002"]).is_equal(BoardLayout.cell_origin(2))
	assert_object(positions[&"clue_0003"]).is_equal(BoardLayout.cell_origin(3))


func test_a_free_cell_left_by_a_moved_card_is_reused() -> void:
	var intel: IntelState = Fixture.state(3).intel
	var note: ClueNote = ClueNote.new()
	note.board_position = Vector2i(2000, 2000)
	intel.notes[&"clue_0001"] = note
	var positions: Dictionary[StringName, Vector2i] = BoardLayout.positions(intel)
	assert_object(positions[&"clue_0002"]).is_equal(BoardLayout.cell_origin(0))


func test_clamp_keeps_cards_on_the_board_and_off_the_origin() -> void:
	assert_object(BoardLayout.clamp_position(Vector2i(-50, 0))).is_equal(
		Vector2i(BoardLayout.MIN_COORDINATE, BoardLayout.MIN_COORDINATE)
	)
	var most: int = ClueNote.MAX_BOARD_COORDINATE
	assert_object(BoardLayout.clamp_position(Vector2i(most + 9, 100))).is_equal(Vector2i(most, 100))


func test_content_size_holds_every_card() -> void:
	var positions: Dictionary[StringName, Vector2i] = {
		&"a": Vector2i(100, 50), &"b": Vector2i(10, 400)
	}
	var size: Vector2i = BoardLayout.content_size(positions)
	assert_int(size.x).is_greater_equal(100 + BoardLayout.CARD_SIZE.x)
	assert_int(size.y).is_greater_equal(400 + BoardLayout.CARD_SIZE.y)
