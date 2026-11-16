## M2 end to end on the M2.5 lean start, headless, over the real data/ content: a new game opens on
## the Gate Room, whose "BUILD BANK" button switches to the Base tab with the bank's
## ghost on the nearest valid spot to the Gate Room, and one click builds it. The bank completes
## after 1 hour and takes the spare 25 MW; SILL then charges and locks, and the pole camera brings
## its documents. The player paints a corridor and builds a Research Lab against it on Level 1 (it
## completes on, taking its 5 MW from charging: "Research Lab on: charging lowered to 20 MW",
## m25-lean-start.md section 3), is granted Excavation survey through
## UnlockFixture.apply_project() (no research system yet), digs Level 2, and the next daily
## settlement pays the allocation less the day's share of the upkeep. Last, with the total
## charge rate lowered below the open wormhole's 20 MWh/h drain, a lock closes when the
## capacitors run empty.
## Bible: roadmap.md (M2 check), technical-architecture.md#testing-and-tooling,
## docs/content/m2-base.md sections 2 to 5, docs/content/m25-lean-start.md sections 1 to 6,
## docs/content/m27-daily-rhythm.md section 1
extends GdUnitTestSuite

const M15Player := preload("res://tests/gate/m15_player.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")
const SWITCHER_SCENE: String = "res://src/ui/views/view_switcher.tscn"

## Seed of the played game.
const SEED: int = 20_261_101
## The corridor run on Level 1: from the spine up column 24, east of the Gate Room.
const CORRIDOR_LEVEL: int = 1
const CORRIDOR_RUN: Array[Vector2i] = [
	Vector2i(24, 9), Vector2i(24, 8), Vector2i(24, 7), Vector2i(24, 6), Vector2i(24, 5)
]
## Where the Research Lab (4 × 3) stands: east of the corridor run, touching it.
const LAB_DEF: StringName = &"room_research_lab"
const LAB_ORIGIN: Vector2i = Vector2i(25, 5)
## A charge rate below the open wormhole's 20 MWh/h drain.
const LOW_CHARGE_MW: int = 10

var _defs: GameDefs
var _root: Control = null
var _real_locale: String = ""
var _closed_reasons: Array[StringName] = []


func before() -> void:
	_defs = GameDefs.from_registry(Registry)


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_closed_reasons.clear()


func after_test() -> void:
	if is_instance_valid(_root):
		_root.free()
	_root = null
	TranslationServer.set_locale(_real_locale)


func test_new_game_to_month_end() -> void:
	var built: Result = GameSetup.build_new(GameState.new_game(SEED, _defs.balance), _defs)
	assert_bool(built.is_ok).override_failure_message(str(built.error_code)).is_true()
	var simulation: Simulation = built.value
	var player: M15Player = M15Player.new(simulation)
	player.simulation.event_posted.connect(_on_event)
	await _build_bank_from_gate_room(player)
	_assert_bank_completes(player)
	_lock_sill_and_send_camera(player)
	_build_lab_with_corridor(player)
	_dig_level_2(player)
	_assert_daily_settlement(player)
	_assert_empty_capacitors_close(player)
	assert_array(player.rejections).is_empty()


func _on_event(event_name: StringName, args: Array) -> void:
	if event_name == &"wormhole_closed":
		_closed_reasons.append(args[0])


## The Gate Room's button switches to the Base tab on Level 1 with the bank's ghost green on
## the nearest valid spot (BaseSpots.bank_spot); one click pays $600k and starts the site; the
## button is gone.
func _build_bank_from_gate_room(player: M15Player) -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var switcher := (load(SWITCHER_SCENE) as PackedScene).instantiate() as ViewSwitcher
	_root.add_child(switcher)
	var runner: GdUnitSceneRunner = scene_runner(_root)
	switcher.setup(player.simulation)
	await runner.simulate_frames(2)
	assert_str(String(switcher.current_view_id())).is_equal("gate_room")
	var gauge := switcher.find_child("Charge", true, false) as ChargeGauge
	assert_str(tr(gauge.get_build_key().text)).is_equal("BUILD BANK")
	await UiInput.click(gauge.get_build_key())
	assert_str(String(switcher.current_view_id())).is_equal("base")
	var base := switcher.get_view(&"base") as BaseView
	var ghost: PlacementGhost = base.get_build().get_ghost()
	assert_bool(ghost.is_placing()).is_true()
	assert_int(base.get_plan().level).is_equal(1)
	var spot: Vector2i = BaseSpots.bank_spot(player.state().base, player.state().room_defs)
	assert_vector(Vector2(ghost.origin)).is_equal(Vector2(spot))
	assert_str(ghost.reason()).is_empty()
	var funds: int = player.state().budget.funds_k
	ghost.confirm()
	assert_int(player.state().budget.funds_k).is_equal(funds - 600)
	var is_bank: Callable = func(r: RoomState) -> bool:
		return r.def_id == StartingBase.CAPACITOR_BANK_DEF
	assert_bool(player.state().base.rooms.any(is_bank)).is_true()
	_root.free()
	_root = null


