## M3a end to end, headless, in the running shell over the real data/ content
## (docs/content/m3-beyond-the-ring.md section 1, "The loop in one page"): a new game; the bank
## is built from the Gate Room's button and SILL is dialed. On the open wormhole the Ring
## actions throw the sample canister and send the MOTH, whose scan screen runs Look around,
## Close look and Sky and recalls it: SILL is Probed and Expeditions unlock with the two lent
## soldiers. The World Report (Archive, Worlds) shows the threat and its Plan expedition opens
## the Expeditions tab (F7) on SILL; four slots are picked and Ready team plans the Survey; the
## Ring action Send team sends T-1 through the same lock. The team checks in (a message, the
## check-in panel) and comes home with SILL Surveyed, ending the Prologue (once). A second
## Survey, whose first check-in is forced missed, pauses the game and opens the rescue alert;
## Go to Gate Room, a new lock and Signal T-1 bring the team home and close the window.
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
## Slots filled in this order: the leader (anyone) last, so the roles are taken first.
const PICK_ORDER: Array[String] = ["scientist", "soldier", "specialist", "leader"]
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
	EventBus.team_checked_in.connect(_on_checked_in)


func after_test() -> void:
	if EventBus.team_checked_in.is_connected(_on_checked_in):
		EventBus.team_checked_in.disconnect(_on_checked_in)
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
	await _plan_from_the_world_report(player)
	await _send_and_close(player)
	await _check_in_and_come_home(player)
	_force_a_missed_check_in(player)
	await _lock_sill(player)
	await _plan_from_the_world_report(player)
	await _send_and_close(player)
	await _miss_and_open_the_alert(player)
	await _rescue(player)
	assert_array(player.rejections).is_empty()


## "Build capacitor bank" in the Gate Room places the bank's ghost; one confirm builds it.
func _build_bank_from_gate_room(player: M15Player) -> void:
	await _key(KEY_F1)
	var gauge := _shell.find_child("CapacitorGauge", true, false) as CapacitorGauge
	await UiInput.click(gauge.get_build_button())
	var base := _shell.view_switcher.get_view(&"base") as BaseView
	base.get_build().get_ghost().confirm()
	_wait(player, func() -> bool: return not player.state().power.charge_rates.is_empty())


## Charges for SILL, dials it and shows the open wormhole's Ring actions in the Gate Room.
func _lock_sill(player: M15Player) -> void:
	var sill: GateAddress = player.address(M15Player.PUZZLES[0]["glyphs"])
	assert_bool(player.wait_for_charge(sill)).is_true()
	assert_int(player.dial(sill).outcome).is_equal(DialOutcome.Kind.LOCK)
	await _key(KEY_F1)
	var screen: WormholeScreen = _gate_room().get_overlays().get_wormhole_screen()
	if not screen.is_showing_open():
		screen.open()
	if not screen.are_actions_shown():
		_gate_room().get_ring_view().portal_pressed.emit()
	await _runner.await_input_processed()
	_actions().render(player.state())


## Throw the sample canister costs $10k and is reeled back 10 minutes later with the biohazard.
func _throw_the_canister(player: M15Player) -> void:
	var canister: Button = _actions().get_team_actions().get_canister_button()
	assert_bool(canister.disabled).is_false()
	var funds: int = player.state().budget.funds_k
	await UiInput.click(canister)
	assert_int(player.state().budget.funds_k).is_equal(funds - MothRules.CANISTER_COST_K)
	assert_bool(player.state().probes.is_canister_out()).is_true()


## Send the MOTH opens the scan screen; Look around, Close look at the slab and Sky run, then
## RECALL flies it home. SILL is Probed, the canister is back and Expeditions unlock.
func _probe_with_the_moth(player: M15Player) -> void:
	await UiInput.click(_actions().get_moth_button())
	var moth: MothScreen = _gate_room().get_moth_screen()
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
	var moth: MothScreen = _gate_room().get_moth_screen()
	var button: Button = moth.get_scan_list().get_button(scan, target)
	assert_object(button).is_not_null()
	await UiInput.click(button)
	_steps(player, MothRules.minutes_of(scan))
	moth.refresh()
	assert_bool(player.state().gate.mode == GateState.RingMode.LOCKED).is_true()


