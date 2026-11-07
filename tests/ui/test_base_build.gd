## Tests for building from the Base tab: the palette places rooms through the ghost (valid and
## invalid with reasons), rotate, one click to build, corridor painting, cancel and demolish with
## refunds, dig, the Gate Room button's bank ghost, the signature, and the 1280 × 720 fit.
## Bible: docs/content/m2-base.md sections 2, 4 and 6
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


func _ghost() -> PlacementGhost:
	return _view.get_build().get_ghost()


func _count(def_id: StringName) -> int:
	var found: int = 0
	for room: RoomState in _simulation.state.base.rooms:
		if room.def_id == def_id:
			found += 1
	return found


func test_capacitor_bank_button_places_the_ghost_and_one_click_builds() -> void:
	_view.place_capacitor_bank()
	var ghost: PlacementGhost = _ghost()
	assert_bool(ghost.is_placing()).is_true()
	assert_int(_view.get_plan().level).is_equal(1)
	var spot: Vector2i = BaseSpots.bank_spot(_simulation.state.base, _simulation.state.room_defs)
	assert_vector(Vector2(ghost.origin)).is_equal(Vector2(spot))
	assert_str(ghost.reason()).is_empty()
	var funds: int = _simulation.state.budget.funds_k
	ghost.confirm()
	assert_int(_count(StartingBase.CAPACITOR_BANK_DEF)).is_equal(1)
	assert_int(_simulation.state.budget.funds_k).is_equal(funds - 600)
	assert_bool(ghost.is_placing()).is_true()
	assert_str(ghost.reason()).is_not_empty()
	assert_bool(CapacitorGauge.needs_bank(_simulation.state)).is_false()


func test_invalid_spots_say_why() -> void:
	var ghost: PlacementGhost = _ghost()
	_view.get_build().start_placing(&"room_research_lab")
	ghost.move_to(Vector2i(15, 5))
	assert_str(ghost.reason()).is_equal("Overlaps the Gate Room.")
	ghost.move_to(Vector2i(34, 0))
	assert_str(ghost.reason()).is_equal("Outside the level.")
	ghost.move_to(Vector2i(0, 0))
	assert_str(ghost.reason()).is_equal("Must touch a corridor.")
	_simulation.state.budget.funds_k = 100
	ghost.recheck()
	ghost.move_to(Vector2i(24, 11))
	assert_str(ghost.reason()).is_equal("Needs $800k; you have $100k.")
	ghost.confirm()
	assert_int(_count(&"room_research_lab")).is_equal(0)


## A new game's palette can pick only the Capacitor Bank, Research Lab, Quarters and Corridor
## (m25-lean-start.md section 1, m26-staff-and-money.md section 3); research-locked rooms
## show disabled until research adds them.
func test_palette_offers_only_unlocked_rooms() -> void:
	var palette: BuildPalette = _view.get_palette()
	for def_id: StringName in BuildPalette.ROOMS:
		var wanted: bool = (
			def_id
			in [&"room_capacitor_bank", &"room_research_lab", &"room_quarters", &"room_corridor"]
		)
		var button: Button = palette.get_room_button(def_id)
		assert_object(button).override_failure_message(String(def_id)).is_not_null()
		assert_bool(not button.disabled).override_failure_message(String(def_id)).is_equal(wanted)
	await _unlock_everything()
	for def_id: StringName in BuildPalette.ROOMS:
		assert_bool(palette.get_room_button(def_id).disabled).is_false()
	assert_object(palette.get_room_button(&"room_infirmary")).is_null()


## A lift ghost on an existing shaft shows what the command charges: the segment price and
## time for the one missing level ($100k, 1 h), not the full lift (m25-lean-start.md
## section 2).
func test_lift_ghost_on_a_shaft_shows_the_segment_price() -> void:
	await _unlock_everything()
	var state: GameState = _simulation.state
	state.base.add_room(&"room_lift", 1, Vector2i(24, 8))
	var ghost: PlacementGhost = _ghost()
	_view.get_build().start_placing(&"room_lift")
	ghost.move_to(Vector2i(24, 8))
	assert_str(ghost.reason()).is_empty()
	var command := ghost.command() as PlaceRoomCommand
	assert_int(ghost.cost_k()).is_equal(command.cost_of(state)).is_equal(100)
	assert_int(ghost.build_ticks()).is_equal(command.ticks_of(state)).is_equal(60)
	assert_str(_view.get_palette().get_hint()).contains("$100k").contains("1 h")
	ghost.move_to(Vector2i(2, 16))
	assert_int(ghost.cost_k()).is_equal(400)
	assert_int(ghost.build_ticks()).is_equal(240)


