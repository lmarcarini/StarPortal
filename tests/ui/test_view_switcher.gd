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
## An event a test bound to a view action; after_test removes it.
var _extra_event: InputEvent = null


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_changes.clear()
	await _run(_make_switcher())


func after_test() -> void:
	if is_instance_valid(_root):
		_root.free()
	if _extra_event != null:
		InputMap.action_erase_event(&"view_next", _extra_event)
		_extra_event = null
	TranslationServer.set_locale(_real_locale)


func test_starts_on_the_gate_room_with_translated_tabs() -> void:
	assert_array(_switcher.get_view_ids()).is_equal([&"gate_room", &"archive"])
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")
	var tabs: TabBar = _switcher.get_tab_bar()
	assert_int(tabs.tab_count).is_equal(2)
	assert_str(tabs.get_tab_title(0)).is_equal("Gate Room")
	assert_str(tabs.get_tab_title(1)).is_equal("Archive")
	TranslationServer.set_locale("pt_BR")
	await _runner.simulate_frames(2)
	assert_str(tabs.get_tab_title(0)).is_equal("Sala do Portal")
	assert_str(tabs.get_tab_title(1)).is_equal("Arquivo")
	assert_str(_view(&"gate_room").get_title_key()).is_equal("GATE_ROOM_TITLE")
	assert_str(_view(&"archive").get_title_key()).is_equal("ARCHIVE_TITLE")


func test_view_actions_switch_and_wrap() -> void:
	await _press_action(&"view_next")
	assert_str(String(_switcher.current_view_id())).is_equal("archive")
	await _press_action(&"view_next")
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")
	await _press_action(&"view_previous")
	assert_str(String(_switcher.current_view_id())).is_equal("archive")
	await _press_action(&"view_previous")
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")
	await _press_action(&"view_archive")
	assert_str(String(_switcher.current_view_id())).is_equal("archive")
	await _press_action(&"view_archive")
	assert_str(String(_switcher.current_view_id())).is_equal("archive")
	await _press_action(&"view_gate_room")
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")
	var expected: Array[StringName] = [&"gate_room", &"archive", &"gate_room", &"archive"]
	expected.append_array([&"gate_room", &"archive", &"gate_room"])
	assert_array(_changes).is_equal(expected)


func test_default_keys_and_gamepad_shoulders_switch_views() -> void:
	await _runner.simulate_key_pressed(KEY_E)
	assert_str(String(_switcher.current_view_id())).is_equal("archive")
	await _runner.simulate_key_pressed(KEY_F1)
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")
	await _runner.simulate_key_pressed(KEY_F2)
	assert_str(String(_switcher.current_view_id())).is_equal("archive")
	await _runner.simulate_key_pressed(KEY_Q)
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")
	await _press_joypad(JOY_BUTTON_LEFT_SHOULDER)
	assert_str(String(_switcher.current_view_id())).is_equal("archive")
	await _press_joypad(JOY_BUTTON_RIGHT_SHOULDER)
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")


func test_switching_focuses_the_new_views_default_control() -> void:
	await _press_action(&"view_next")
	assert_object(_focus_owner()).is_same(_view(&"archive").get_default_focus())
	await _press_action(&"view_gate_room")
	assert_object(_focus_owner()).is_same(_view(&"gate_room").get_default_focus())
	_switcher.show_view(&"archive")
	assert_object(_focus_owner()).is_same(_view(&"archive").get_default_focus())


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
	assert_str(String(_switcher.current_view_id())).is_equal("archive")
	assert_object(_focus_owner()).is_same(_view(&"archive").get_default_focus())


func test_moving_along_the_focused_tabs_keeps_focus_on_them() -> void:
	var tabs: TabBar = _switcher.get_tab_bar()
	tabs.grab_focus()
	await _press_action(&"ui_right")
	assert_str(String(_switcher.current_view_id())).is_equal("archive")
	assert_object(_focus_owner()).is_same(tabs)
	await _press_action(&"ui_down")
	assert_object(_focus_owner()).is_same(_view(&"archive").get_default_focus())
	await _press_action(&"ui_right")
	assert_object(_focus_owner()).is_same(_view(&"archive").get_default_focus())
	await _press_action(&"ui_up")
	assert_object(_focus_owner()).is_same(tabs)
	await _press_action(&"ui_left")
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")
	await _press_action(&"ui_down")
	assert_object(_focus_owner()).is_same(_view(&"gate_room").get_default_focus())


