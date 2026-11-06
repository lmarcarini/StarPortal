## Tests for the Research tab: the sub-tabs and tree follow the data (node states, locked
## slots, the empty Gate tab, dots), the header shows the current project, time left and
## progress, the SELECTED panel offers Start or Cancel with the refund, every action goes
## through the commands with refusals shown plainly, the tree refreshes while paused, the
## D-pad, shoulders, (A) and the mouse work, and the layout fits 1280 × 720 in both languages.
## Bible: docs/content/m25-lean-start.md section 3
extends GdUnitTestSuite

const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")
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


func _tree() -> ResearchTree:
	return _view.get_board().get_tree_view()


func _node(id: StringName) -> ResearchNode:
	return _tree().node_of(id)


func test_sub_tabs_follow_the_data() -> void:
	var board: ResearchBoard = _view.get_board()
	assert_array(board.tab_titles()).is_equal(
		["Construction •", "Energy •", "Gate", "Alien", "Staff"]
	)
	assert_str(String(board.get_category())).is_equal("research_construction")
	assert_int(_tree().nodes().size()).is_equal(4)
	assert_array(_node(&"excavation_survey").texts()).is_equal(
		["Excavation survey", "$400k · 2 d", "Start"]
	)
	assert_array(_node(&"lift_shaft").texts()).is_equal(
		["Lift shaft", "$300k · 2 d", "needs Excavation survey"]
	)
	assert_float(_node(&"lift_shaft").modulate.a).is_less(1.0)
	assert_vector(_node(&"deep_excavation").position).is_equal(
		ResearchTree.cell_position(Vector2i(2, 0))
	)
	board.show_category(&"research_gate")
	assert_array(_tree().nodes()).is_empty()
	assert_str(_tree().empty_text()).is_equal("Nothing to research yet")
	assert_array(_view.get_panel().lines()).is_equal(["SELECTED", "", "", "", ""])
	board.show_category(&"research_staff")
	for node: ResearchNode in _tree().nodes():
		assert_array(node.texts()).is_equal(["Unknown", "Requires staff", "locked"])
	board.show_category(&"research_alien")
	assert_int(_tree().nodes().size()).is_equal(5)
	assert_str(_tree().nodes()[0].texts()[1]).is_equal("Requires an alien find")


func test_dot_leaves_a_tab_with_nothing_to_start() -> void:
	ResearchFixture.finish(_simulation.state, &"second_plant")
	ResearchFixture.finish(_simulation.state, &"fuel_contracts")
	ResearchFixture.finish(_simulation.state, &"bank_array")
	_view.refresh()
	assert_str(_view.get_board().tab_titles()[1]).is_equal("Energy")


func test_start_with_accept_shows_header_and_cancel() -> void:
	var node: ResearchNode = _node(&"excavation_survey")
	node.grab_focus()
	await _press(&"ui_accept")
	assert_str(String(_simulation.state.research.active)).is_equal("excavation_survey")
	assert_array(_view.get_board().header()).is_equal(
		["RESEARCH", "Current: Excavation survey", "2 d left"]
	)
	assert_bool(_view.get_board().get_bar().visible).is_true()
	assert_bool(node.get_bar().visible).is_true()
	assert_str(node.texts()[2]).is_equal("2 d left")
	assert_str(_view.get_panel().get_button().text).is_equal("Cancel ($200k back)")


func test_cancel_goes_through_the_command_and_refunds() -> void:
	var funds: int = _simulation.state.budget.funds_k
	_view.act(&"bank_array")
	assert_int(_simulation.state.budget.funds_k).is_equal(funds - 600)
	_view.get_board().show_category(&"research_energy")
	_node(&"bank_array").grab_focus()
	_view.get_panel().get_button().pressed.emit()
	assert_bool(_simulation.state.research.is_running()).is_false()
	assert_int(_simulation.state.budget.funds_k).is_equal(funds - 300)
	assert_str(_view.get_panel().get_button().text).is_equal("Start")


func test_refusals_are_shown_plainly() -> void:
	_view.act(&"bank_array")
	_view.get_board().show_category(&"research_energy")
	_node(&"second_plant").grab_focus()
	var panel: ResearchPanel = _view.get_panel()
	assert_bool(panel.get_button().disabled).is_true()
	assert_str(panel.lines()[4]).is_equal("One project at a time.")
	_view.act(&"second_plant")
	assert_str(String(_simulation.state.research.active)).is_equal("bank_array")
	assert_str(panel.lines()[4]).is_equal("One project at a time.")
	_node(&"fuel_contracts").grab_focus()
	assert_str(panel.lines()[4]).is_equal("One project at a time.")


func test_lab_off_refreshes_while_paused() -> void:
	_view.act(&"bank_array")
	var lab: RoomState = PowerFixture.lab(_simulation.state)
	_simulation.submit(SwitchRoomCommand.create(lab.id, false))
	assert_str(_view.get_board().header()[2]).is_equal("3 d left, paused: no lab on")
	_view.act(&"bank_array")
	_view.get_board().show_category(&"research_energy")
	_node(&"second_plant").grab_focus()
	assert_str(_view.get_panel().lines()[4]).is_equal("Needs a Research Lab that is on.")


