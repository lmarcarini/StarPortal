## Tests for the room roles (m25-lean-start.md section 4): the palette's "now" line on hover or
## focus, "Unlock: <project>" for research-locked rooms, the SELECTED panel's "now" and "later"
## lines and its upkeep with research overrides, every offered room's lines in both languages,
## and the 1280 × 720 fit of the longest lines.
## Bible: docs/content/m25-lean-start.md section 4
extends GdUnitTestSuite

const VIEW_SCENE: String = "res://src/ui/views/base/base_view.tscn"
const VIEW_SIZE: Vector2 = Vector2(1280, 640)
const LOCALES: Array[String] = ["en", "pt_BR"]
## Every room the M2.5 base offers or starts with.
const OFFERED: Array[StringName] = [
	&"room_gate",
	&"room_control",
	&"room_power_plant",
	&"room_capacitor_bank",
	&"room_research_lab",
	&"room_workshop",
	&"room_stairs",
	&"room_lift",
	&"room_corridor",
]

var _root: Control = null
var _view: BaseView = null
var _simulation: Simulation = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
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


func test_every_offered_room_has_now_and_later_in_both_languages() -> void:
	for locale: String in LOCALES:
		TranslationServer.set_locale(locale)
		for def_id: StringName in OFFERED:
			var def: RoomDef = _simulation.state.room_defs[def_id]
			var message: String = "%s %s" % [locale, def_id]
			var now: String = BasePanelText.now(def)
			assert_str(now).override_failure_message(message).is_not_equal(def.description_key)
			assert_str(String(def.description_key)).ends_with("_NOW")
			var later_key: String = BasePanelText.later_key(def)
			var later: String = TranslationServer.translate(StringName(later_key))
			assert_str(later).override_failure_message(message).is_not_equal(later_key)
			assert_str(BasePanelText.later(def)).contains(later)


func test_hovering_a_room_shows_its_summary_and_now_line() -> void:
	var palette: BuildPalette = _view.get_palette()
	palette.get_room_button(&"room_research_lab").mouse_entered.emit()
	var time: String = BuildText.duration(_def(&"room_research_lab").build_ticks)
	assert_str(palette.get_hint()).is_equal("Research Lab: $800k, %s. Draw 5 MW." % time)
	assert_str(palette.get_role()).is_equal("Runs one research project at a time.")
	palette.get_room_button(&"room_corridor").focus_entered.emit()
	assert_str(palette.get_role()).is_equal("Connects rooms. One cell.")
	palette.show_message("Placed.")
	assert_str(palette.get_role()).is_empty()


func test_research_locked_rooms_are_greyed_with_their_project() -> void:
	var palette: BuildPalette = _view.get_palette()
	var expected: Dictionary[StringName, String] = {
		&"room_power_plant": "Unlock: Second plant",
		&"room_workshop": "Unlock: Field engineering",
		&"room_lift": "Unlock: Lift shaft",
		&"room_stairs": "Unlock: Excavation survey",
	}
	for def_id: StringName in expected:
		var button: Button = palette.get_room_button(def_id)
		assert_bool(button.disabled).override_failure_message(String(def_id)).is_true()
		button.focus_entered.emit()
		assert_str(palette.get_role()).is_equal(expected[def_id])
	assert_object(palette.get_room_button(&"room_quarters")).is_null()
	assert_object(palette.get_room_button(&"room_infirmary")).is_null()
	assert_object(palette.first_button()).is_equal(palette.get_room_button(&"room_capacitor_bank"))


func test_selected_panel_shows_now_and_later_lines() -> void:
	var gate: RoomState = _find(StartingBase.GATE_ROOM_DEF)
	_view.get_plan().select(gate.id)
	var lines: Array[String] = _view.get_room_panel().lines()
	assert_str(lines[6]).is_equal("The Ring and its dial console. Always on.")
	assert_str(lines[7]).is_equal("Later: Gains the Shutter, telemetry and new seals.")
	TranslationServer.set_locale("pt_BR")
	_view.get_plan().select(&"")
	_view.get_plan().select(gate.id)
	lines = _view.get_room_panel().lines()
	assert_str(lines[7]).is_equal("Depois: Ganha o Obturador, telemetria e novos selos.")


func test_panel_upkeep_uses_the_fuel_contracts_override() -> void:
	var plant: RoomState = _find(&"room_power_plant")
	assert_object(plant).is_not_null()
	_view.get_plan().select(plant.id)
	var before: String = _view.get_room_panel().lines()[4]
	assert_str(before).contains(str(_def(&"room_power_plant").upkeep_k))
	UnlockRules.apply_project(_simulation.state.unlocks, &"fuel_contracts")
	_view.get_plan().select(&"")
	_view.get_plan().select(plant.id)
	assert_str(_view.get_room_panel().lines()[4]).is_equal("Upkeep $100k / month")


func test_longest_lines_fit_1280_by_720_in_both_languages() -> void:
	var palette: BuildPalette = _view.get_palette()
	for locale: String in LOCALES:
		TranslationServer.set_locale(locale)
		palette.get_room_button(&"room_workshop").focus_entered.emit()
		_view.get_plan().select(_find(&"room_power_plant").id)
		for _frame: int in 3:
			await get_tree().process_frame
		var view: Rect2 = _view.get_global_rect()
		var message: String = locale
		(
			assert_bool(view.encloses(palette.get_global_rect()))
			. override_failure_message(message)
			. is_true()
		)
		var panel: Rect2 = _view.get_room_panel().get_global_rect()
		assert_bool(view.encloses(panel)).override_failure_message(message).is_true()
		var plan: Rect2 = _view.get_plan().get_global_rect()
		assert_float(plan.end.y).is_less_equal(palette.get_global_rect().position.y)


func _def(def_id: StringName) -> RoomDef:
	return _simulation.state.room_defs[def_id]


func _find(def_id: StringName) -> RoomState:
	for room: RoomState in _simulation.state.base.rooms:
		if room.def_id == def_id:
			return room
	return null
