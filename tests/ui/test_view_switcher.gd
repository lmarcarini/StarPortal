## Tests for ViewSwitcher, the views it hosts and the GameView contract, run headless with the
## gdUnit4 scene runner. The switcher runs inside a plain parent Control, because the runner
## also calls the scene root's _unhandled_input directly.
## Bible: game-design.md#core-loop, technical-architecture.md#signals-and-scenes,
## technical-architecture.md#input-accessibility-and-localisation
extends GdUnitTestSuite

const SWITCHER_SCENE: String = "res://src/ui/views/view_switcher.tscn"
const SpyView := preload("res://tests/ui/fixtures/spy_view.gd")

var _root: Control = null
var _switcher: ViewSwitcher = null
var _runner: GdUnitSceneRunner = null
var _changes: Array[StringName] = []
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_changes.clear()
	await _run(_make_switcher())


func after_test() -> void:
	if is_instance_valid(_root):
		_root.free()
	TranslationServer.set_locale(_real_locale)


func test_starts_on_the_gate_room_with_translated_tabs() -> void:
	assert_array(_switcher.get_view_ids()).is_equal([&"gate_room", &"analysis"])
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")
	var tabs: TabBar = _switcher.get_tab_bar()
	assert_int(tabs.tab_count).is_equal(2)
	assert_str(tabs.get_tab_title(0)).is_equal("Gate Room")
	assert_str(tabs.get_tab_title(1)).is_equal("Analysis")
	TranslationServer.set_locale("pt_BR")
	await _runner.simulate_frames(2)
	assert_str(tabs.get_tab_title(0)).is_equal("Sala do Portal")
	assert_str(tabs.get_tab_title(1)).is_equal("Análise")
	assert_str(_view(&"gate_room").get_title_key()).is_equal("GATE_ROOM_TITLE")
	assert_str(_view(&"analysis").get_title_key()).is_equal("ANALYSIS_TITLE")


func test_view_actions_switch_and_wrap() -> void:
	await _press_action(&"view_next")
	assert_str(String(_switcher.current_view_id())).is_equal("analysis")
	await _press_action(&"view_next")
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")
	await _press_action(&"view_previous")
	assert_str(String(_switcher.current_view_id())).is_equal("analysis")
	await _press_action(&"view_previous")
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")
	await _press_action(&"view_analysis")
	assert_str(String(_switcher.current_view_id())).is_equal("analysis")
	await _press_action(&"view_analysis")
	assert_str(String(_switcher.current_view_id())).is_equal("analysis")
	await _press_action(&"view_gate_room")
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")
	var expected: Array[StringName] = [&"gate_room", &"analysis", &"gate_room", &"analysis"]
	expected.append_array([&"gate_room", &"analysis", &"gate_room"])
	assert_array(_changes).is_equal(expected)


func test_default_keys_and_gamepad_shoulders_switch_views() -> void:
	await _runner.simulate_key_pressed(KEY_E)
	assert_str(String(_switcher.current_view_id())).is_equal("analysis")
	await _runner.simulate_key_pressed(KEY_F1)
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")
	await _runner.simulate_key_pressed(KEY_F2)
	assert_str(String(_switcher.current_view_id())).is_equal("analysis")
	await _runner.simulate_key_pressed(KEY_Q)
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")
	await _press_joypad(JOY_BUTTON_LEFT_SHOULDER)
	assert_str(String(_switcher.current_view_id())).is_equal("analysis")
	await _press_joypad(JOY_BUTTON_RIGHT_SHOULDER)
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")


func test_switching_focuses_the_new_views_default_control() -> void:
	await _press_action(&"view_next")
	assert_object(_focus_owner()).is_same(_view(&"analysis").get_default_focus())
	await _press_action(&"view_gate_room")
	assert_object(_focus_owner()).is_same(_view(&"gate_room").get_default_focus())
	_switcher.show_view(&"analysis")
	assert_object(_focus_owner()).is_same(_view(&"analysis").get_default_focus())


func test_clicking_a_tab_switches_and_focuses_the_view() -> void:
	var tabs: TabBar = _switcher.get_tab_bar()
	var target: Vector2 = tabs.get_global_transform() * tabs.get_tab_rect(1).get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = target
		click.global_position = target
		_root.get_viewport().push_input(click, true)
	await _runner.await_input_processed()
	assert_str(String(_switcher.current_view_id())).is_equal("analysis")
	assert_object(_focus_owner()).is_same(_view(&"analysis").get_default_focus())


