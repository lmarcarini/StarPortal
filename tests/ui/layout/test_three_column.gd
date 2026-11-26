## Personnel's layout: its header sits above the list, with no left column. (The Research
## tab's three columns gave way to the Lab station, card #560: tests/ui/lab/.)
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


## Owner change 2026-11-14: Personnel keeps its title, summary and sub-tabs above the list,
## with no left column.
func test_personnel_header_sits_above_the_list() -> void:
	var personnel: PersonnelView = _shell.view_switcher.get_view(ViewSwitcher.PERSONNEL)
	var board: PersonnelBoard = personnel.find_child("Board", true, false) as PersonnelBoard
	assert_object(board.get_tabs().get_parent()).is_same(board)
	assert_object(_columns(ViewSwitcher.PERSONNEL)).is_null()