## Every research unlock, and an empty dug Level 2 below, then a refresh.
func _unlock_everything() -> void:
	ConstructionFixture.unlock_all(_simulation.state)
	_simulation.state.budget.funds_k = 100000
	_simulation.state.base.levels.append(LevelState.new())
	_view.get_build().refresh()
	for _frame: int in 2:
		await get_tree().process_frame


func test_every_catalogue_room_has_a_palette_button_and_summary() -> void:
	await _unlock_everything()
	for def_id: StringName in BuildPalette.ROOMS:
		var button: Button = _view.get_palette().get_room_button(def_id)
		assert_object(button).is_not_null()
		var def: RoomDef = _simulation.state.room_defs[def_id]
		assert_str(BuildText.summary(def)).contains(MoneyLabel.format_k(def.build_cost_k))


func test_rotate_turns_the_ghost() -> void:
	var ghost: PlacementGhost = _ghost()
	_view.get_build().start_placing(&"room_research_lab")
	ghost.move_to(Vector2i(4, 16))
	assert_object(ghost.area().size).is_equal(Vector2i(4, 3))
	ghost.rotate_ghost()
	assert_object(ghost.area().size).is_equal(Vector2i(3, 4))


func test_corridor_painting_builds_one_run() -> void:
	var ghost: PlacementGhost = _ghost()
	_view.get_build().start_placing(StartingBase.CORRIDOR_DEF)
	ghost.move_to(Vector2i(24, 11))
	ghost.move_to(Vector2i(24, 12))
	assert_int(ghost.run.size()).is_equal(1)
	ghost.move_to(Vector2i(24, 11))
	ghost.set_start()
	ghost.move_to(Vector2i(25, 12))
	assert_int(ghost.run.size()).is_equal(3)
	ghost.move_to(Vector2i(24, 12))
	assert_int(ghost.run.size()).is_equal(2)
	var before: int = _count(StartingBase.CORRIDOR_DEF)
	ghost.confirm()
	assert_int(_count(StartingBase.CORRIDOR_DEF)).is_equal(before + 2)


## With no valid spot on the Gate level (no corridor or lift left there), the button still
## shows the Gate level with the ghost out, and the palette says why.
func test_capacitor_bank_button_without_a_spot_explains() -> void:
	var base: BaseState = _simulation.state.base
	for room: RoomState in BaseRules.rooms_on_level(base, 1):
		if BaseRules.is_connector(room.def_id):
			base.rooms.erase(room)
	_view.place_capacitor_bank()
	assert_bool(_ghost().is_placing()).is_true()
	assert_int(_view.get_plan().level).is_equal(1)
	assert_str(_ghost().reason()).is_not_empty()
	assert_str(_view.get_palette().get_hint()).starts_with("No free 3 × 2 spot")


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


func test_demolish_refused_for_the_gate_room_and_allowed_for_a_lab() -> void:
	var panel: RoomPanel = _view.get_room_panel()
	var gate: RoomState = _find(StartingBase.GATE_ROOM_DEF)
	_view.get_plan().select(gate.id)
	assert_bool(panel.get_action_button().disabled).is_true()
	assert_str(panel.get_action_reason()).is_equal("The Gate and Control Rooms stay.")
	var lab: RoomState = _simulation.state.base.add_room(&"room_research_lab", 1, Vector2i(24, 11))
	lab.paid_k = 800
	_view.get_plan().select(lab.id)
	assert_str(panel.get_action_button().text).contains("$400k")
	panel.get_action_button().begin_hold()
	panel.get_action_button().advance(1.0)
	assert_bool(lab.is_demolishing()).is_true()


func test_dig_button_digs_and_cancels() -> void:
	var dig: DigButton = _view.get_palette().get_dig_button()
	assert_str(dig.text).is_equal("Dig Level 2: $1,500k, 3 d")
	assert_bool(dig.disabled).is_true()
	assert_str(dig.get_reason()).is_equal("Unlock: Excavation survey")
	UnlockRules.apply_project(_simulation.state.unlocks, &"excavation_survey")
	_view.get_build().refresh()
	assert_bool(dig.disabled).is_false()
	dig.begin_hold()
	dig.advance(1.0)
	assert_int(_simulation.state.base.digging_level()).is_equal(2)
	assert_int(_view.get_plan().get_parent().get_parent().get_child_count()).is_greater(0)
	assert_str(dig.text).contains("$750k")
	assert_str(dig.tooltip_text).is_equal("Digging Level 2: 0%, 3 d left")
	dig.begin_hold()
	dig.advance(1.0)
	assert_int(_simulation.state.base.digging_level()).is_equal(0)


func test_signature_includes_room_ids_and_positions() -> void:
	var base: BaseState = _simulation.state.base
	var before: int = BaseView.signature(base)
	base.rooms[-1].origin += Vector2i.RIGHT
	assert_int(BaseView.signature(base)).is_not_equal(before)