func test_moving_along_the_focused_tabs_keeps_focus_on_them() -> void:
	var tabs: TabBar = _switcher.get_tab_bar()
	tabs.grab_focus()
	await _press_action(&"ui_right")
	assert_str(String(_switcher.current_view_id())).is_equal("analysis")
	assert_object(_focus_owner()).is_same(tabs)
	await _press_action(&"ui_down")
	assert_object(_focus_owner()).is_same(_view(&"analysis").get_default_focus())
	await _press_action(&"ui_right")
	assert_object(_focus_owner()).is_same(_view(&"analysis").find_child("Board", true, false))
	await _press_action(&"ui_up")
	assert_object(_focus_owner()).is_same(tabs)
	await _press_action(&"ui_left")
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")
	await _press_action(&"ui_down")
	assert_object(_focus_owner()).is_same(_view(&"gate_room").get_default_focus())


func test_only_the_shown_view_is_visible_focusable_and_processing() -> void:
	_assert_active(&"gate_room", true)
	_assert_active(&"analysis", false)
	_switcher.show_view(&"analysis")
	_assert_active(&"gate_room", false)
	_assert_active(&"analysis", true)


func test_hidden_view_keeps_its_nodes() -> void:
	var board: Control = _view(&"analysis").find_child("Board", true, false) as Control
	_switcher.show_view(&"analysis")
	_switcher.show_view(&"gate_room")
	assert_object(_view(&"analysis").find_child("Board", true, false)).is_same(board)


func test_unknown_view_changes_nothing() -> void:
	_switcher.show_view(&"base")
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")
	assert_array(_changes).is_equal([&"gate_room"])


func test_setup_reaches_every_view_again_and_again() -> void:
	_root.free()
	var switcher: ViewSwitcher = _make_switcher()
	var spy: SpyView = SpyView.new()
	spy.name = "Spy"
	switcher.get_node("%Views").add_child(spy)
	await _run(switcher)
	assert_array(_switcher.get_view_ids()).is_equal([&"gate_room", &"analysis", &"spy"])
	assert_bool(spy.visible).is_false()
	var first := Simulation.new(GameState.new_game(1))
	var second := Simulation.new(GameState.new_game(2))
	_switcher.setup(first)
	_switcher.setup(second)
	assert_array(spy.received).is_equal([first, second])
	assert_object(_switcher.get_view(&"spy")).is_same(spy)
	await _press_action(&"view_previous")
	assert_str(String(_switcher.current_view_id())).is_equal("spy")
	assert_object(_focus_owner()).is_same(spy.get_default_focus())


func test_analysis_view_puts_workbench_beside_a_wider_board() -> void:
	_switcher.show_view(&"analysis")
	await _runner.simulate_frames(2)
	var view: GameView = _view(&"analysis")
	var workbench: Control = view.find_child("Workbench", true, false) as Control
	var board: Control = view.find_child("Board", true, false) as Control
	assert_object(workbench).is_instanceof(Workbench)
	assert_object(board).is_instanceof(AnalysisBoard)
	var share: float = workbench.size.x / (workbench.size.x + board.size.x)
	assert_float(share).is_equal_approx(0.4, 0.01)
	assert_float(workbench.position.x).is_less(board.position.x)


func _make_switcher() -> ViewSwitcher:
	return (load(SWITCHER_SCENE) as PackedScene).instantiate() as ViewSwitcher


## Runs [param switcher] inside a full-screen parent Control.
func _run(switcher: ViewSwitcher) -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(switcher)
	_switcher = switcher
	_switcher.view_changed.connect(_on_view_changed)
	_runner = scene_runner(_root)
	await _runner.await_input_processed()


func _assert_active(view_id: StringName, active: bool) -> void:
	var view: GameView = _view(view_id)
	var focus: Control = view.get_default_focus()
	var expected_focus: Control.FocusMode = Control.FOCUS_ALL if active else Control.FOCUS_NONE
	assert_bool(view.visible).override_failure_message(String(view_id)).is_equal(active)
	assert_bool(view.can_process()).override_failure_message(String(view_id)).is_equal(active)
	assert_int(focus.get_focus_mode_with_override()).is_equal(expected_focus)
	if not active:
		assert_int(focus.get_mouse_filter_with_override()).is_equal(Control.MOUSE_FILTER_IGNORE)


func _view(view_id: StringName) -> GameView:
	return _switcher.get_view(view_id)


func _press_action(action: StringName) -> void:
	_runner.simulate_action_pressed(String(action))
	await _runner.await_input_processed()


func _press_joypad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await _runner.await_input_processed()


func _focus_owner() -> Control:
	return _root.get_viewport().gui_get_focus_owner()


func _on_view_changed(view_id: StringName) -> void:
	_changes.append(view_id)