func test_done_nodes_are_ticked() -> void:
	ResearchFixture.finish(_simulation.state, &"excavation_survey")
	_view.refresh()
	assert_str(_node(&"excavation_survey").texts()[2]).is_equal("done")
	assert_str(_node(&"lift_shaft").texts()[2]).is_equal("Start")


func test_dpad_moves_along_the_tree() -> void:
	_node(&"excavation_survey").grab_focus()
	await _press(&"ui_right")
	assert_object(_focus()).is_same(_node(&"lift_shaft"))
	assert_str(String(_view.get_panel().get_project())).is_equal("lift_shaft")
	await _press(&"ui_right")
	assert_object(_focus()).is_same(_node(&"deep_excavation"))
	await _press(&"ui_right")
	assert_object(_focus()).is_same(_node(&"deep_excavation"))
	await _press(&"ui_left")
	await _press(&"ui_left")
	await _press(&"ui_down")
	assert_object(_focus()).is_same(_node(&"field_engineering"))
	await _press(&"ui_right")
	assert_object(_focus()).is_same(_node(&"lift_shaft"))


func test_shoulders_switch_sub_tabs_then_main_tabs() -> void:
	_tree().nodes()[0].grab_focus()
	var board: ResearchBoard = _view.get_board()
	assert_bool(_shoulder(JOY_BUTTON_RIGHT_SHOULDER)).is_true()
	assert_str(String(board.get_category())).is_equal("research_energy")
	assert_object(_focus()).is_same(_node(&"second_plant"))
	assert_str(String(_view.get_panel().get_project())).is_equal("second_plant")
	assert_bool(_shoulder(JOY_BUTTON_LEFT_SHOULDER)).is_true()
	assert_bool(_shoulder(JOY_BUTTON_LEFT_SHOULDER)).is_false()
	board.show_category(&"research_staff")
	assert_bool(_shoulder(JOY_BUTTON_RIGHT_SHOULDER)).is_false()
	assert_bool(_shoulder(JOY_BUTTON_LEFT_SHOULDER)).is_true()
	assert_str(String(board.get_category())).is_equal("research_alien")
	assert_object(_focus()).is_same(_tree().nodes()[0])
	assert_bool(_shoulder(JOY_BUTTON_LEFT_SHOULDER)).is_true()
	assert_object(_focus()).is_same(board.get_tabs())


func test_mouse_click_selects_a_node() -> void:
	_view.get_board().show_category(&"research_energy")
	await _runner.simulate_frames(2)
	await UiInput.click(_node(&"bank_array"))
	assert_str(String(_view.get_panel().get_project())).is_equal("bank_array")


## Every line of every node, in every state shown and in both languages, fits the node's
## inner width in the lines it may take, measured with the label's real font; and every tree
## fits the board's width in the 1920 × 1080 layout.
func test_node_text_is_never_cut() -> void:
	_root.size = Vector2(1920, 1080)
	_view.size = _root.size
	ResearchFixture.finish(_simulation.state, &"second_plant")
	_view.act(&"excavation_survey")
	var board_width: float = 1920 - 32 - 24 - 352
	for locale: String in ["en", "pt_BR"]:
		TranslationServer.set_locale(locale)
		for category: StringName in [
			"research_construction", "research_energy", "research_alien", "research_staff"
		]:
			_view.get_board().show_category(category)
			_view.refresh()
			await _runner.simulate_frames(1)
			assert_float(_tree().custom_minimum_size.x).is_less_equal(board_width)
			for node: ResearchNode in _tree().nodes():
				_assert_fits(node, locale)


func _assert_fits(node: ResearchNode, locale: String) -> void:
	for label: Label in node.labels():
		var font: Font = label.get_theme_font(&"font")
		var font_size: int = label.get_theme_font_size(&"font_size")
		var inner: float = label.size.x
		var message: String = (
			"%s: '%s' is cut (%d/%d lines, %s)"
			% [
				locale,
				label.text,
				label.get_line_count(),
				label.get_visible_line_count(),
				label.size
			]
		)
		assert_float(label.get_global_rect().end.y).override_failure_message(message).is_less_equal(
			node.get_global_rect().end.y
		)
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var width: float = font.get_string_size(label.text, 0, -1, font_size).x
			assert_float(width).override_failure_message(message).is_less_equal(inner)
			continue
		assert_int(label.get_line_count()).override_failure_message(message).is_less_equal(
			label.get_visible_line_count()
		)


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
		# The board's share of 1280: the margins, the gap and the 352 px panel taken off.
		var board_width: float = 1280 - 32 - 24 - 352
		for category: StringName in [&"research_construction", &"research_energy"]:
			_view.get_board().show_category(category)
			assert_float(_tree().custom_minimum_size.x).is_less_equal(board_width)
			assert_float(_tree().custom_minimum_size.y).is_less_equal(VIEW_SIZE.y - 160)
		assert_vector(_tree().nodes()[0].size).is_equal(ResearchNode.SIZE)


## Sends a gamepad shoulder press to the view; true when the view took it.
func _shoulder(button: JoyButton) -> bool:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	var before: StringName = _view.get_board().get_category()
	_view._unhandled_input(event)
	return _view.get_board().get_category() != before


func _focus() -> Control:
	return _root.get_viewport().gui_get_focus_owner()


func _press(action: StringName) -> void:
	_runner.simulate_action_pressed(String(action))
	await _runner.await_input_processed()