func test_palette_fits_1280_by_720_in_both_languages() -> void:
	await _unlock_everything()
	for locale: String in ["en", "pt_BR"]:
		TranslationServer.set_locale(locale)
		_view.get_build().refresh()
		_view.get_palette().show_message(_view.get_palette().get_hint())
		for _frame: int in 3:
			await get_tree().process_frame
		var view: Rect2 = _view.get_global_rect()
		var palette: Rect2 = _view.get_palette().get_global_rect()
		assert_bool(view.encloses(palette)).override_failure_message(locale).is_true()
		var plan: Rect2 = _view.get_plan().get_global_rect()
		assert_float(plan.end.y).is_less_equal(palette.position.y)
		assert_bool(view.encloses(_view.get_room_panel().get_global_rect())).is_true()
		for def_id: StringName in BuildPalette.ROOMS:
			var button: Rect2 = _view.get_palette().get_room_button(def_id).get_global_rect()
			(
				assert_bool(palette.encloses(button))
				. override_failure_message("%s %s" % [locale, def_id])
				. is_true()
			)
		var dig: Rect2 = _view.get_palette().get_dig_button().get_global_rect()
		assert_bool(palette.encloses(dig)).override_failure_message(locale).is_true()


func test_focused_palette_button_gets_enter_not_the_ghost() -> void:
	_view.place_capacitor_bank()
	var lab: Button = _view.get_palette().get_room_button(&"room_research_lab")
	lab.grab_focus()
	var before: int = _count(&"room_research_lab")
	await get_tree().process_frame
	_push_key(KEY_ENTER, true)
	_push_key(KEY_ENTER, false)
	await get_tree().process_frame
	assert_str(String(_ghost().def_id)).is_equal("room_research_lab")
	# The Enter that picked the room on the palette must not also build it.
	assert_int(_count(&"room_research_lab")).is_equal(before)


func test_mouse_click_builds_with_real_events() -> void:
	_view.place_capacitor_bank()
	await get_tree().process_frame
	var plan: BasePlan = _view.get_plan()
	var cell: Vector2i = _ghost().origin
	var at: Vector2 = plan.get_global_rect().position + plan.view.offset
	at += (Vector2(cell) + Vector2(0.5, 0.5)) * BasePlanPainter.CELL * plan.view.scale()
	# Headless Godot picks no control under the pointer, so the event goes to the ghost's
	# own GUI entry, the same one the viewport calls.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at - plan.get_global_rect().position
	_ghost()._gui_input(press)
	assert_int(_count(StartingBase.CAPACITOR_BANK_DEF)).is_equal(1)
	press.pressed = false
	_ghost()._gui_input(press)


func test_gamepad_a_press_builds_with_real_events() -> void:
	_view.place_capacitor_bank()
	await get_tree().process_frame
	assert_bool(_view.get_plan().has_focus()).is_true()
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	get_viewport().push_input(button)
	await get_tree().process_frame
	assert_int(_count(StartingBase.CAPACITOR_BANK_DEF)).is_equal(1)
	button.pressed = false
	get_viewport().push_input(button)


func test_every_catalogue_room_finds_a_valid_spot() -> void:
	await _unlock_everything()
	var ghost: PlacementGhost = _ghost()
	var plan: BasePlan = _view.get_plan()
	var grid: Vector2i = _simulation.state.base.grid_size
	for def_id: StringName in BuildPalette.ROOMS:
		var found: bool = false
		for level: int in [1, 2]:
			plan.show_level(level)
			_view.get_build().start_placing(def_id)
			for y: int in grid.y:
				for x: int in grid.x:
					ghost.run.clear()
					ghost.move_to(Vector2i(x, y))
					if ghost.reason().is_empty():
						found = true
						break
				if found:
					break
			ghost.stop()
			if found:
				break
		assert_bool(found).override_failure_message(String(def_id)).is_true()


func test_energy_layer_and_ghost_do_not_fight() -> void:
	var power: BaseViewPower = _view.get_power()
	_view.place_capacitor_bank()
	power.toggle_layer()
	assert_bool(power.is_layer_on()).is_true()
	assert_bool(_ghost().is_placing()).is_false()
	_view.get_palette().get_room_button(&"room_research_lab").pressed.emit()
	assert_bool(power.is_layer_on()).is_false()
	assert_bool(_ghost().is_placing()).is_true()
	_view.place_capacitor_bank()
	power.toggle_layer()
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	get_viewport().push_input(button)
	await get_tree().process_frame
	button.pressed = false
	get_viewport().push_input(button)
	assert_int(_count(StartingBase.CAPACITOR_BANK_DEF)).is_equal(0)


func _push_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	get_viewport().push_input(event)


func _find(def_id: StringName) -> RoomState:
	for room: RoomState in _simulation.state.base.rooms:
		if room.def_id == def_id:
			return room
	return null