## The site takes 60 ticks (1 hour); the bank then charges at the spare 25 MW.
func _assert_bank_completes(player: M15Player) -> void:
	for _tick: int in 59:
		player.step()
	assert_bool(player.state().power.charge_rates.is_empty()).is_true()
	player.step()
	assert_array(player.state().power.charge_rates.values()).is_equal([25])
	assert_float(PowerRules.spare_mw(player.state())).is_equal(0.0)


## SILL charges (about 14.7 hours at 25 MW), locks, and the pole camera brings its documents.
func _lock_sill_and_send_camera(player: M15Player) -> void:
	var sill: GateAddress = player.address(M15Player.PUZZLES[0]["glyphs"])
	var started: int = player.state().clock.tick
	assert_bool(player.wait_for_charge(sill)).is_true()
	assert_int(player.state().clock.tick - started).is_between(800, 900)
	var entry: DialLogEntry = player.dial(sill)
	assert_object(entry).is_not_null()
	assert_int(entry.outcome).is_equal(DialOutcome.Kind.LOCK)
	var delivers: Array = M15Player.PUZZLES[0]["delivers"]
	var expected: Array[StringName] = []
	expected.assign(delivers)
	assert_array(player.extend_pole_camera()).contains_exactly_in_any_order(expected)
	assert_bool(player.close_wormhole()).is_true()


## Paints a corridor run off the Level 1 spine, builds a Research Lab against it, and waits for
## both. The lab completes switched on: the bank held all the spare power, so its charge rate
## comes down from 25 to 20 MW, and the log says so.
func _build_lab_with_corridor(player: M15Player) -> void:
	var funds: int = player.state().budget.funds_k
	var run: Array[Vector2i] = CORRIDOR_RUN.duplicate()
	(
		assert_bool(
			player.simulation.submit(PaintCorridorCommand.create(CORRIDOR_LEVEL, run)).is_ok
		)
		. is_true()
	)
	var place := PlaceRoomCommand.create(LAB_DEF, CORRIDOR_LEVEL, LAB_ORIGIN)
	assert_bool(player.simulation.submit(place).is_ok).is_true()
	assert_int(player.state().budget.funds_k).is_equal(funds - 5 * 5 - 800)
	var lab: RoomState = PowerFixture.first_room(player.state(), LAB_DEF)
	while not lab.is_built():
		player.step()
	for cell: Vector2i in CORRIDOR_RUN:
		assert_bool(_corridor_built_at(player.state(), cell)).is_true()
	assert_bool(lab.powered_on).is_true()
	assert_float(PowerRules.charge_mw(player.state())).is_equal(20.0)
	var line: String = "Research Lab on: charging lowered to 20 MW."
	var entry: LogEntry = player.state().operations_log.entries[-2]
	assert_str(ArchiveLogRow.line_for(entry, player.state())).is_equal(line)
	var staffed: LogEntry = player.state().operations_log.entries[-1]
	assert_str(ArchiveLogRow.line_for(staffed, player.state())).is_equal(
		"Research Lab staffed: 2 scientists."
	)
	assert_int(StaffRules.assigned(player.state(), lab).size()).is_equal(2)


func _corridor_built_at(state: GameState, cell: Vector2i) -> bool:
	for room: RoomState in BaseRules.rooms_on_level(state.base, CORRIDOR_LEVEL):
		if room.def_id == StartingBase.CORRIDOR_DEF and room.origin == cell:
			return room.is_built()
	return false


