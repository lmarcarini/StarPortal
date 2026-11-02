## M2.5 end to end, headless, over the real data/ content (docs/content/m25-lean-start.md):
## a new game opens on the Gate Room, whose "Build capacitor bank" button builds the bank in one
## click; it charges at the spare 25 MW. A Research Lab built as soon as the bank is done
## finishes on, lowering charging to 20 MW with its message, and SILL locks about 17.3 hours in.
## The Research tab (F4) starts Excavation survey through its real row and Start button; Level 2
## is dug and Stairs join it. Lift shaft brings a Lift on both levels, Field engineering the
## Workshop, which makes the next site finish 25% faster, and Bank array a second bank.
## Bible: roadmap.md (M2.5 check), technical-architecture.md#testing-and-tooling,
## docs/content/m25-lean-start.md sections 1 to 6
extends GdUnitTestSuite

const M15Player := preload("res://tests/gate/m15_player.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")
const SWITCHER_SCENE: String = "res://src/ui/views/view_switcher.tscn"

## Seed of the played game.
const SEED: int = 20_261_102
## The corridor run and the Research Lab on Level 1, as in test_m2_flow.gd.
const LEVEL: int = 1
const CORRIDOR_RUN: Array[Vector2i] = [
	Vector2i(24, 9), Vector2i(24, 8), Vector2i(24, 7), Vector2i(24, 6), Vector2i(24, 5)
]
const LAB_DEF: StringName = &"room_research_lab"
const LAB_ORIGIN: Vector2i = Vector2i(25, 5)
const STAIRS_DEF: StringName = &"room_stairs"
const WORKSHOP_DEF: StringName = &"room_workshop"
const BANK_DEF: StringName = &"room_capacitor_bank"
## Most ticks the test waits for a site, a dig or a project.
const MAX_WAIT_TICKS: int = 60 * TimeMath.TICKS_PER_DAY

var _defs: GameDefs
var _root: Control = null
var _real_locale: String = ""


func before() -> void:
	_defs = GameDefs.from_registry(Registry)


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	_free_ui()
	TranslationServer.set_locale(_real_locale)


func test_new_game_to_second_bank() -> void:
	var built: Result = GameSetup.build_new(GameState.new_game(SEED, _defs.balance), _defs)
	assert_bool(built.is_ok).override_failure_message(str(built.error_code)).is_true()
	var simulation: Simulation = built.value
	var player: M15Player = M15Player.new(simulation)
	await _build_bank_from_gate_room(player)
	_build_lab_after_bank(player)
	_lock_sill(player)
	await _start_survey_from_research_tab(player)
	_dig_level_2_and_place_stairs(player)
	_research_and_build_lift(player)
	_research_and_build_workshop(player)
	_research_and_build_second_bank(player)
	assert_array(player.rejections).is_empty()


func _make_switcher(player: M15Player) -> ViewSwitcher:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var switcher := (load(SWITCHER_SCENE) as PackedScene).instantiate() as ViewSwitcher
	_root.add_child(switcher)
	scene_runner(_root)
	switcher.setup(player.simulation)
	return switcher


func _free_ui() -> void:
	if is_instance_valid(_root):
		_root.free()
	_root = null


## "Build capacitor bank" places the bank's ghost on the nearest spot; one click builds it,
## and it charges at the spare 25 MW after 1 hour.
func _build_bank_from_gate_room(player: M15Player) -> void:
	var switcher: ViewSwitcher = _make_switcher(player)
	await UiInput.settle(switcher)
	var gauge := switcher.find_child("CapacitorGauge", true, false) as CapacitorGauge
	assert_str(tr(gauge.get_build_button().text)).is_equal("Build capacitor bank")
	await UiInput.click(gauge.get_build_button())
	var base := switcher.get_view(&"base") as BaseView
	var ghost: PlacementGhost = base.get_build().get_ghost()
	assert_str(ghost.reason()).is_empty()
	ghost.confirm()
	_free_ui()
	(
		assert_int(
			_wait(player, func() -> bool: return not player.state().power.charge_rates.is_empty())
		)
		. is_equal(60)
	)
	assert_array(player.state().power.charge_rates.values()).is_equal([25])


## The lab, started when the bank is done, finishes 8 hours later switched on: charging comes
## down to 20 MW and the log says so.
func _build_lab_after_bank(player: M15Player) -> void:
	var run: Array[Vector2i] = CORRIDOR_RUN.duplicate()
	_submit(player, PaintCorridorCommand.create(LEVEL, run))
	_submit(player, PlaceRoomCommand.create(LAB_DEF, LEVEL, LAB_ORIGIN))
	var lab: RoomState = PowerFixture.first_room(player.state(), LAB_DEF)
	assert_int(_wait(player, lab.is_built)).is_equal(8 * 60)
	assert_bool(lab.powered_on).is_true()
	assert_float(PowerRules.charge_mw(player.state())).is_equal(20.0)
	var entry: LogEntry = player.state().operations_log.entries[-1]
	var line: String = ArchiveLogRow.line_for(entry, player.state())
	assert_str(line).is_equal("Research Lab on: charging lowered to 20 MW.")


## SILL's lock energy is ready about 17.3 hours into the game (section 1); it locks.
func _lock_sill(player: M15Player) -> void:
	var sill: GateAddress = player.address(M15Player.PUZZLES[0]["glyphs"])
	assert_bool(player.wait_for_charge(sill)).is_true()
	assert_int(player.state().clock.tick).is_between(1030, 1050)
	assert_int(player.dial(sill).outcome).is_equal(DialOutcome.Kind.LOCK)
	assert_bool(player.close_wormhole()).is_true()


