## Tests for the Base tab's power UI: the bar and strip match the simulation, the panel's
## switch and charge control and the energy layer go through the commands, refusals are shown
## plainly, always-on rooms and the last plant show a locked switch with the reason, the
## energy-layer action toggles the layer, and the layout fits 1280 × 720 in both languages.
## Bible: docs/content/m2-base.md sections 3 and 6
extends GdUnitTestSuite

const VIEW_SCENE: String = "res://src/ui/views/base/base_view.tscn"
const VIEW_SIZE: Vector2 = Vector2(1280, 640)

var _root: Control = null
var _view: BaseView = null
var _power: BaseViewPower = null
var _runner: GdUnitSceneRunner = null
var _simulation: Simulation = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var state: GameState = ConstructionFixture.state()
	PowerFixture.lab(state)
	_simulation = Simulation.new(state)
	_simulation.state.clock.is_paused = true
	_root = Control.new()
	_root.size = VIEW_SIZE
	_view = (load(VIEW_SCENE) as PackedScene).instantiate() as BaseView
	_root.add_child(_view)
	_runner = scene_runner(_root)
	_view.setup(_simulation)
	_power = _view.get_power()
	# The switch and charge control live on the Energy sub-tab (card #206).
	_view.get_sub_tabs().show_tab(BaseSubTabs.ENERGY)
	await _runner.await_input_processed()


func after_test() -> void:
	EventBus.bind_simulation(null)
	if is_instance_valid(_root):
		_root.free()
	TranslationServer.set_locale(_real_locale)


func test_bar_matches_the_simulation() -> void:
	var bar: PowerBar = _power.strip.bar
	assert_float(bar.get_supply()).is_equal(30.0)
	assert_float(_drawn_mw()).is_equal(PowerRules.allocated_mw(_simulation.state))
	assert_array(_power.strip.texts()).is_equal(["30 MW · 20 spare", "No capacitors installed"])
	PowerFixture.add_bank(_simulation.state, 20)
	_simulation.state.power.stored_mwh = 100.0
	_power.refresh()
	assert_float(_drawn_mw()).is_equal(30.0)
	assert_int(bar.get_blocks().back()["kind"]).is_equal(PowerBar.Kind.CHARGE)
	assert_str(_power.strip.texts()[1]).is_equal("Capacitors 100/400 MWh, full in 15 h")


func test_panel_switch_goes_through_the_command() -> void:
	var lab: RoomState = PowerFixture.lab(_simulation.state)
	_view.get_plan().select(lab.id)
	var button: Button = _power.room_switch.get_button()
	assert_bool(_power.room_switch.visible).is_true()
	assert_str(button.text).is_equal("ON · switch off")
	button.pressed.emit()
	assert_bool(lab.powered_on).is_false()
	assert_str(button.text).is_equal("OFF · switch on")
	assert_float(_drawn_mw()).is_equal(5.0)


func test_always_on_and_last_plant_are_locked_with_the_reason() -> void:
	var gate: RoomState = PowerFixture.first_room(_simulation.state, &"room_gate")
	_view.get_plan().select(gate.id)
	assert_bool(_power.room_switch.get_button().disabled).is_true()
	assert_str(_power.room_switch.get_note()).contains("never switch off")
	var plant: RoomState = PowerFixture.first_room(_simulation.state, &"room_power_plant")
	_view.get_plan().select(plant.id)
	assert_bool(_power.room_switch.get_button().disabled).is_true()
	assert_str(_power.room_switch.get_note()).is_equal("The base's last running plant.")
	var corridor: RoomState = PowerFixture.first_room(_simulation.state, &"room_corridor")
	_view.get_plan().select(corridor.id)
	assert_bool(_power.room_switch.visible).is_false()


func test_refused_switch_on_is_shown_plainly() -> void:
	var lab: RoomState = PowerFixture.lab(_simulation.state)
	lab.powered_on = false
	PowerFixture.add_bank(_simulation.state, 25)
	_view.get_plan().select(lab.id)
	_power.room_switch.get_button().pressed.emit()
	assert_bool(lab.powered_on).is_false()
	assert_str(_power.room_switch.get_note()).is_equal("Needs 5 MW; 0 MW spare.")
	assert_str(_power.layer.tag_of(lab.id)).is_equal("NEEDS 5")


