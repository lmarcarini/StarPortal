## Tests that the Base tab's build palette offers every room the player may build: each room in
## starting_room_unlocks on a new game, each room a finished research unlocks after it, and
## Quarters built from the palette in one click adding 4 beds to the Personnel header.
## Bible: docs/content/m26-staff-and-money.md section 3; docs/content/m2-base.md section 6
extends GdUnitTestSuite

const VIEW_SCENE: String = "res://src/ui/views/base/base_view.tscn"
const VIEW_SIZE: Vector2 = Vector2(1280, 640)

var _root: Control = null
var _view: BaseView = null
var _simulation: Simulation = null
var _real_locale: String = ""
var _runner: GdUnitSceneRunner = null


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var defs: GameDefs = GameDefs.from_registry(Registry)
	_simulation = GameSetup.build_new(GameState.new_game(1, defs.balance), defs).value
	_root = Control.new()
	_root.size = VIEW_SIZE
	_view = (load(VIEW_SCENE) as PackedScene).instantiate() as BaseView
	_root.add_child(_view)
	_runner = scene_runner(_root)
	_view.setup(_simulation)


func after_test() -> void:
	if is_instance_valid(_root):
		_root.free()
	TranslationServer.set_locale(_real_locale)


func test_new_game_palette_offers_every_starting_unlock() -> void:
	var palette: BuildPalette = _view.get_palette()
	for def_id: StringName in _simulation.state.balance.starting_room_unlocks:
		var button: Button = palette.get_room_button(def_id)
		assert_object(button).override_failure_message(String(def_id)).is_not_null()
		assert_bool(button.disabled).override_failure_message(String(def_id)).is_false()


func test_each_research_room_unlock_appears_after_its_project() -> void:
	var palette: BuildPalette = _view.get_palette()
	for project_id: StringName in UnlockFixture.projects():
		UnlockFixture.apply_project(_simulation.state.unlocks, project_id)
		_view.get_build().refresh()
		await get_tree().process_frame
		for pair: Array in UnlockFixture.projects()[project_id]:
			if pair[0] != UnlockRules.EFFECT_UNLOCK_ROOM:
				continue
			var def_id := StringName(str(pair[1]))
			var button: Button = palette.get_room_button(def_id)
			var label: String = "%s / %s" % [project_id, def_id]
			assert_object(button).override_failure_message(label).is_not_null()
			assert_bool(button.disabled).override_failure_message(label).is_false()


func test_quarters_shows_its_lines_and_builds_four_beds() -> void:
	var state: GameState = _simulation.state
	var palette: BuildPalette = _view.get_palette()
	var button: Button = palette.get_room_button(&"room_quarters")
	assert_object(button).is_not_null()
	button.focus_entered.emit()
	assert_str(palette.get_hint()).contains("$150k").contains("2 h")
	assert_str(palette.get_role()).is_not_empty()
	assert_str(palette.get_role()).is_equal(BasePanelText.now(state.room_defs[&"room_quarters"]))
	var beds: int = StaffRules.beds(state)
	button.pressed.emit()
	var ghost: PlacementGhost = _view.get_build().get_ghost()
	assert_bool(ghost.is_placing()).is_true()
	ghost.move_to(Vector2i(24, 11))
	assert_str(ghost.reason()).is_empty()
	ghost.confirm()
	assert_int(StaffRules.beds(state)).is_equal(beds)
	for _tick: int in state.room_defs[&"room_quarters"].build_ticks + 1:
		_simulation.advance_tick()
	assert_int(StaffRules.beds(state)).is_equal(beds + 4)
	assert_str(PersonnelText.header(state)).contains(str(beds + 4))