## Digging is refused until Excavation survey; granted directly, Level 2 ($1,500k, 3 days)
## is dug.
func _dig_level_2(player: M15Player) -> void:
	var refused: CommandResult = DigLevelCommand.new().validate(player.state())
	assert_str(String(refused.error_code)).is_equal("needs_research")
	assert_bool(UnlockFixture.apply_project(player.state().unlocks, &"excavation_survey")).is_true()
	var funds: int = player.state().budget.funds_k
	assert_bool(player.simulation.submit(DigLevelCommand.new()).is_ok).is_true()
	assert_int(player.state().budget.funds_k).is_equal(funds - 1500)
	assert_int(player.state().base.digging_level()).is_equal(2)
	var started: int = player.state().clock.tick
	while player.state().base.digging_level() != 0:
		player.step()
	assert_int(player.state().clock.tick - started).is_equal(3 * TimeMath.TICKS_PER_DAY)
	assert_int(player.state().base.level_count).is_equal(2)


## At the next daily settlement the budget gains $(50 + Confidence)k less a 30th of the costs
## per 30 days, with the carry: the starting $190k, the bank's $10k and the lab's $60k (it is
## on); corridors pay nothing. The five starting staff are paid $145k (m27-daily-rhythm.md
## section 1).
func _assert_daily_settlement(player: M15Player) -> void:
	var state: GameState = player.state()
	while not TimeMath.is_day_start(state.clock.tick + 1):
		player.step()
	var funds: int = state.budget.funds_k
	var allocation: int = 50 + state.committee.whole()
	var owed: int = (190 + 10 + 60) + StaffRules.salaries_k(state) + state.committee.cost_carry
	player.step()
	assert_int(state.budget.funds_k).is_equal(funds + allocation - owed / 30)
	assert_int(state.committee.cost_carry).is_equal(owed % 30)


## With the lab switched off and charging back at 25 MW, the charge out-runs the open
## wormhole's 20 MWh/h drain, so a lock stays open. With the charge rate lowered below the
## drain (the lab switched on with the MW freed), the next lock, dialed as soon as SILL's
## charge is ready, closes for power when the capacitors run empty, before its time runs out.
func _assert_empty_capacitors_close(player: M15Player) -> void:
	var state: GameState = player.state()
	var sill: GateAddress = player.address(M15Player.PUZZLES[0]["glyphs"])
	var lab: RoomState = PowerFixture.first_room(state, LAB_DEF)
	var bank: StringName = state.power.charge_rates.keys()[0]
	assert_bool(player.simulation.submit(SwitchRoomCommand.create(lab.id, false)).is_ok).is_true()
	assert_bool(player.simulation.submit(SetChargeRateCommand.create(bank, 25)).is_ok).is_true()
	assert_bool(player.wait_for_charge(sill)).is_true()
	assert_int(player.dial(sill).outcome).is_equal(DialOutcome.Kind.LOCK)
	var stored: float = state.power.stored_mwh
	for _tick: int in state.balance.max_open_ticks / 2:
		player.step()
	assert_int(state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_float(state.power.stored_mwh).is_greater(stored)
	assert_bool(player.close_wormhole()).is_true()
	var lower := SetChargeRateCommand.create(bank, LOW_CHARGE_MW)
	assert_bool(player.simulation.submit(lower).is_ok).is_true()
	assert_bool(player.simulation.submit(SwitchRoomCommand.create(lab.id, true)).is_ok).is_true()
	assert_bool(lab.powered_on).is_true()
	assert_bool(player.wait_for_charge(sill)).is_true()
	_closed_reasons.clear()
	assert_int(player.dial(sill).outcome).is_equal(DialOutcome.Kind.LOCK)
	var opened: int = state.gate.lock_started_tick
	while state.gate.mode == GateState.RingMode.LOCKED:
		player.step()
	assert_array(_closed_reasons).is_equal([GateSystem.REASON_POWER])
	assert_int(state.clock.tick - opened).is_less(state.balance.max_open_ticks)
	assert_float(state.power.stored_mwh).is_less_equal(0.0)