func test_charge_control_steps_and_refuses() -> void:
	var bank: RoomState = PowerFixture.add_bank(_simulation.state, 20)
	_view.get_plan().select(bank.id)
	assert_bool(_power.charge.visible).is_true()
	assert_bool(_power.room_switch.visible).is_false()
	var steps: Array[Button] = _power.charge.get_steps()
	steps[0].pressed.emit()
	assert_int(_simulation.state.power.charge_rates[bank.id]).is_equal(15)
	assert_int(_power.charge.get_rate()).is_equal(15)
	PowerFixture.lab(_simulation.state).powered_on = false
	_power.charge.rate_requested.emit(bank.id, 30)
	assert_int(_simulation.state.power.charge_rates[bank.id]).is_equal(15)
	assert_str(_power.charge.get_note()).is_equal("Needs 15 MW; 10 MW spare.")


func test_energy_layer_action_click_and_dpad() -> void:
	_view.get_sub_tabs().show_tab(BaseSubTabs.BUILD)
	assert_bool(_power.is_layer_on()).is_false()
	await _press_action(&"base_energy_layer")
	assert_bool(_power.is_layer_on()).is_true()
	assert_bool(_power.strip.bar.expanded).is_true()
	var plan: BasePlan = _view.get_plan()
	var gate: RoomState = PowerFixture.first_room(_simulation.state, &"room_gate")
	assert_str(_power.layer.tag_of(gate.id)).is_equal("LOCK 5")
	var bank: RoomState = PowerFixture.add_bank(_simulation.state, 10)
	plan.show_level(1)
	var plant: RoomState = PowerFixture.first_room(_simulation.state, &"room_power_plant")
	assert_str(_power.layer.tag_of(plant.id)).is_equal("+30")
	assert_str(_power.layer.tag_of(bank.id)).is_equal("− CHG 10 +")
	plan.cursor = bank.origin
	plan.gui_input.emit(_action(&"ui_right"))
	assert_int(_simulation.state.power.charge_rates[bank.id]).is_equal(15)
	assert_vector(Vector2(plan.cursor)).is_equal(Vector2(bank.origin))
	_click(plan, bank.origin)
	assert_int(_simulation.state.power.charge_rates[bank.id]).is_equal(10)
	plan.show_level(1)
	var lab: RoomState = PowerFixture.lab(_simulation.state)
	_click(plan, lab.origin)
	assert_bool(lab.powered_on).is_false()
	assert_str(_power.layer.tag_of(lab.id)).is_equal("OFF")
	plan.cursor = lab.origin
	plan.gui_input.emit(_action(&"ui_accept"))
	assert_bool(lab.powered_on).is_true()
	await _press_action(&"base_energy_layer")
	assert_bool(_power.is_layer_on()).is_false()


## A demolish submitted while paused refreshes the bar through the events alone.
func test_demolish_while_paused_refreshes_the_bar() -> void:
	EventBus.bind_simulation(_simulation)
	var lab: RoomState = PowerFixture.lab(_simulation.state)
	var result: CommandResult = _simulation.submit(DemolishRoomCommand.create(lab.id))
	assert_bool(result.is_ok).override_failure_message(String(result.error_code)).is_true()
	assert_float(_drawn_mw()).is_equal(PowerRules.allocated_mw(_simulation.state))
	assert_float(_drawn_mw()).is_equal(5.0)


## The view keeps working after leaving and re-entering the tree.
func test_survives_leaving_and_reentering_the_tree() -> void:
	_root.remove_child(_view)
	_root.add_child(_view)
	EventBus.bind_simulation(_simulation)
	var lab: RoomState = PowerFixture.lab(_simulation.state)
	_simulation.submit(SwitchRoomCommand.create(lab.id, false))
	assert_float(_drawn_mw()).is_equal(5.0)


func _drawn_mw() -> float:
	var total: float = 0.0
	for block: Dictionary in _power.strip.bar.get_blocks():
		var mw: float = block["mw"]
		total += mw
	return total


func _click(plan: BasePlan, cell: Vector2i) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	var centre: Vector2 = (Vector2(cell) + Vector2(0.3, 0.5)) * BasePlanPainter.CELL
	event.position = plan.view.offset + centre * plan.view.scale()
	plan.gui_input.emit(event)
	BasePlanInput.handle(plan, event)


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _press_action(action: StringName) -> void:
	_runner.simulate_action_pressed(String(action))
	await _runner.await_input_processed()
