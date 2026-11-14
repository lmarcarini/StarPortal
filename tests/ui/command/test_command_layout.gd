## Command in the instrument look: Finances, Factions and Requests as sub-tabs in the left
## column, opened by id from the top bar and alerts, and fitting at 1280 × 720 in pt_BR.
## Bible: docs/content/interface-pass.md section 7
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _locale: String = ""


func before_test() -> void:
	_locale = TranslationServer.get_locale()
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 13
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	TranslationServer.set_locale(_locale)
	if is_instance_valid(_shell):
		_shell.free()


func _command() -> CommandView:
	return _shell.view_switcher.get_view(ViewSwitcher.COMMAND) as CommandView


func test_sub_tabs_by_id() -> void:
	var command: CommandView = _command()
	command.show_sub_tab(CommandView.REQUESTS_ID)
	assert_bool(command.get_requests().visible).is_true()
	assert_bool(command.get_board().visible).is_false()
	command.show_sub_tab(CommandView.FACTIONS_ID)
	assert_bool(command.get_factions().visible).is_true()
	command.show_sub_tab(CommandView.FINANCES_ID)
	assert_bool(command.get_board().visible).is_true()
	assert_bool(command.get_panel().visible).is_true()


func test_top_bar_funds_open_finances_and_request_alerts_open_requests() -> void:
	_command().show_sub_tab(CommandView.REQUESTS_ID)
	_shell.top_bar.money_label.pressed.emit()
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("command")
	assert_bool(_command().get_board().visible).is_true()
	_shell.open_view(ViewSwitcher.COMMAND, &"requests")
	assert_bool(_command().get_requests().visible).is_true()


func test_fits_at_1280_in_pt_br() -> void:
	TranslationServer.set_locale("pt_BR")
	_shell.size = Vector2(1280, 720)
	_shell.view_switcher.show_view(ViewSwitcher.COMMAND)
	await _runner.simulate_frames(3)
	var columns: ThreeColumn = _command().find_child("Columns", true, false) as ThreeColumn
	assert_float(columns.get_combined_minimum_size().x).is_less_equal(1280.0)