## F4 opens the Research tab; clicking the Excavation survey row and its Start button starts it.
func _start_survey_from_research_tab(player: M15Player) -> void:
	var switcher: ViewSwitcher = _make_switcher(player)
	await UiInput.settle(switcher)
	await UiInput.key(switcher, KEY_F4)
	assert_str(String(switcher.current_view_id())).is_equal("research")
	var view := switcher.get_view(&"research") as ResearchView
	await UiInput.click(view.get_list().row_of(&"excavation_survey"))
	var start: Button = view.get_panel().get_button()
	assert_str(start.text).is_equal("Start")
	var funds: int = player.state().budget.funds_k
	await UiInput.click(start)
	_free_ui()
	assert_str(String(player.state().research.active)).is_equal("excavation_survey")
	assert_int(player.state().budget.funds_k).is_equal(funds - 400)
	var done: Callable = func() -> bool:
		return player.state().research.is_done(&"excavation_survey")
	assert_int(_wait(player, done)).is_equal(2 * TimeMath.TICKS_PER_DAY)


## Level 2 is dug in 3 days; Stairs placed from Level 1 reach it.
func _dig_level_2_and_place_stairs(player: M15Player) -> void:
	_submit(player, DigLevelCommand.new())
	var dug: Callable = func() -> bool: return player.state().base.digging_level() == 0
	assert_int(_wait(player, dug)).is_equal(3 * TimeMath.TICKS_PER_DAY)
	var stairs: RoomState = _place_near_gate(player, STAIRS_DEF)
	_wait(player, stairs.is_built)
	assert_array(_levels_of(player.state(), STAIRS_DEF)).is_equal([1, 2])


func _research_and_build_lift(player: M15Player) -> void:
	_research(player, &"lift_shaft")
	var lift: RoomState = _place_near_gate(player, StartingBase.LIFT_DEF)
	_wait(player, lift.is_built)
	assert_array(_levels_of(player.state(), StartingBase.LIFT_DEF)).is_equal([1, 2])


## The Workshop finishes on, taking its 5 MW from charging.
func _research_and_build_workshop(player: M15Player) -> void:
	_research(player, &"field_engineering")
	var workshop: RoomState = _place_near_gate(player, WORKSHOP_DEF)
	_wait(player, workshop.is_built)
	assert_bool(workshop.powered_on).is_true()
	assert_bool(BuildSpeed.has_running_workshop(player.state())).is_true()
	assert_float(PowerRules.charge_mw(player.state())).is_equal(15.0)


## Bank array allows a second bank; with the Workshop on its 1-hour site takes 48 minutes (or
## one less, by phase). Money runs short first: the player waits for the month-end.
func _research_and_build_second_bank(player: M15Player) -> void:
	_research(player, &"bank_array")
	var cost: int = player.state().room_defs[BANK_DEF].build_cost_k
	_wait(player, func() -> bool: return player.state().budget.funds_k >= cost)
	var bank: RoomState = _place_near_gate(player, BANK_DEF)
	assert_int(_wait(player, bank.is_built)).is_between(47, 48)
	assert_int(player.state().power.charge_rates.size()).is_equal(2)


## Starts [param project_id] by command and runs the clock until it is done.
func _research(player: M15Player, project_id: StringName) -> void:
	_submit(player, StartResearchCommand.create(project_id))
	_wait(player, func() -> bool: return player.state().research.is_done(project_id))


## Places [param def_id] on the nearest valid spot to the Gate Room on Level 1; returns it.
func _place_near_gate(player: M15Player, def_id: StringName) -> RoomState:
	var state: GameState = player.state()
	var gate: RoomState = BaseSpots.gate_room(state.base)
	var target: Rect2i = BaseRules.footprint(gate, state.room_defs[gate.def_id])
	var spot: Vector2i = BaseSpots.nearest_spot(state.base, state.room_defs, def_id, LEVEL, target)
	assert_bool(spot != BaseSpots.NO_SPOT).override_failure_message(String(def_id)).is_true()
	_submit(player, PlaceRoomCommand.create(def_id, LEVEL, spot))
	return state.base.rooms[-1] if state.base.rooms[-1].level == LEVEL else _room_at(state, spot)


func _room_at(state: GameState, spot: Vector2i) -> RoomState:
	for room: RoomState in BaseRules.rooms_on_level(state.base, LEVEL):
		if room.origin == spot:
			return room
	return null


func _levels_of(state: GameState, def_id: StringName) -> Array[int]:
	var levels: Array[int] = []
	for room: RoomState in state.base.rooms:
		if room.def_id == def_id and room.is_built():
			levels.append(room.level)
	levels.sort()
	return levels


func _submit(player: M15Player, command: Command) -> void:
	var result: CommandResult = player.simulation.submit(command)
	assert_bool(result.is_ok).override_failure_message(str(result.error_code)).is_true()


## Runs the clock until [param done] holds; returns the ticks it took (fails past the limit).
func _wait(player: M15Player, done: Callable) -> int:
	var ticks: int = 0
	while not done.call():
		assert_int(ticks).is_less(MAX_WAIT_TICKS)
		if ticks >= MAX_WAIT_TICKS:
			return ticks
		player.step()
		ticks += 1
	return ticks
