## Tests for the top bar's funds and Conf. readouts: focusable buttons that open the Command
## tab by gamepad (A) and by mouse click, in the shell's focus ring.
## Bible: docs/content/m27-daily-rhythm.md section 4
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _real_saves_dir: String = ""


func before_test() -> void:
	_real_saves_dir = SaveService.saves_dir
	SaveService.saves_dir = "user://test_top_bar_saves_%d" % Time.get_ticks_usec()
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 7
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()
	SaveService.saves_dir = _real_saves_dir


func test_readouts_are_in_the_focus_ring() -> void:
	var buttons: Array[Button] = _shell.get_focus_order()
	assert_bool(buttons.has(_shell.money_label)).is_true()
	assert_bool(buttons.has(_shell.confidence_readout)).is_true()
	assert_int(_shell.money_label.focus_mode).is_equal(Control.FOCUS_ALL)


## The funds and Conf. readouts open the Command tab by gamepad (A) and by mouse click.
func test_funds_and_confidence_open_command_by_gamepad_and_mouse() -> void:
	var switcher: ViewSwitcher = _shell.view_switcher
	for button: Button in [_shell.money_label, _shell.confidence_readout]:
		switcher.show_view(ViewSwitcher.GATE_ROOM)
		await _runner.simulate_frames(2)
		button.grab_focus()
		await _press_joypad(JOY_BUTTON_A)
		assert_str(String(switcher.current_view_id())).is_equal("command")
		switcher.show_view(ViewSwitcher.GATE_ROOM)
		await _runner.simulate_frames(2)
		await _click(button)
		assert_str(String(switcher.current_view_id())).is_equal("command")
		assert_object(_focus_owner()).is_same(
			switcher.get_view(ViewSwitcher.COMMAND).get_default_focus()
		)


func _focus_owner() -> Control:
	return _shell.get_viewport().gui_get_focus_owner()


func _press_joypad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await _runner.await_input_processed()


## Clicks the left mouse button over the centre of [param control].
func _click(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		control.get_viewport().push_input(event, true)
	await _runner.simulate_frames(2)
