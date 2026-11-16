## M3a end to end, headless, in the running shell over the real data/ content
## (docs/content/m3-beyond-the-ring.md section 1, "The loop in one page"): a new game; the bank
## is built from the Gate Room's button and SILL is dialed. On the open wormhole the send
## rail's keys throw the sample canister and send the MOTH, whose scan screen runs Look around,
## Close look and Sky and recalls it: SILL is Probed and Expeditions unlock with the two lent
## soldiers. The World Report (Archive, Worlds) shows the threat and its Plan expedition opens
## the mission sheet on the Gate station, prefilled for a Survey of SILL; GO sends T-1 through
## the same lock. The team comes home with SILL Surveyed, ending the Prologue (once). A second
## Survey, whose first check-in is forced missed, pauses the game and opens the rescue alert;
## Go to Gate, a new lock and TEAM (signal T-1) bring the team home and close the window.
## Bible: docs/content/m3-beyond-the-ring.md sections 1, 2, 4 and 7,
## technical-architecture.md#testing-and-tooling
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const M15Player := preload("res://tests/gate/m15_player.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

## Seed of the played game, as in test_m27_flow.gd.
const SEED: int = 20_261_105
const SILL: StringName = &"world_sill"
const SLAB: StringName = &"slab"
## Most ticks the test waits for anything.
const MAX_WAIT_TICKS: int = 10 * TimeMath.TICKS_PER_DAY

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _real_saves_dir: String = ""
var _real_locale: String = ""
var _messages: Array[String] = []


func before_test() -> void:
	_real_saves_dir = SaveService.saves_dir
	_real_locale = TranslationServer.get_locale()
	SaveService.saves_dir = "user://test_m3a_flow_%d" % Time.get_ticks_usec()
	TranslationServer.set_locale("en")
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = SEED
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()
	_messages.clear()


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()
	SaveService.saves_dir = _real_saves_dir
	TranslationServer.set_locale(_real_locale)


func test_first_threshold_team_and_a_rescue() -> void:
	var player: M15Player = M15Player.new(SimClock.simulation)
	preload("res://tests/gate/dial_fixture.gd").give_moth_rack(player.state())
	assert_bool(player.state().clock.is_paused).is_true()
	await _build_bank_from_gate_room(player)
	await _lock_sill(player)
	await _throw_the_canister(player)
	await _probe_with_the_moth(player)
	await _plan_from_the_world_report()
	await _send_and_close(player)
	await _check_in_and_come_home(player)
	_force_a_missed_check_in(player)
	await _lock_sill(player)
	await _plan_from_the_world_report()
	await _send_and_close(player)
	await _miss_and_open_the_alert(player)
	await _rescue(player)
	assert_array(player.rejections).is_empty()


## "BUILD BANK" in the Gate Room places the bank's ghost; one confirm builds it.
func _build_bank_from_gate_room(player: M15Player) -> void:
	await _key(KEY_F1)
	var gauge := _shell.find_child("Charge", true, false) as ChargeGauge
	await UiInput.click(gauge.get_build_key())
	var base := _shell.view_switcher.get_view(&"base") as BaseView
	base.get_build().get_ghost().confirm()
	_wait(player, func() -> bool: return not player.state().power.charge_rates.is_empty())


## Charges for SILL, dials it and shows the open wormhole's Ring actions in the Gate Room.
func _lock_sill(player: M15Player) -> void:
	var sill: GateAddress = player.address(M15Player.PUZZLES[0]["glyphs"])
	assert_bool(player.wait_for_charge(sill)).is_true()
	assert_int(player.dial(sill).outcome).is_equal(DialOutcome.Kind.LOCK)
	await _key(KEY_F1)
	await _runner.await_input_processed()
	_rail().refresh()
	assert_bool(_rail().visible).is_true()


## Throw the sample canister costs $10k and is reeled back 10 minutes later with the biohazard.
func _throw_the_canister(player: M15Player) -> void:
	var canister: IconKey = _rail().get_key(&"canister")
	assert_bool(canister.disabled).is_false()
	var funds: int = player.state().budget.funds_k
	await UiInput.click(canister)
	assert_int(player.state().budget.funds_k).is_equal(funds - MothRules.CANISTER_COST_K)
	assert_bool(player.state().probes.is_canister_out()).is_true()


## Send the MOTH opens the scan screen; Look around, Close look at the slab and Sky run, then
## RECALL flies it home. SILL is Probed, the canister is back and Expeditions unlock.
func _probe_with_the_moth(player: M15Player) -> void:
	await UiInput.click(_rail().get_key(&"moth"))
	var moth: MothScreen = _station().get_moth_screen()
	assert_bool(moth.is_open()).is_true()
	await _scan(player, MothRules.Scan.LOOK_AROUND)
	await _scan(player, MothRules.Scan.CLOSE_LOOK, SLAB)
	await _scan(player, MothRules.Scan.SKY)
	await UiInput.click(moth.get_recall_button())
	_steps(player, MothRules.minutes_of(MothRules.Scan.RECALL) + 1)
	assert_bool(moth.is_open()).is_false()
	assert_bool(player.state().worlds.has_reached(SILL, WorldsState.WorldStatus.PROBED)).is_true()
	assert_bool(player.state().probes.is_canister_out()).is_false()
	assert_bool(ExpeditionUnlock.is_unlocked(player.state())).is_true()
	for lent: String in ExpeditionUnlock.FIRST_LENT:
		assert_bool(player.state().staff.people.any(_named(lent))).is_true()


func _scan(player: M15Player, scan: MothRules.Scan, target: StringName = &"") -> void:
	var moth: MothScreen = _station().get_moth_screen()
	var button: Button = moth.get_scan_list().get_button(scan, target)
	assert_object(button).is_not_null()
	await UiInput.click(button)
	_steps(player, MothRules.minutes_of(scan))
	moth.refresh()
	assert_bool(player.state().gate.mode == GateState.RingMode.LOCKED).is_true()


## Archive (F6), Worlds, SILL: the report shows a threat; Plan expedition opens the Gate's
## mission sheet on SILL, prefilled for a Survey with four fit members.
func _plan_from_the_world_report() -> void:
	await _key(KEY_F6)
	var archive := _shell.view_switcher.get_view(&"archive") as ArchiveView
	archive.show_worlds()
	archive.get_worlds().open_world(SILL)
	var report: WorldReportPanel = archive.get_worlds().get_report()
	assert_str(report.get_value_text(WorldReport.Fact.THREAT)).is_not_empty()
	await UiInput.click(report.get_plan_button())
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("gate_room")
	var sheet: MissionSheet = _station().get_mission_sheet()
	assert_bool(sheet.visible).is_true()
	assert_str(String(sheet.get_draft().world_id)).is_equal(String(SILL))
	assert_int(sheet.get_draft().objective).is_equal(ExpeditionState.Objective.SURVEY)
	assert_int(sheet.get_draft().team.size()).is_equal(ExpeditionState.SLOTS.size())
	assert_str(String(sheet.reason())).is_empty()


## GO on the mission sheet sends T-1 through the open wormhole, which then closes.
func _send_and_close(player: M15Player) -> void:
	_station().get_mission_sheet().go()
	await _runner.await_input_processed()
	assert_int(player.state().expedition.mode).is_equal(ExpeditionState.Mode.AWAY)
	assert_bool(player.close_wormhole()).is_true()


## The Survey works silently (a team talks only through an open gate, M4.9-11) and comes home
## at +48 h: SILL is Surveyed and the plan clears.
func _check_in_and_come_home(player: M15Player) -> void:
	var state: GameState = player.state()
	_wait(player, func() -> bool: return state.expedition.mode == ExpeditionState.Mode.IDLE)
	_wait(player, func() -> bool: return state.gate.mode == GateState.RingMode.IDLE)
	assert_bool(state.worlds.has_reached(SILL, WorldsState.WorldStatus.SURVEYED)).is_true()
	var prologue: String = "Prologue complete: the first Threshold team is home."
	assert_str(_shell.get_toast_text()).is_equal(prologue)
	assert_bool(state.flags.get(ExpeditionSystem.PROLOGUE_FLAG, false)).is_true()
	var lines: Array = state.operations_log.entries.filter(
		func(e: LogEntry) -> bool: return e.args.get("reason", "") == "prologue"
	)
	assert_int(lines.size()).is_equal(1)


## The game's own ExpeditionSystem misses the next team's first check-in (field events' worst
## setback, forced here so the run does not depend on a roll).
func _force_a_missed_check_in(player: M15Player) -> void:
	for system: SimSystem in player.simulation._systems:
		if system is ExpeditionSystem:
			(system as ExpeditionSystem).resolve_day = (func(
				_s: GameState, day: int, _r: RandomNumberGenerator
			) -> String:
				return ExpeditionState.DAY_MISSED if day == 0 else ExpeditionState.DAY_OK)


## At the missed check-in the game pauses and the rescue alert opens over the tab.
func _miss_and_open_the_alert(player: M15Player) -> void:
	var state: GameState = player.state()
	_wait(player, func() -> bool: return state.expedition.mode == ExpeditionState.Mode.MISSING)
	await _runner.await_input_processed()
	var alert: RescueAlert = _shell.get_rescue_alert()
	assert_bool(alert.visible).is_true()
	assert_bool(state.clock.is_paused).is_true()
	assert_str(alert.texts()[0]).starts_with("T-1 MISSED ITS CHECK-IN (")
	assert_bool(_shell.get_alert_stack().get_rescue_button().visible).is_true()
	await UiInput.click(alert.get_gate_button())
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("gate_room")
	_wait(player, func() -> bool: return state.gate.has_incoming())
	assert_bool(player.simulation.submit(AnswerIncomingCommand.new()).is_ok).is_true()
	var hold: OrderTeamCommand = OrderTeamCommand.create(TeamContactRules.Order.HOLD_ON)
	assert_bool(player.simulation.submit(hold).is_ok).is_true()
	assert_int(state.gate.mode).is_equal(GateState.RingMode.IDLE)


## A new lock on SILL and Signal T-1: the team reaches the Ring 15 minutes later; the window
## closes, the alert and its stack entry hide, and no one is left away.
func _rescue(player: M15Player) -> void:
	var state: GameState = player.state()
	await _lock_sill(player)
	var signal_key: IconKey = _rail().get_key(&"team")
	assert_bool(signal_key.visible).is_true()
	await UiInput.click(signal_key)
	assert_int(state.expedition.signal_tick).is_equal(state.clock.tick)
	_wait(player, func() -> bool: return state.expedition.mode == ExpeditionState.Mode.IDLE)
	await _runner.await_input_processed()
	assert_bool(_shell.get_rescue_alert().visible).is_false()
	assert_bool(_shell.get_alert_stack().get_rescue_button().visible).is_false()
	assert_bool(player.close_wormhole()).is_true()
	var prologues: Array = state.operations_log.entries.filter(
		func(e: LogEntry) -> bool: return e.args.get("reason", "") == "prologue"
	)
	assert_int(prologues.size()).is_equal(1)


func _station() -> GateStationView:
	return _shell.view_switcher.get_view(&"gate_room") as GateStationView


func _rail() -> SendRail:
	return _station().get_rail()


static func _named(display_name: String) -> Callable:
	return func(p: PersonState) -> bool: return p.name == display_name


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await _runner.await_input_processed()


func _steps(player: M15Player, ticks: int) -> void:
	for index: int in ticks:
		player.step()


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
