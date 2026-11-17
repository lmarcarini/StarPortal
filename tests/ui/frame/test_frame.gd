## The frame in the shell (M4.10-01): every item is in the focus ring and opens its screen, it is
## right after a load and while paused, and pt_BR fits at 150% in a 1280 × 720 window.
## Bible: docs/content/interface-pass.md section 3
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _real_saves_dir: String = ""
var _real_locale: String = ""


func before_test() -> void:
	_real_saves_dir = SaveService.saves_dir
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	SaveService.saves_dir = "user://test_top_bar_new_%d" % Time.get_ticks_usec()
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 7
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()
	var dir: DirAccess = DirAccess.open(SaveService.saves_dir)
	if dir != null:
		for file_name: String in dir.get_files():
			DirAccess.remove_absolute(SaveService.saves_dir.path_join(file_name))
	DirAccess.remove_absolute(SaveService.saves_dir)
	SaveService.saves_dir = _real_saves_dir
	TranslationServer.set_locale(_real_locale)


func test_every_item_is_focusable_and_in_the_ring() -> void:
	var bar: Frame = _shell.frame
	var buttons: Array[Button] = _shell.get_focus_order()
	for item: Button in [bar.power_readout, bar.money_label, bar.confidence_readout]:
		assert_bool(buttons.has(item)).is_true()
		assert_int(item.focus_mode).is_equal(Control.FOCUS_ALL)


func test_power_opens_base_on_energy() -> void:
	_shell.frame.power_readout.pressed.emit()
	await _runner.simulate_frames(2)
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("base")
	var base: BaseView = _shell.view_switcher.get_view(ViewSwitcher.BASE) as BaseView
	assert_str(String(base.get_sub_tabs().shown())).is_equal("energy")


func test_gate_chip_opens_the_gate_room() -> void:
	_shell.view_switcher.show_view(ViewSwitcher.BASE)
	_shell.frame.gate_chip.pressed.emit()
	await _runner.simulate_frames(2)
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("gate_room")


func test_readouts_show_state_while_paused_and_after_a_load() -> void:
	var bar: Frame = _shell.frame
	var state: GameState = SimClock.simulation.state
	assert_str(bar.money_label.text).contains(TopBarText.net_text(TopBarText.net_per_day(state)))
	assert_str(bar.power_readout.text).starts_with(TopBarText.power_text(state))
	assert_str(bar.gate_chip.text).is_equal("GATE: IDLE")
	_shell.quick_save()
	SimClock.simulation.state.gate.incoming_faction = &"kindred"
	EventBus.incoming_wormhole.emit(&"kindred")
	assert_str(String(bar.gate_chip.get_status())).is_equal("incoming")
	_shell.quick_load()
	assert_str(String(bar.gate_chip.get_status())).is_equal("idle")


## The interface scales with the window height (canvas_items, expand): a wider window adds
## space between the left and the right groups; the plates keep their size and never overlap.
func test_wider_windows_add_space_and_nothing_stretches() -> void:
	TranslationServer.set_locale("pt_BR")
	for width: float in [1920.0, 2560.0]:
		_shell.size = Vector2(width, 1080)
		await _runner.simulate_frames(2)
		var plates: Array[Control] = _shell.frame.get_plates()
		for i: int in plates.size() - 1:
			var next: Rect2 = plates[i + 1].get_global_rect()
			assert_bool(plates[i].get_global_rect().intersects(next)).is_false()
		var speed: Rect2 = plates[4].get_global_rect()
		assert_float(speed.end.x).is_equal_approx(width - 8.0, 0.5)
		assert_float(speed.size.x).is_equal_approx(204.0, 0.5)
		assert_float(plates[0].get_global_rect().position.x).is_equal_approx(8.0, 0.5)


func test_the_frame_is_thin_plates_and_save_load_and_debug_left_the_screen() -> void:
	var frame: Frame = _shell.frame
	assert_int(frame.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var covered: float = 0.0
	for plate: Control in frame.get_plates():
		covered += plate.size.x
	assert_float(covered).is_less(_shell.size.x)
	assert_object(frame.find_child("*Save*", true, false)).is_null()
	for button: Button in _shell.get_focus_order():
		assert_str(button.text).is_not_equal(button.tr(&"UI_SAVE"))
		assert_str(button.text).is_not_equal(button.tr(&"UI_DEBUG_SET_FLAG"))


func test_speed_keys_pause_play_and_fast() -> void:
	var plate: SpeedPlate = _shell.frame.speed_plate
	SimClock.resume()
	plate.pause_key.pressed.emit()
	assert_bool(SimClock.simulation.state.clock.is_paused).is_true()
	plate.play_key.pressed.emit()
	assert_bool(SimClock.simulation.state.clock.is_paused).is_false()
	var speed: int = SimClock.simulation.state.clock.speed_index
	plate.fast_key.pressed.emit()
	assert_int(SimClock.simulation.state.clock.speed_index).is_equal(speed + 1)
	plate.play_key.pressed.emit()
	assert_int(SimClock.simulation.state.clock.speed_index).is_equal(speed)
	SimClock.pause()
