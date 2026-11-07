## Fit at 1280 × 720 (the view's 1280 × 640 under the top bar), measured with the real font in
## en and pt_BR: the Build and Energy sub-tabs, the "L2 +" ghost level tab, and the palette's
## Dig entry both before the dig (greyed, "Unlock: ...") and while digging (its cancel text).
## Bible: docs/content/m2-base.md section 6, docs/content/m25-lean-start.md section 3
extends GdUnitTestSuite

const VIEW_SCENE: String = "res://src/ui/views/base/base_view.tscn"
const VIEW_SIZE: Vector2 = Vector2(1280, 640)

var _root: Control = null
var _view: BaseView = null
var _simulation: Simulation = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	var defs: GameDefs = GameDefs.from_registry(Registry)
	_simulation = GameSetup.build_new(GameState.new_game(1, defs.balance), defs).value
	_root = Control.new()
	_root.size = VIEW_SIZE
	_view = (load(VIEW_SCENE) as PackedScene).instantiate() as BaseView
	_root.add_child(_view)
	scene_runner(_root)
	_view.setup(_simulation)


func after_test() -> void:
	if is_instance_valid(_root):
		_root.free()
	TranslationServer.set_locale(_real_locale)


func test_sub_tabs_ghost_tab_and_dig_entry_fit_in_both_languages() -> void:
	for locale: String in ["en", "pt_BR"]:
		TranslationServer.set_locale(locale)
		await _check(locale + " locked")
		UnlockRules.apply_project(_simulation.state.unlocks, &"excavation_survey")
		_simulation.state.budget.funds_k = 100000
		_view.get_build().refresh()
		await _check(locale + " unlocked")
		_simulation.submit(DigLevelCommand.new())
		await _check(locale + " digging")
		_simulation.submit(CancelBuildCommand.create(CancelBuildCommand.DIG_TARGET))
		_simulation.state.unlocks.dig_depth = 1


func _check(label: String) -> void:
	_view.get_build().refresh()
	for _frame: int in 3:
		await get_tree().process_frame
	var view: Rect2 = _view.get_global_rect()
	var sub_tabs: BaseSubTabs = _view.get_sub_tabs()
	for index: int in sub_tabs.tab_count:
		var tab: Rect2 = sub_tabs.get_tab_rect(index)
		(
			assert_bool(view.encloses(Rect2(sub_tabs.global_position + tab.position, tab.size)))
			. is_true()
		)
	var levels: LevelTabs = _view.find_child("LevelTabs", true, false) as LevelTabs
	for button: Node in levels.get_children():
		var control := button as Button
		if not control.visible:
			continue
		(
			assert_float(control.get_combined_minimum_size().x)
			. override_failure_message("%s %s" % [label, control.text])
			. is_less_equal(levels.size.x)
		)
	var palette: Rect2 = _view.get_palette().get_global_rect()
	var dig: DigButton = _view.get_palette().get_dig_button()
	assert_bool(view.encloses(palette)).override_failure_message(label).is_true()
	(
		assert_bool(palette.encloses(dig.get_global_rect()))
		. override_failure_message("%s %s" % [label, dig.text])
		. is_true()
	)
	assert_float(_view.get_plan().get_global_rect().end.y).is_less_equal(palette.position.y)
	assert_float(dig.get_combined_minimum_size().x).is_less_equal(dig.size.x)
