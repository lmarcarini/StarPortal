## Research and Personnel use the three-column layout: left, board, detail, in that order,
## widths scaled, and both fit at 1280 × 720 in pt_BR at the default scale.
## Bible: docs/content/interface-pass.md section 4
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _locale: String = ""


func before_test() -> void:
	_locale = TranslationServer.get_locale()
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 12
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	TranslationServer.set_locale(_locale)
	if is_instance_valid(_shell):
		_shell.free()


func _columns(view_id: StringName) -> ThreeColumn:
	return _shell.view_switcher.get_view(view_id).find_child("Columns", true, false) as ThreeColumn


func test_left_board_detail_in_order() -> void:
	for view_id: StringName in [ViewSwitcher.RESEARCH, ViewSwitcher.PERSONNEL]:
		var columns: ThreeColumn = _columns(view_id)
		assert_object(columns.get_child(0)).is_same(columns.left)
		assert_int(columns.left.get_child_count()).is_greater(0)
		assert_float(columns.left.custom_minimum_size.x).is_equal(ThreeColumn.LEFT_WIDTH)
		assert_float(columns.detail().custom_minimum_size.x).is_equal(ThreeColumn.DETAIL_WIDTH)


func test_personnel_sub_tabs_sit_on_the_left() -> void:
	var personnel: PersonnelView = _shell.view_switcher.get_view(ViewSwitcher.PERSONNEL)
	var board: PersonnelBoard = personnel.find_child("Board", true, false) as PersonnelBoard
	assert_object(board.get_tabs().get_parent()).is_same(_columns(ViewSwitcher.PERSONNEL).left)


func test_both_fit_at_1280_in_pt_br() -> void:
	TranslationServer.set_locale("pt_BR")
	_shell.size = Vector2(1280, 720)
	_shell.view_switcher.show_view(ViewSwitcher.PERSONNEL)
	await _runner.simulate_frames(3)
	for view_id: StringName in [ViewSwitcher.PERSONNEL]:
		var columns: ThreeColumn = _columns(view_id)
		assert_float(columns.get_combined_minimum_size().x).is_less_equal(1280.0)
		assert_float(columns.detail().get_global_rect().end.x).is_less_equal(1280.5)
