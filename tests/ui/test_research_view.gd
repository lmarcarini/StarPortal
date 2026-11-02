## Tests for the Research tab: the rows follow the doc (state words, locked slots, done rows
## at the bottom), the header shows the current project, time left and progress, the SELECTED
## panel offers Start or Cancel with the refund, every action goes through the commands with
## refusals shown plainly, the list refreshes while paused, the D-pad and (A) work, and the
## layout fits 1280 × 720 in both languages.
## Bible: docs/content/m25-lean-start.md section 3
extends GdUnitTestSuite

const VIEW_SCENE: String = "res://src/ui/views/research/research_view.tscn"
const VIEW_SIZE: Vector2 = Vector2(1280, 640)

var _root: Control = null
var _view: ResearchView = null
var _runner: GdUnitSceneRunner = null
var _simulation: Simulation = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var state: GameState = ResearchFixture.state()
	state.clock.is_paused = true
	_simulation = Simulation.new(state)
	EventBus.bind_simulation(_simulation)
	_root = Control.new()
	_root.size = VIEW_SIZE
	_view = (load(VIEW_SCENE) as PackedScene).instantiate() as ResearchView
	_view.size = VIEW_SIZE
	_root.add_child(_view)
	_runner = scene_runner(_root)
	_view.setup(_simulation)
	await _runner.simulate_frames(2)


func after_test() -> void:
	EventBus.bind_simulation(null)
	if is_instance_valid(_root):
		_root.free()
	TranslationServer.set_locale(_real_locale)


func test_rows_follow_the_doc() -> void:
	var rows: Array[ResearchRow] = _view.get_list().rows()
	assert_int(rows.size()).is_equal(14)
	assert_array(rows[0].texts()).is_equal(
		["Excavation survey", "$400k", "2 d", "Dig Level 2 and build Stairs.", "Start"]
	)
	assert_str(rows[1].texts()[4]).is_equal("needs R1")
	var last: Array[String] = rows[13].texts()
	assert_str(last[0]).is_equal("Unknown")
	assert_str(last[1]).is_empty()
	assert_str(last[3]).starts_with("Requires")
	assert_str(last[4]).is_equal("locked")


func test_start_with_accept_shows_header_and_cancel() -> void:
	var row: ResearchRow = _view.get_list().row_of(&"excavation_survey")
	row.grab_focus()
	await _press(&"ui_accept")
	assert_str(String(_simulation.state.research.active)).is_equal("excavation_survey")
	assert_array(_view.get_list().header()).is_equal(
		["RESEARCH", "Current: Excavation survey", "2 d left"]
	)
	assert_bool(_view.get_list().get_bar().visible).is_true()
	assert_str(row.texts()[4]).is_equal("ACTIVE")
	assert_str(_view.get_panel().get_button().text).is_equal("Cancel ($200k back)")


func test_cancel_goes_through_the_command_and_refunds() -> void:
	var funds: int = _simulation.state.budget.funds_k
	_view.act(&"bank_array")
	assert_int(_simulation.state.budget.funds_k).is_equal(funds - 600)
	_view.get_list().row_of(&"bank_array").grab_focus()
	_view.get_panel().get_button().pressed.emit()
	assert_bool(_simulation.state.research.is_running()).is_false()
	assert_int(_simulation.state.budget.funds_k).is_equal(funds - 300)
	assert_str(_view.get_panel().get_button().text).is_equal("Start")


func test_refusals_are_shown_plainly() -> void:
	_view.act(&"bank_array")
	_view.get_list().row_of(&"second_plant").grab_focus()
	var panel: ResearchPanel = _view.get_panel()
	assert_bool(panel.get_button().disabled).is_true()
	assert_str(panel.lines()[4]).is_equal("One project at a time.")
	_view.act(&"second_plant")
	assert_str(String(_simulation.state.research.active)).is_equal("bank_array")
	assert_str(panel.lines()[4]).is_equal("One project at a time.")
	_view.get_list().row_of(&"lift_shaft").grab_focus()
	assert_str(panel.lines()[4]).is_equal("One project at a time.")


func test_lab_off_refreshes_while_paused() -> void:
	_view.act(&"bank_array")
	var lab: RoomState = PowerFixture.lab(_simulation.state)
	_simulation.submit(SwitchRoomCommand.create(lab.id, false))
	assert_str(_view.get_list().header()[2]).is_equal("3 d left, paused: no lab on")
	_view.act(&"bank_array")
	_view.get_list().row_of(&"second_plant").grab_focus()
	assert_str(_view.get_panel().lines()[4]).is_equal("Needs a Research Lab that is on.")


func test_done_rows_move_to_the_bottom() -> void:
	ResearchFixture.finish(_simulation.state, &"excavation_survey")
	_view.refresh()
	var rows: Array[ResearchRow] = _view.get_list().rows()
	var last: ResearchRow = rows[rows.size() - 1]
	assert_str(String(last.project_id)).is_equal("excavation_survey")
	assert_str(last.texts()[4]).is_equal("done ✓")
	assert_str(rows[0].texts()[4]).is_equal("Start")


func test_dpad_moves_between_rows() -> void:
	var rows: Array[ResearchRow] = _view.get_list().rows()
	rows[0].grab_focus()
	await _press(&"ui_down")
	assert_object(_root.get_viewport().gui_get_focus_owner()).is_same(rows[1])
	assert_str(String(_view.get_panel().get_project())).is_equal("lift_shaft")


func test_tab_is_available_once_a_lab_has_finished() -> void:
	var state: GameState = ResearchFixture.state(false)
	_view.setup(Simulation.new(state))
	assert_bool(_view.is_available()).is_false()
	var lab: RoomState = PowerFixture.lab(state)
	lab.build_ticks_left = 60
	_view.refresh()
	EventBus.room_built.emit(&"x")
	assert_bool(_view.is_available()).is_false()
	lab.build_ticks_left = 0
	EventBus.room_built.emit(lab.id)
	assert_bool(_view.is_available()).is_true()
	state.base.rooms.erase(lab)
	EventBus.room_demolished.emit(lab.id)
	assert_bool(_view.is_available()).is_true()


func test_layout_fits_in_both_languages() -> void:
	_view.act(&"excavation_survey")
	for locale: String in ["en", "pt_BR"]:
		TranslationServer.set_locale(locale)
		await _runner.simulate_frames(2)
		var columns: Control = _view.get_node("Columns") as Control
		var needed: Vector2 = columns.get_combined_minimum_size()
		assert_bool(needed.x <= VIEW_SIZE.x - 32 and needed.y <= VIEW_SIZE.y).is_true()
		assert_float(_view.get_list().rows()[0].size.y).is_equal(ResearchRow.HEIGHT)


func _press(action: StringName) -> void:
	_runner.simulate_action_pressed(String(action))
	await _runner.await_input_processed()
