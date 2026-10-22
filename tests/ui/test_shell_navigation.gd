## Tests for moving around the shell with the keyboard and a gamepad: trigger pulls on the
## time speed, switching views and walking focus through the top bar, the tabs and each view.
## Saves go to a temporary user:// folder, never user://saves.
## Bible: technical-architecture.md#input-accessibility-and-localisation,
## technical-architecture.md#signals-and-scenes, game-design.md#core-loop
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"
const TEST_SEED: int = 12345

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
