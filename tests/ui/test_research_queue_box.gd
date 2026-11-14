## Tests for the research queue box (M4-31): add the selected project, reorder, remove, and the
## wait reason.
extends GdUnitTestSuite

var _state: GameState
var _box: ResearchQueueBox


func before_test() -> void:
	TranslationServer.set_locale("en")
	_state = ResearchFixture.state()
	_state.budget.funds_k = 100000
	_state.clock.mode = ClockState.Mode.PAUSED
	_box = ResearchQueueBox.new()
	add_child(_box)
	_box.setup(Simulation.new(_state, []))


func after_test() -> void:
	_box.free()


func test_add_move_remove_and_wait() -> void:
	for project: StringName in [&"excavation_survey", &"second_plant", &"bank_array"]:
		_box.select(project)
		assert_bool(_box.get_add_button().visible).is_true()
		_box.get_add_button().pressed.emit()
	assert_array(_box.get_names()).is_equal(["1. Second plant", "2. Bank array"])
	_box.get_row_buttons(1)[0].pressed.emit()
	assert_array(_box.get_names()).is_equal(["1. Bank array", "2. Second plant"])
	_box.get_row_buttons(0)[2].pressed.emit()
	assert_array(_box.get_names()).is_equal(["1. Second plant"])
	assert_str(_box.get_wait_text()).is_empty()
	_state.research.active = &""
	_state.budget.funds_k = 0
	_box.refresh()
	assert_str(_box.get_wait_text()).is_equal("Waiting for funds")