## Archive (F2), Worlds, SILL: the report shows a threat; Plan expedition opens F7 on SILL.
## The four slots are picked from their rosters and Ready team plans a Survey.
func _plan_from_the_world_report(player: M15Player) -> void:
	await _key(KEY_F6)
	var archive := _shell.view_switcher.get_view(&"archive") as ArchiveView
	archive.show_worlds()
	archive.get_worlds().open_world(SILL)
	var report: WorldReportPanel = archive.get_worlds().get_report()
	assert_str(report.get_value_text(WorldReport.Fact.THREAT)).is_not_empty()
	await UiInput.click(report.get_plan_button())
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("expeditions")
	var sheet: ExpeditionPlanSheet = _expeditions().get_sheet()
	assert_str(String(sheet.get_draft().world_id)).is_equal(String(SILL))
	assert_str(sheet.get_objective_buttons()[0].text).is_equal("Survey")
	_pick_team(player, sheet)
	assert_str(sheet.texts()[1]).starts_with("Risk ")
	await UiInput.click(sheet.get_ready_button())
	assert_int(player.state().expedition.mode).is_equal(ExpeditionState.Mode.PLANNED)


## Picks, slot by slot, the first fit person who is neither injured nor already picked.
func _pick_team(player: M15Player, sheet: ExpeditionPlanSheet) -> void:
	var taken: Array[StringName] = []
	for slot: String in PICK_ORDER:
		var picker: OptionButton = sheet.get_slot_picker(slot)
		for index: int in picker.item_count:
			var meta: Variant = picker.get_item_metadata(index)
			if not meta is StringName:
				continue
			var id: StringName = meta
			if id.is_empty() or taken.has(id):
				continue
			if player.state().staff.find_person(id).is_injured():
				continue
			picker.select(index)
			picker.item_selected.emit(index)
			taken.append(id)
			break
	assert_int(taken.size()).is_equal(ExpeditionState.SLOTS.size())


## Back in the Gate Room the Ring actions offer Send team; it sends T-1 and the wormhole closes.
func _send_and_close(player: M15Player) -> void:
	await _key(KEY_F1)
	_actions().render(player.state())
	var send: Button = _actions().get_team_actions().get_team_button()
	assert_bool(send.visible).is_true()
	assert_bool(send.disabled).is_false()
	await UiInput.click(send)
	assert_int(player.state().expedition.mode).is_equal(ExpeditionState.Mode.AWAY)
	assert_bool(player.close_wormhole()).is_true()


## The Survey checks in at +24 h (a message, the Expeditions tab's check-in) and comes home at
## +48 h: SILL is Surveyed and the plan clears.
func _check_in_and_come_home(player: M15Player) -> void:
	var state: GameState = player.state()
	_wait(player, func() -> bool: return not _messages.is_empty())
	assert_str(_shell.get_toast_text()).starts_with("T-1 checked in from ")
	assert_str(_expeditions().get_check_in().texts()[0]).starts_with("CHECK-IN  ")
	_wait(player, func() -> bool: return state.expedition.mode == ExpeditionState.Mode.IDLE)
	assert_bool(state.worlds.has_reached(SILL, WorldsState.WorldStatus.SURVEYED)).is_true()
	var prologue: String = "Prologue complete: the first Threshold team is home."
	assert_str(_shell.get_toast_text()).is_equal(prologue)
	assert_bool(state.flags.get(ExpeditionSystem.PROLOGUE_FLAG, false)).is_true()
	var lines: Array = state.operations_log.entries.filter(
		func(e: LogEntry) -> bool: return e.args.get("reason", "") == "prologue"
	)
	assert_int(lines.size()).is_equal(1)
	await _key(KEY_F5)
	assert_str(_expeditions().get_trip().texts()[5]).contains("Survey report")


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


## A new lock on SILL and Signal T-1: the team reaches the Ring 15 minutes later; the window
## closes, the alert and its stack entry hide, and no one is left away.
func _rescue(player: M15Player) -> void:
	var state: GameState = player.state()
	await _lock_sill(player)
	var signal_button: Button = _actions().get_team_actions().get_signal_button()
	assert_bool(signal_button.visible).is_true()
	await UiInput.click(signal_button)
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


func _gate_room() -> GateRoomView:
	return _shell.view_switcher.get_view(&"gate_room") as GateRoomView


func _actions() -> WormholeActions:
	return _gate_room().get_overlays().get_wormhole_screen().get_actions()


func _expeditions() -> ExpeditionsView:
	return _shell.view_switcher.get_view(&"expeditions") as ExpeditionsView


func _on_checked_in(_world_id: StringName, _light: int, _serious: int, _day: String) -> void:
	_messages.append(_shell.get_toast_text())


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
