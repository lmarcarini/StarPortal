## Tests for building from the Base tab: the palette places rooms through the ghost (valid and
## invalid with reasons), rotate, hold to build, corridor painting, cancel and demolish with
## refunds, dig, the Gate Room button's alcove ghost, the signature, and the 1280 × 720 fit.
## Bible: docs/content/m2-base.md sections 2, 4 and 6
extends GdUnitTestSuite

const VIEW_SCENE: String = "res://src/ui/views/base/base_view.tscn"
const VIEW_SIZE: Vector2 = Vector2(1280, 640)

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
	add_child(_root)
	_view.setup(_simulation)


func after_test() -> void:
	if is_instance_valid(_root):
		_root.free()
	TranslationServer.set_locale(_real_locale)


func _ghost() -> PlacementGhost:
	return _view.get_build().get_ghost()


func _count(def_id: StringName) -> int:
	var found: int = 0
	for room: RoomState in _simulation.state.base.rooms:
		if room.def_id == def_id:
			found += 1
	return found


func test_capacitor_bank_button_places_the_ghost_and_one_hold_builds() -> void:
	_view.place_capacitor_bank()
	var ghost: PlacementGhost = _ghost()
	assert_bool(ghost.is_placing()).is_true()
	assert_int(_view.get_plan().level).is_equal(3)
	assert_str(ghost.reason()).is_empty()
	var funds: int = _simulation.state.budget.funds_k
	ghost.begin_hold()
	ghost.advance(HoldButton.HOLD_SECONDS + 0.1)
	assert_int(_count(StartingBase.CAPACITOR_BANK_DEF)).is_equal(1)
	assert_int(_simulation.state.budget.funds_k).is_equal(funds - 600)
	assert_bool(ghost.is_placing()).is_false()
	assert_bool(CapacitorGauge.needs_bank(_simulation.state)).is_false()


func test_invalid_spots_say_why() -> void:
	var ghost: PlacementGhost = _ghost()
	_view.get_build().start_placing(&"room_physics_lab")
	ghost.move_to(Vector2i(15, 5))
	assert_str(ghost.reason()).is_equal("Overlaps the Gate Room.")
	ghost.move_to(Vector2i(34, 0))
	assert_str(ghost.reason()).is_equal("Outside the level.")
	ghost.move_to(Vector2i(0, 0))
	assert_str(ghost.reason()).is_equal("Must touch a corridor.")
	_simulation.state.budget.funds_k = 100
	ghost.recheck()
	ghost.move_to(Vector2i(4, 16))
	assert_str(ghost.reason()).is_equal("Needs $800k; you have $100k.")
	ghost.begin_hold()
	ghost.advance(1.0)
	assert_int(_count(&"room_physics_lab")).is_equal(0)


func test_every_catalogue_room_has_a_palette_button_and_summary() -> void:
	for def_id: StringName in BuildPalette.ROOMS:
		var button: Button = _view.get_palette().get_room_button(def_id)
		assert_object(button).is_not_null()
		var def: RoomDef = _simulation.state.room_defs[def_id]
		assert_str(BuildText.summary(def)).contains(MoneyLabel.format_k(def.build_cost_k))


func test_rotate_turns_the_ghost() -> void:
	var ghost: PlacementGhost = _ghost()
	_view.get_build().start_placing(&"room_physics_lab")
	ghost.move_to(Vector2i(4, 16))
	assert_object(ghost.area().size).is_equal(Vector2i(4, 3))
	ghost.rotate_ghost()
	assert_object(ghost.area().size).is_equal(Vector2i(3, 4))


func test_corridor_painting_builds_one_run() -> void:
	var ghost: PlacementGhost = _ghost()
	_view.get_build().start_placing(StartingBase.CORRIDOR_DEF)
	ghost.move_to(Vector2i(10, 16))
	ghost.move_to(Vector2i(10, 17))
	ghost.move_to(Vector2i(11, 17))
	assert_int(ghost.run.size()).is_equal(3)
	ghost.move_to(Vector2i(10, 17))
	assert_int(ghost.run.size()).is_equal(2)
	var before: int = _count(StartingBase.CORRIDOR_DEF)
	ghost.confirm()
	assert_int(_count(StartingBase.CORRIDOR_DEF)).is_equal(before + 2)


func test_cancel_site_shows_and_pays_the_refund() -> void:
	_view.place_capacitor_bank()
	_ghost().confirm()
	var site: RoomState = _simulation.state.base.rooms[-1]
	_view.get_plan().select(site.id)
	var panel: RoomPanel = _view.get_room_panel()
	assert_str(panel.get_action_button().text).contains("$450k")
	var funds: int = _simulation.state.budget.funds_k
	panel.get_action_button().begin_hold()
	panel.get_action_button().advance(1.0)
	assert_int(_simulation.state.budget.funds_k).is_equal(funds + 450)
	assert_int(_count(StartingBase.CAPACITOR_BANK_DEF)).is_equal(0)


func test_demolish_refused_for_the_gate_room_and_allowed_for_quarters() -> void:
	var panel: RoomPanel = _view.get_room_panel()
	var gate: RoomState = _find(StartingBase.GATE_ROOM_DEF)
	_view.get_plan().select(gate.id)
	assert_bool(panel.get_action_button().disabled).is_true()
	assert_str(panel.get_action_reason()).is_equal("The Gate and Control Rooms stay.")
	_view.get_plan().show_level(1)
	var quarters: RoomState = _find(&"room_quarters")
	_view.get_plan().select(quarters.id)
	assert_str(panel.get_action_button().text).contains("$75k")
	panel.get_action_button().begin_hold()
	panel.get_action_button().advance(1.0)
	assert_bool(quarters.is_demolishing()).is_true()


func test_dig_button_digs_and_cancels() -> void:
	var dig: DigButton = _view.get_palette().get_dig_button()
	assert_str(dig.text).is_equal("Dig Level 4: $3,000k, 20 d")
	dig.begin_hold()
	dig.advance(1.0)
	assert_int(_simulation.state.base.digging_level()).is_equal(4)
	assert_int(_view.get_plan().get_parent().get_parent().get_child_count()).is_greater(0)
	assert_str(dig.text).contains("$1,500k")
	dig.begin_hold()
	dig.advance(1.0)
	assert_int(_simulation.state.base.digging_level()).is_equal(0)


func test_signature_includes_room_ids_and_positions() -> void:
	var base: BaseState = _simulation.state.base
	var before: int = BaseView.signature(base)
	base.rooms[-1].origin += Vector2i.RIGHT
	assert_int(BaseView.signature(base)).is_not_equal(before)


func test_palette_fits_1280_by_720_in_both_languages() -> void:
	for locale: String in ["en", "pt_BR"]:
		TranslationServer.set_locale(locale)
		_view.get_build().refresh()
		await get_tree().process_frame
		var palette: BuildPalette = _view.get_palette()
		assert_float(palette.get_combined_minimum_size().y).is_less_equal(72.0)
		assert_float(palette.get_combined_minimum_size().x).is_less_equal(VIEW_SIZE.x)


func _find(def_id: StringName) -> RoomState:
	for room: RoomState in _simulation.state.base.rooms:
		if room.def_id == def_id:
			return room
	return null
