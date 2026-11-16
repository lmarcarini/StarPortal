## M2.7 end to end, headless, in the running shell over the real data/ content
## (docs/content/m27-daily-rhythm.md): a new game; Quarters is in the Base tab's Build palette
## and a placement is put away with a right click on the plan. The bank is built from the Gate
## Room's button, the lab's corridor is painted with a drag and the lab placed from the palette.
## SILL locks on time and Confidence rises at once by 5, then drifts 0.1 toward 50 at the next
## daily settlement, which pays the day's allocation less a thirtieth of the costs. The tech
## tree's Start runs Excavation survey and N2 is dug from the Build sub-tab's Dig. On 4 January
## a new candidate arrives and is hired from the Personnel tab (F5). A click on Conf. opens the
## Command tab, whose figures match the state.
## Bible: roadmap.md (M2 check), technical-architecture.md#testing-and-tooling,
## docs/content/m27-daily-rhythm.md sections 1 to 4, docs/content/m2-base.md section 6
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const M15Player := preload("res://tests/gate/m15_player.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

## Seed of the played game, as in test_m26_flow.gd.
const SEED: int = 20_261_105
## The lab's corridor run and the Research Lab on Level 1, as in test_m26_flow.gd.
const RUN_FROM: Vector2i = Vector2i(24, 9)
const RUN_TO: Vector2i = Vector2i(24, 5)
const LAB_DEF: StringName = &"room_research_lab"
const LAB_ORIGIN: Vector2i = Vector2i(25, 5)
const QUARTERS_DEF: StringName = &"room_quarters"
const SURVEY: StringName = &"excavation_survey"
## 4 January 00:00: the settlement of day 3, when the first new candidate arrives.
const ARRIVAL_DAY: int = 3
## Most ticks the test waits for anything.
const MAX_WAIT_TICKS: int = 10 * TimeMath.TICKS_PER_DAY

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _real_saves_dir: String = ""
var _real_locale: String = ""


func before_test() -> void:
	_real_saves_dir = SaveService.saves_dir
	_real_locale = TranslationServer.get_locale()
	SaveService.saves_dir = "user://test_m27_flow_%d" % Time.get_ticks_usec()
	TranslationServer.set_locale("en")
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = SEED
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()
	SaveService.saves_dir = _real_saves_dir
	TranslationServer.set_locale(_real_locale)


func test_new_game_to_the_command_tab() -> void:
	var player: M15Player = M15Player.new(SimClock.simulation)
	assert_bool(player.state().clock.is_paused).is_true()
	await _cancel_a_quarters_placement(player)
	await _build_bank_from_gate_room(player)
	await _build_lab_from_the_palette(player)
	await _start_survey_from_the_tree(player)
	_lock_sill_and_settle_a_day(player)
	_finish_survey(player)
	var arrived: StringName = _wait_for_a_candidate(player)
	await _hire(player, arrived)
	await _dig_n2_from_the_build_sub_tab(player)
	await _open_command_from_conf(player)
	assert_array(player.rejections).is_empty()


## F3 shows Build; Quarters is offered; picking it starts a ghost and a right click on the plan
## puts it away with nothing built or spent.
func _cancel_a_quarters_placement(player: M15Player) -> void:
	var base: BaseView = await _open_base()
	assert_str(String(base.get_sub_tabs().shown())).is_equal("build")
	var quarters: Button = base.get_palette().get_room_button(QUARTERS_DEF)
	assert_object(quarters).is_not_null()
	assert_str(tr(quarters.text)).is_equal("Quarters")
	assert_bool(quarters.disabled).is_false()
	var rooms: int = player.state().base.rooms.size()
	var funds: int = player.state().budget.funds_k
	await UiInput.click(quarters)
	assert_bool(base.get_build().get_ghost().is_placing()).is_true()
	_mouse_button(base, MOUSE_BUTTON_RIGHT, true, LAB_ORIGIN)
	_mouse_button(base, MOUSE_BUTTON_RIGHT, false, LAB_ORIGIN)
	await _runner.await_input_processed()
	assert_bool(base.get_build().get_ghost().is_placing()).is_false()
	assert_bool(quarters.button_pressed).is_false()
	assert_int(player.state().base.rooms.size()).is_equal(rooms)
	assert_int(player.state().budget.funds_k).is_equal(funds)


## "BUILD BANK" in the Gate Room places the bank's ghost; one confirm builds it.
func _build_bank_from_gate_room(player: M15Player) -> void:
	await _key(KEY_F1)
	var gauge := _shell.find_child("Charge", true, false) as ChargeGauge
	await UiInput.click(gauge.get_build_key())
	var base := _shell.view_switcher.get_view(&"base") as BaseView
	base.get_build().get_ghost().confirm()
	var charging: Callable = func() -> bool: return not player.state().power.charge_rates.is_empty()
	assert_int(_wait(player, charging)).is_equal(60)


## A drag paints the corridor run; Research Lab from the palette, moved to its spot and
## confirmed, finishes 8 hours later.
func _build_lab_from_the_palette(player: M15Player) -> void:
	var base: BaseView = await _open_base()
	base.get_build().start_placing(StartingBase.CORRIDOR_DEF)
	await _drag(base, RUN_FROM, RUN_TO)
	await UiInput.click(base.get_palette().get_room_button(LAB_DEF))
	var ghost: PlacementGhost = base.get_build().get_ghost()
	assert_str(String(ghost.def_id)).is_equal(String(LAB_DEF))
	ghost.move_to(LAB_ORIGIN)
	ghost.confirm()
	var lab: RoomState = PowerFixture.first_room(player.state(), LAB_DEF)
	assert_object(lab).is_not_null()
	assert_int(_wait(player, lab.is_built)).is_equal(8 * 60)


## SILL locks about 17 hours in; Confidence rises by 5 at once. The next settlement pays the
## allocation at the new Confidence, charges a thirtieth of the costs and drifts 0.1 to 50.
func _lock_sill_and_settle_a_day(player: M15Player) -> void:
	var state: GameState = player.state()
	var sill: GateAddress = player.address(M15Player.PUZZLES[0]["glyphs"])
	assert_bool(player.wait_for_charge(sill)).is_true()
	assert_int(state.clock.tick).is_between(1030, 1050)
	var before: int = state.committee.confidence
	assert_int(player.dial(sill).outcome).is_equal(DialOutcome.Kind.LOCK)
	var locked: int = before + ConfidenceRules.LOCK_CHANGE
	assert_int(state.committee.confidence).is_equal(locked)
	assert_bool(player.close_wormhole()).is_true()
	assert_str(_shell.confidence_readout.text).is_equal("Conf. 55 -0.1\u2193")
	var eve: int = (TimeMath.day_index(state.clock.tick) + 1) * TimeMath.TICKS_PER_DAY - 1
	_wait(player, func() -> bool: return state.clock.tick == eve)
	assert_int(state.committee.confidence).is_equal(locked)
	var allocation: int = ConfidenceRules.daily_allocation_k(
		state.balance.daily_allocation_k, ConfidenceRules.whole(locked)
	)
	var charge: Vector2i = ConfidenceRules.daily_charge(
		CommandLedger.costs_k(state), state.committee.cost_carry
	)
	var funds: int = state.budget.funds_k
	player.step()
	assert_int(state.budget.funds_k).is_equal(funds + allocation - charge.x)
	assert_int(state.committee.confidence).is_equal(locked - ConfidenceRules.SETTLING_STEP)
	assert_str(_shell.confidence_readout.text).is_equal("Conf. 54 -0.1\u2193")


## F4, the Excavation survey node and Start begin the survey while the bank charges.
func _start_survey_from_the_tree(player: M15Player) -> void:
	await _key(KEY_F3)
	var view := _shell.view_switcher.get_view(&"research") as ResearchView
	await UiInput.click(view.get_board().get_tree_view().node_of(SURVEY))
	var start: Button = view.get_panel().get_button()
	assert_str(start.text).is_equal("Start")
	await UiInput.click(start)
	assert_str(String(player.state().research.active)).is_equal(String(SURVEY))


## The survey finishes and, on the next tick, adds +3.
func _finish_survey(player: M15Player) -> void:
	var done: Callable = func() -> bool: return player.state().research.is_done(SURVEY)
	_wait(player, done)
	var before: int = player.state().committee.confidence
	player.step()
	assert_int(player.state().committee.confidence).is_equal(
		before + ConfidenceRules.RESEARCH_CHANGE
	)


## Back on Base, the Build sub-tab's Dig is now available; holding it starts N2 as a
## construction, shown on the level tabs, and N2 is dug.
func _dig_n2_from_the_build_sub_tab(player: M15Player) -> void:
	var base: BaseView = await _open_base()
	assert_str(String(base.get_sub_tabs().shown())).is_equal("build")
	var dig: DigButton = base.get_palette().get_dig_button()
	assert_bool(dig.disabled).is_false()
	assert_str(dig.text).is_equal("Dig Level 2: $1,500k, 3 d")
	dig.confirmed.emit()
	await _runner.await_input_processed()
	assert_int(player.state().base.digging_level()).is_equal(2)
	var tabs := base.find_child("LevelTabs", true, false) as LevelTabs
	assert_str((tabs.get_child(1) as Button).text).is_equal("L2 0%")
	_wait(player, func() -> bool: return player.state().base.digging_level() == 0)
	assert_int(player.state().base.level_count).is_equal(2)


## Runs to the settlement of 4 January: a new candidate arrives, staying 12 days. Returns its id.
func _wait_for_a_candidate(player: M15Player) -> StringName:
	var state: GameState = player.state()
	var day_start: int = ARRIVAL_DAY * TimeMath.TICKS_PER_DAY
	assert_int(state.clock.tick).is_less(day_start)
	var known: Array[StringName] = []
	for candidate: CandidateState in state.recruitment.candidates:
		known.append(candidate.id)
	_wait(player, func() -> bool: return state.clock.tick >= day_start)
	var arrived: Array[CandidateState] = state.recruitment.candidates.filter(
		func(c: CandidateState) -> bool: return not known.has(c.id)
	)
	assert_int(arrived.size()).is_equal(1)
	assert_int(arrived[0].leaves_day).is_equal(ARRIVAL_DAY + RecruitmentRules.STAY_DAYS)
	return arrived[0].id


## F5, Candidates, the new candidate's row and Hire: the fee is paid and the hire is on the way.
func _hire(player: M15Player, candidate_id: StringName) -> void:
	_shell.view_switcher.show_view(ViewSwitcher.PERSONNEL)
	var view := _shell.view_switcher.get_view(&"personnel") as PersonnelView
	view.get_board().show_page(PersonnelBoard.Page.CANDIDATES)
	view.get_board().row_of(candidate_id).grab_focus()
	await _runner.await_input_processed()
	var hire: Button = view.get_panel().get_hire_button()
	var candidate: CandidateState = player.state().recruitment.find_candidate(candidate_id)
	var fee: int = RecruitmentRules.fee_k(candidate)
	assert_str(hire.text).is_equal("Hire (fee %s)" % MoneyLabel.format_k(fee))
	var funds: int = player.state().budget.funds_k
	await UiInput.click(hire)
	assert_int(player.state().staff.people.size()).is_equal(8)
	assert_str(player.state().staff.people.back().name).is_equal(candidate.name)
	assert_int(player.state().budget.funds_k).is_equal(funds - fee)


## A click on Conf. opens the Command tab; its header, allocation and Committee summary match.
func _open_command_from_conf(player: M15Player) -> void:
	await _key(KEY_F1)
	await UiInput.click(_shell.confidence_readout)
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("command")
	var state: GameState = player.state()
	var view := _shell.view_switcher.get_view(&"command") as CommandView
	var conf: String = CommitteeText.one_decimal(state.committee.confidence)
	var board: Array[String] = view.get_board().texts()
	assert_array(board).contains([CommandText.funds_line(state), "Conf. %s" % conf])
	var allocation: CommandLine = view.get_board().lines()[0]
	assert_int(allocation.kind).is_equal(CommandLine.Kind.ALLOCATION)
	var daily: int = ConfidenceRules.daily_allocation_k(
		state.balance.daily_allocation_k, state.committee.whole()
	)
	assert_int(allocation.per_period_k).is_equal(daily * ConfidenceRules.PERIOD_DAYS)
	assert_array(view.get_panel().texts()).contains(["Confidence %s" % conf])


func _open_base() -> BaseView:
	await _key(KEY_F2)
	return _shell.view_switcher.get_view(&"base") as BaseView


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await _runner.await_input_processed()


## A drag on the plan from [param from] to [param to] through the ghost's GUI entry, as in
## test_m26_flow.gd.
func _drag(base: BaseView, from: Vector2i, to: Vector2i) -> void:
	_mouse_move(base, from, 0)
	_mouse_button(base, MOUSE_BUTTON_LEFT, true, from)
	await get_tree().process_frame
	var step: Vector2i = (to - from).sign()
	var cell: Vector2i = from
	while cell != to:
		cell += step
		_mouse_move(base, cell, MOUSE_BUTTON_MASK_LEFT)
	await get_tree().process_frame
	_mouse_button(base, MOUSE_BUTTON_LEFT, false, to)
	await get_tree().process_frame


func _at(base: BaseView, cell: Vector2i) -> Vector2:
	var plan: BasePlan = base.get_plan()
	return (
		plan.view.offset
		+ (Vector2(cell) + Vector2(0.5, 0.5)) * BasePlanPainter.CELL * plan.view.scale()
	)


func _mouse_move(base: BaseView, cell: Vector2i, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _at(base, cell)
	event.button_mask = mask
	base.get_build().get_ghost()._gui_input(event)


## A mouse button on the plan, given to the ghost and the plan as in test_cancel_placement.gd.
func _mouse_button(base: BaseView, button: MouseButton, pressed: bool, cell: Vector2i) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = _at(base, cell)
	base.get_build().get_ghost()._gui_input(event)
	if button == MOUSE_BUTTON_RIGHT:
		BasePlanInput.handle(base.get_plan(), event)


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