func test_only_the_shown_view_is_visible_focusable_and_processing() -> void:
	_assert_active(&"gate_room", true)
	_assert_active(&"archive", false)
	_switcher.show_view(&"archive")
	_assert_active(&"gate_room", false)
	_assert_active(&"archive", true)


## A view action rebound to an axis switches once per pull, however many motion events the
## pull sends, and again on the next pull.
func test_view_action_on_an_axis_fires_once_per_pull() -> void:
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 1.0
	stick.device = -1
	_extra_event = stick
	InputMap.action_add_event(&"view_next", stick)
	await _move_axis(JOY_AXIS_RIGHT_X, [0.1, 0.4, 0.8, 1.0, 1.0, 0.6, 0.3, 0.0])
	assert_str(String(_switcher.current_view_id())).is_equal("archive")
	await _move_axis(JOY_AXIS_RIGHT_X, [0.9, 1.0, 0.0])
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")
	await _move_axis(JOY_AXIS_RIGHT_X, [-0.9, -1.0, 0.0])
	assert_str(String(_switcher.current_view_id())).is_equal("gate_room")


## Hiding and showing a view restores its root's own modes and leaves a descendant that is
## disabled on purpose disabled.
func test_showing_a_view_restores_only_what_hiding_changed() -> void:
	var view: GameView = _view(&"gate_room")
	var seal: Control = view.find_child("Seal1", true, false) as Control
	_switcher.show_view(&"gate_room")
	view.process_mode = Node.PROCESS_MODE_ALWAYS
	view.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	seal.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_switcher.show_view(&"archive")
	_assert_active(&"gate_room", false)
	_switcher.show_view(&"archive")
	_switcher.show_view(&"gate_room")
	assert_int(view.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	assert_int(view.mouse_behavior_recursive).is_equal(Control.MOUSE_BEHAVIOR_DISABLED)
	assert_int(view.focus_behavior_recursive).is_equal(Control.FOCUS_BEHAVIOR_INHERITED)
	assert_int(seal.focus_behavior_recursive).is_equal(Control.FOCUS_BEHAVIOR_DISABLED)
	assert_int(seal.get_focus_mode_with_override()).is_equal(Control.FOCUS_NONE)
	assert_int(view.get_default_focus().get_focus_mode_with_override()).is_equal(Control.FOCUS_ALL)


func test_hidden_view_keeps_its_nodes() -> void:
	var console: Control = _view(&"gate_room").find_child("DialConsole", true, false) as Control
	_switcher.show_view(&"archive")
	_switcher.show_view(&"gate_room")
	assert_object(_view(&"gate_room").find_child("DialConsole", true, false)).is_same(console)


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
	assert_array(_switcher.get_view_ids()).is_equal([&"gate_room", &"archive", &"spy"])
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


## The Archive view holds the document list and the reader, not the dial console; with no
## simulation its list is empty and the kind filter takes focus.
func test_archive_view_holds_the_list_and_the_reader() -> void:
	_switcher.show_view(&"archive")
	await _runner.simulate_frames(2)
	var view: ArchiveView = _view(&"archive") as ArchiveView
	assert_object(view).is_not_null()
	assert_object(view.find_child("DialConsole", true, false)).is_null()
	assert_object(view.get_reader()).is_instanceof(DocumentReader)
	assert_array(view.get_list().get_rows()).is_empty()
	assert_object(view.get_default_focus()).is_same(view.get_list().get_filter_button())
	assert_object(_focus_owner()).is_same(view.get_default_focus())


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


## Moves [param axis] through [param values], one motion event each, sent from a process
## frame as the engine sends real ones.
func _move_axis(axis: JoyAxis, values: Array[float]) -> void:
	await get_tree().process_frame
	for value: float in values:
		var event := InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = value
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await _runner.await_input_processed()


func _focus_owner() -> Control:
	return _root.get_viewport().gui_get_focus_owner()


func _on_view_changed(view_id: StringName) -> void:
	_changes.append(view_id)
