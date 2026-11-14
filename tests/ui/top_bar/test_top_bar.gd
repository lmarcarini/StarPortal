## The top bar in the shell: every item is in the focus ring and opens its screen, it is
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
	var bar: TopBar = _shell.top_bar
	var buttons: Array[Button] = _shell.get_focus_order()
	for item: Button in [bar.power_readout, bar.gate_chip, bar.alerts_button, bar.money_label]:
		assert_bool(buttons.has(item)).is_true()
		assert_int(item.focus_mode).is_equal(Control.FOCUS_ALL)


func test_power_opens_base_on_energy() -> void:
	_shell.top_bar.power_readout.pressed.emit()
	await _runner.simulate_frames(2)
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("base")
	var base: BaseView = _shell.view_switcher.get_view(ViewSwitcher.BASE) as BaseView
	assert_str(String(base.get_sub_tabs().shown())).is_equal("energy")


func test_gate_chip_opens_the_gate_room() -> void:
	_shell.view_switcher.show_view(ViewSwitcher.BASE)
	_shell.top_bar.gate_chip.pressed.emit()
	await _runner.simulate_frames(2)
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("gate_room")


func test_readouts_show_state_while_paused_and_after_a_load() -> void:
	var bar: TopBar = _shell.top_bar
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


func test_pt_br_fits_at_150_percent_in_1280_by_720() -> void:
	TranslationServer.set_locale("pt_BR")
	Settings.setting_changed.emit(&"display", &"ui_scale", 1.5)
	_shell.theme = UiThemeBuilder.build(1.5)
	_shell.size = Vector2(1280, 720)
	await _runner.simulate_frames(4)
	var bar: TopBar = _shell.top_bar
	assert_float(bar.size.x).is_less_equal(1280.0)
	for item: Control in bar.row.get_children():
		if not item.visible:
			continue
		var rect: Rect2 = item.get_global_rect()
		assert_float(rect.end.x).is_less_equal(1280.0)
	assert_float(_shell.view_switcher.offset_top).is_equal_approx(bar.size.y, 0.5)
