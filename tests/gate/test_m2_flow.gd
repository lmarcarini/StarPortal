## M2 end to end, headless, over the real data/ content: a new game opens on the Gate Room, whose
## "Build capacitor bank" button switches to the Base tab with the bank's ghost on the nearest valid
## spot to the Gate Room, and one click builds it. The bank completes after 6 hours and takes the
## spare 26 MW; SILL then charges and locks, and the pole camera brings its documents. The player
## paints a corridor and builds a Physics Lab against it on Level 2 (it completes off: the bank
## holds all the spare power, and switching it on is refused), digs Level 4, and the month-end pays
## the allocation less the upkeep. Last, with the total charge rate lowered below the open
## wormhole's 20 MWh/h drain, a lock closes when the capacitors run empty.
## Bible: roadmap.md (M2 check), technical-architecture.md#testing-and-tooling,
## docs/content/m2-base.md sections 2 to 5
extends GdUnitTestSuite

const M15Player := preload("res://tests/gate/m15_player.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")
const SWITCHER_SCENE: String = "res://src/ui/views/view_switcher.tscn"

## Seed of the played game.
const SEED: int = 20_261_101
## The corridor run on Level 2: from the spine up column 20.
const CORRIDOR_LEVEL: int = 2
const CORRIDOR_RUN: Array[Vector2i] = [
	Vector2i(20, 14), Vector2i(20, 13), Vector2i(20, 12), Vector2i(20, 11), Vector2i(20, 10)
]
## Where the Physics Lab (4 × 3) stands: east of the corridor run, touching it.
const LAB_DEF: StringName = &"room_physics_lab"
const LAB_ORIGIN: Vector2i = Vector2i(21, 10)
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
	_dig_level_4(player)
	_assert_month_end(player)
	_assert_empty_capacitors_close(player)
	assert_array(player.rejections).is_empty()


func _on_event(event_name: StringName, args: Array) -> void:
	if event_name == &"wormhole_closed":
		_closed_reasons.append(args[0])


## The Gate Room's button switches to the Base tab on Level 3 with the bank's ghost green on
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
	var gauge := switcher.find_child("CapacitorGauge", true, false) as CapacitorGauge
	assert_str(tr(gauge.get_build_button().text)).is_equal("Build capacitor bank")
	await UiInput.click(gauge.get_build_button())
	assert_str(String(switcher.current_view_id())).is_equal("base")
	var base := switcher.get_view(&"base") as BaseView
	var ghost: PlacementGhost = base.get_build().get_ghost()
	assert_bool(ghost.is_placing()).is_true()
	assert_int(base.get_plan().level).is_equal(3)
	var spot: Vector2i = BaseSpots.bank_spot(player.state().base, player.state().room_defs)
	assert_vector(Vector2(ghost.origin)).is_equal(Vector2(spot))
	assert_str(ghost.reason()).is_empty()
	var funds: int = player.state().budget.funds_k
	ghost.confirm()
	assert_int(player.state().budget.funds_k).is_equal(funds - 600)
	assert_bool(CapacitorGauge.needs_bank(player.state())).is_false()
	_root.free()
	_root = null


## The site takes 360 ticks (6 hours); the bank then charges at the spare 26 MW.
func _assert_bank_completes(player: M15Player) -> void:
	for _tick: int in 359:
		player.step()
	assert_bool(player.state().power.charge_rates.is_empty()).is_true()
	player.step()
	assert_array(player.state().power.charge_rates.values()).is_equal([26])
	assert_float(PowerRules.spare_mw(player.state())).is_equal(0.0)


## SILL charges (about 14 hours at 26 MW), locks, and the pole camera brings its documents.
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


## Paints a corridor run off the Level 2 spine, builds a Physics Lab against it, and waits for
## both. The lab completes switched off (no spare power), and switching it on is refused
## until the bank's charge rate is lowered.
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
	assert_bool(lab.powered_on).is_false()
	var refused: CommandResult = player.simulation.submit(SwitchRoomCommand.create(lab.id, true))
	assert_str(String(refused.error_code)).is_equal("no_spare_power")
	assert_bool(lab.powered_on).is_false()
	player.rejections.clear()


func _corridor_built_at(state: GameState, cell: Vector2i) -> bool:
	for room: RoomState in BaseRules.rooms_on_level(state.base, CORRIDOR_LEVEL):
		if room.def_id == StartingBase.CORRIDOR_DEF and room.origin == cell:
			return room.is_built()
	return false


## Digs Level 4 ($3,000k, 20 days) and waits for it.
func _dig_level_4(player: M15Player) -> void:
	var funds: int = player.state().budget.funds_k
	assert_bool(player.simulation.submit(DigLevelCommand.new()).is_ok).is_true()
	assert_int(player.state().budget.funds_k).is_equal(funds - 3000)
	assert_int(player.state().base.digging_level()).is_equal(4)
	var started: int = player.state().clock.tick
	while player.state().base.digging_level() != 0:
		player.step()
	assert_int(player.state().clock.tick - started).is_equal(20 * TimeMath.TICKS_PER_DAY)
	assert_int(player.state().base.level_count).is_equal(4)


## At the month-end the budget gains the $3,000k allocation less the upkeep: the starting
## $240k, the bank's $10k and half the lab's $60k (it is off); corridors pay nothing.
func _assert_month_end(player: M15Player) -> void:
	var closes: Array[int] = []
	player.simulation.month_closed.connect(
		func(_year: int, _month: int) -> void: closes.append(player.state().clock.tick)
	)
	var funds: int = player.state().budget.funds_k
	while closes.is_empty():
		player.step()
	assert_int(player.state().budget.funds_k).is_equal(funds + 3000 - (240 + 10 + 30))


## At the starting 26 MW the charge out-runs the open wormhole's 20 MWh/h drain, so a lock
## stays open. With the charge rate lowered below the drain (the lab switched on with the MW
## freed), the next lock, dialed as soon as SILL's charge is ready, closes for power when the
## capacitors run empty, before its time runs out.
func _assert_empty_capacitors_close(player: M15Player) -> void:
	var state: GameState = player.state()
	var sill: GateAddress = player.address(M15Player.PUZZLES[0]["glyphs"])
	assert_int(player.dial(sill).outcome).is_equal(DialOutcome.Kind.LOCK)
	var stored: float = state.power.stored_mwh
	for _tick: int in state.balance.max_open_ticks / 2:
		player.step()
	assert_int(state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_float(state.power.stored_mwh).is_greater(stored)
	assert_bool(player.close_wormhole()).is_true()
	var bank: StringName = state.power.charge_rates.keys()[0]
	var lower := SetChargeRateCommand.create(bank, LOW_CHARGE_MW)
	assert_bool(player.simulation.submit(lower).is_ok).is_true()
	var lab: RoomState = PowerFixture.first_room(state, LAB_DEF)
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
