## Tests for moving around the shell with the keyboard and a gamepad: trigger pulls on the
## time speed, switching views and walking focus through the top bar, the tabs and each view.
## Saves go to a temporary user:// folder, never user://saves.
## Bible: technical-architecture.md#input-accessibility-and-localisation,
## technical-architecture.md#signals-and-scenes, game-design.md#core-loop
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"
const TEST_SEED: int = 12345
const SpyView := preload("res://tests/ui/fixtures/spy_view.gd")

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _real_saves_dir: String = ""
var _real_locale: String = ""


func before_test() -> void:
	_real_saves_dir = SaveService.saves_dir
	_real_locale = TranslationServer.get_locale()
	SaveService.saves_dir = (
		"user://test_shell_navigation_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	)
	TranslationServer.set_locale("en")
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = TEST_SEED
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()
	_remove_dir(SaveService.saves_dir)
	SaveService.saves_dir = _real_saves_dir
	TranslationServer.set_locale(_real_locale)


## A trigger sends a stream of motion events as it moves; one pull steps the speed once, and
## only a new pull past the deadzone steps it again.
func test_one_trigger_pull_steps_the_speed_once() -> void:
	var clock: ClockState = SimClock.simulation.state.clock
	await _pull_trigger(JOY_AXIS_TRIGGER_RIGHT, [0.1, 0.3, 0.6, 0.9, 1.0, 0.7, 0.4, 0.0])
	assert_int(clock.speed_index).is_equal(2)
	await _pull_trigger(JOY_AXIS_TRIGGER_RIGHT, [0.5, 1.0, 0.0])
	assert_int(clock.speed_index).is_equal(3)
	await _pull_trigger(JOY_AXIS_TRIGGER_LEFT, [0.15, 0.1, 0.0])
	assert_int(clock.speed_index).is_equal(3)
	await _pull_trigger(JOY_AXIS_TRIGGER_LEFT, [0.8, 1.0, 0.9, 0.0])
	assert_int(clock.speed_index).is_equal(2)


## The view actions switch views inside the running shell, and the time actions still work.
func test_view_actions_switch_views_in_the_shell() -> void:
	var switcher: ViewSwitcher = _shell.view_switcher
	assert_str(String(switcher.current_view_id())).is_equal("gate_room")
	await _press_action(&"view_next")
	assert_str(String(switcher.current_view_id())).is_equal("archive")
	assert_object(_focus_owner()).is_same(switcher.get_view(&"archive").get_default_focus())
	await _press_action(&"time_toggle_pause")
	assert_bool(SimClock.simulation.state.clock.is_paused).is_false()
	await _press_joypad(JOY_BUTTON_RIGHT_SHOULDER)
	assert_str(String(switcher.current_view_id())).is_equal("gate_room")
	assert_int(SimClock.simulation.state.clock.speed_index).is_equal(1)


## Every view gets the new simulation at start and again after a quick load.
func test_quick_load_sets_up_every_view_with_the_new_simulation() -> void:
	var spy: SpyView = await _restart_with_spy_view()
	var started: Simulation = SimClock.simulation
	assert_array(spy.received).is_equal([started])
	# Called directly: the scene runner also calls the root's _unhandled_input itself, so a
	# simulated quick_load action would load twice.
	_shell.quick_save()
	_shell.quick_load()
	var loaded: Simulation = SimClock.simulation
	assert_object(loaded).is_not_same(started)
	assert_array(spy.received).is_equal([started, loaded])


## Frees the shell from before_test and runs a new one with a SpyView added to its views.
func _restart_with_spy_view() -> SpyView:
	_shell.free()
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = TEST_SEED
	var spy: SpyView = SpyView.new()
	spy.name = "Spy"
	_shell.get_node("%ViewSwitcher").get_node("%Views").add_child(spy)
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()
	return spy


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
	return _shell.get_viewport().gui_get_focus_owner()


## Moves trigger [param axis] through [param values], one motion event each. The events are
## sent from a process frame, as the engine sends real ones: inside a physics frame Input
## checks "just pressed" against physics frames instead.
func _pull_trigger(axis: JoyAxis, values: Array[float]) -> void:
	await get_tree().process_frame
	for value: float in values:
		var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = value
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await _runner.await_input_processed()


func _remove_dir(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
