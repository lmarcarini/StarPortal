## M2.6 end to end, headless, over the real data/ content (docs/content/m26-staff-and-money.md):
## a new game opens with the five starting staff. The bank is built from the Gate Room's button;
## the lab's corridor is painted with a mouse drag on the Base plan and the lab finishes staffed
## by the two starting scientists. SILL locks on time. In the Personnel tab (F5) the first
## candidate is hired with the Hire button and, on arrival, assigned to the lab with Assign…:
## the tech tree's Start then runs Excavation survey at 150% (total skill 9). The clock runs,
## unpaused, to 1 February: every daily settlement arrives without a pause, and the lock and
## the project raised Confidence at once (docs/content/m27-daily-rhythm.md sections 1 and 2).
## Bible: roadmap.md (M2 check), technical-architecture.md#testing-and-tooling,
## docs/content/m26-staff-and-money.md sections 2 to 7, docs/content/m27-daily-rhythm.md
extends GdUnitTestSuite

const M15Player := preload("res://tests/gate/m15_player.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")
const SWITCHER_SCENE: String = "res://src/ui/views/view_switcher.tscn"

## Seed of the played game.
const SEED: int = 20_261_105
## The lab's corridor run and the Research Lab on Level 1, as in test_m25_flow.gd.
const LEVEL: int = 1
const RUN_FROM: Vector2i = Vector2i(24, 9)
const RUN_TO: Vector2i = Vector2i(24, 5)
const LAB_DEF: StringName = &"room_research_lab"
const LAB_ORIGIN: Vector2i = Vector2i(25, 5)
## The first fixed candidate: Dr Ines Moreau, Scientist, skill 3, $30k (section 2).
const HIRED_NAME: String = "Dr Ines Moreau"
## Excavation survey's listed time, at a standard crew (total skill 6).
const SURVEY_TICKS: int = 2 * TimeMath.TICKS_PER_DAY
## 1 February 00:00, the 31st daily settlement.
const FEB_1_TICK: int = 31 * TimeMath.TICKS_PER_DAY
## Most ticks the test waits for anything.
const MAX_WAIT_TICKS: int = 40 * TimeMath.TICKS_PER_DAY

var _defs: GameDefs
var _root: Control = null
var _real_locale: String = ""
## Daily settlements seen (budget_changed at a day start): {tick, paused}.
var _reports: Array[Dictionary] = []
var _pause_requests: int = 0
var _simulation: Simulation = null


func before() -> void:
	_defs = GameDefs.from_registry(Registry)


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_reports.clear()
	_pause_requests = 0


func after_test() -> void:
	_free_ui()
	EventBus.bind_simulation(null)
	_simulation = null
	TranslationServer.set_locale(_real_locale)


func test_new_game_to_1_february() -> void:
	var built: Result = GameSetup.build_new(GameState.new_game(SEED, _defs.balance), _defs)
	assert_bool(built.is_ok).override_failure_message(str(built.error_code)).is_true()
	var simulation: Simulation = built.value
	_simulation = simulation
	EventBus.bind_simulation(simulation)
	var player: M15Player = M15Player.new(simulation)
	_assert_starting_crew(player.state())
	await _build_bank_from_gate_room(player)
	await _build_lab_on_a_painted_corridor(player)
	_lock_sill(player)
	var hired: StringName = await _hire_first_candidate(player)
	await _assign_to_the_lab(player, hired)
	await _start_survey_from_the_tree(player)
	_settle_to_february(player)
	assert_array(player.rejections).is_empty()


func _assert_starting_crew(state: GameState) -> void:
	assert_int(state.staff.people.size()).is_equal(5)
	assert_int(StaffRules.beds_free(state)).is_equal(1)
	assert_int(state.committee.confidence).is_equal(ConfidenceRules.START)
	assert_int(state.recruitment.candidates.size()).is_equal(4)
	assert_str(state.recruitment.candidates[0].name).is_equal(HIRED_NAME)


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


## "Build capacitor bank" places the bank's ghost; one click builds it; it charges after 1 hour.
func _build_bank_from_gate_room(player: M15Player) -> void:
	var switcher: ViewSwitcher = _make_switcher(player)
	await UiInput.settle(switcher)
	var gauge := switcher.find_child("CapacitorGauge", true, false) as CapacitorGauge
	await UiInput.click(gauge.get_build_button())
	var base := switcher.get_view(&"base") as BaseView
	base.get_build().get_ghost().confirm()
	_free_ui()
	var charging: Callable = func() -> bool: return not player.state().power.charge_rates.is_empty()
	assert_int(_wait(player, charging)).is_equal(60)


## F3, Corridor, a mouse drag from RUN_FROM to RUN_TO; the lab placed against it finishes
## 8 hours later, on and staffed by the two starting scientists.
func _build_lab_on_a_painted_corridor(player: M15Player) -> void:
	var switcher: ViewSwitcher = _make_switcher(player)
	await UiInput.settle(switcher)
	await UiInput.key(switcher, KEY_F3)
	var base := switcher.get_view(&"base") as BaseView
	var before: int = _corridor_count(player.state())
	base.get_build().start_placing(StartingBase.CORRIDOR_DEF)
	await UiInput.settle(switcher)
	await _drag(base, RUN_FROM, RUN_TO)
	_free_ui()
	assert_int(_corridor_count(player.state())).is_equal(before + 5)
	_submit(player, PlaceRoomCommand.create(LAB_DEF, LEVEL, LAB_ORIGIN))
	var lab: RoomState = PowerFixture.first_room(player.state(), LAB_DEF)
	assert_int(_wait(player, lab.is_built)).is_equal(8 * 60)
	assert_bool(lab.powered_on).is_true()
	assert_int(ResearchRules.speed_percent(player.state())).is_equal(100)


## SILL's lock energy is ready about 17.3 hours in (m25-lean-start.md section 1); it locks.
func _lock_sill(player: M15Player) -> void:
	var sill: GateAddress = player.address(M15Player.PUZZLES[0]["glyphs"])
	assert_bool(player.wait_for_charge(sill)).is_true()
	assert_int(player.state().clock.tick).is_between(1030, 1050)
	assert_int(player.dial(sill).outcome).is_equal(DialOutcome.Kind.LOCK)
	assert_bool(player.close_wormhole()).is_true()


## F5 opens Personnel; on Candidates the first row's Hire (fee $30k) hires Dr Ines Moreau, who
## arrives 5 days later. Returns her id.
func _hire_first_candidate(player: M15Player) -> StringName:
	var switcher: ViewSwitcher = _make_switcher(player)
	await UiInput.settle(switcher)
	await UiInput.key(switcher, KEY_F5)
	assert_str(String(switcher.current_view_id())).is_equal("personnel")
	var view := switcher.get_view(&"personnel") as PersonnelView
	view.get_board().show_page(PersonnelBoard.Page.CANDIDATES)
	view.get_board().rows()[0].grab_focus()
	await UiInput.settle(switcher)
	var hire: Button = view.get_panel().get_hire_button()
	assert_str(hire.text).is_equal("Hire (fee $30k)")
	var funds: int = player.state().budget.funds_k
	await UiInput.click(hire)
	_free_ui()
	var person: PersonState = player.state().staff.people.back()
	assert_str(person.name).is_equal(HIRED_NAME)
	assert_int(player.state().budget.funds_k).is_equal(funds - 30)
	var arrived: Callable = func() -> bool: return person.is_on_base(player.state().clock.tick)
	assert_int(_wait(player, arrived)).is_equal(5 * TimeMath.TICKS_PER_DAY)
	return person.id


## Assign… on the new scientist lists the lab with its effect; picking it raises research to
## 150%.
func _assign_to_the_lab(player: M15Player, person_id: StringName) -> void:
	var switcher: ViewSwitcher = _make_switcher(player)
	await UiInput.settle(switcher)
	await UiInput.key(switcher, KEY_F5)
	var view := switcher.get_view(&"personnel") as PersonnelView
	view.get_board().row_of(person_id).grab_focus()
	await UiInput.settle(switcher)
	var assign: Button = view.get_panel().buttons()[0]
	assert_str(assign.text).is_equal("Assign…")
	await UiInput.click(assign)
	var picks: Array[Button] = view.get_panel().room_buttons()
	assert_str(picks[0].text).is_equal("Research Lab (Level 1): 2/4 · speed 100% to 150%")
	await UiInput.click(picks[0])
	_free_ui()
	var lab: RoomState = PowerFixture.first_room(player.state(), LAB_DEF)
	assert_str(player.state().staff.find_person(person_id).room_id).is_equal(lab.id)
	assert_int(ResearchRules.speed_percent(player.state())).is_equal(150)


## The tech tree's Excavation survey node and Start begin the survey ($400k); at 150% its
## 2 days take 32 hours.
func _start_survey_from_the_tree(player: M15Player) -> void:
	var switcher: ViewSwitcher = _make_switcher(player)
	await UiInput.settle(switcher)
	await UiInput.key(switcher, KEY_F4)
	var view := switcher.get_view(&"research") as ResearchView
	await UiInput.click(view.get_board().get_tree_view().node_of(&"excavation_survey"))
	var start: Button = view.get_panel().get_button()
	assert_str(start.text).is_equal("Start")
	await UiInput.click(start)
	_free_ui()
	assert_str(String(player.state().research.active)).is_equal("excavation_survey")
	var done: Callable = func() -> bool:
		return player.state().research.is_done(&"excavation_survey")
	assert_int(_wait(player, done)).is_between(SURVEY_TICKS * 2 / 3, SURVEY_TICKS * 2 / 3 + 1)


## With the clock running to 1 February, every daily settlement arrives without a pause; SILL's
## lock (+5) and the project (+3) are causes, the salaries are six people's $175k per 30 days
## and Confidence is above 50.
func _settle_to_february(player: M15Player) -> void:
	var state: GameState = player.state()
	state.clock.is_paused = false
	player.simulation.pause_requested.connect(_on_pause_requested)
	var settlements: int = 31 - TimeMath.day_index(state.clock.tick)
	EventBus.budget_changed.connect(_on_budget_changed)
	var reached: Callable = func() -> bool: return state.clock.tick >= FEB_1_TICK
	_wait(player, reached)
	EventBus.budget_changed.disconnect(_on_budget_changed)
	assert_int(settlements).is_greater(10)
	assert_int(_reports.size()).is_equal(settlements)
	assert_int(_reports.back()["tick"]).is_equal(FEB_1_TICK)
	assert_bool(_reports.back()["paused"]).is_false()
	assert_int(_pause_requests).is_equal(0)
	var changes: Dictionary[StringName, int] = {}
	for cause: ConfidenceCause in state.committee.causes:
		changes[cause.cause] = cause.change
	assert_int(changes.get(ConfidenceRules.LOCKED, 0)).is_equal(ConfidenceRules.LOCK_CHANGE)
	assert_int(changes.get(ConfidenceRules.RESEARCH, 0)).is_equal(ConfidenceRules.RESEARCH_CHANGE)
	assert_int(StaffRules.headcount(state)).is_equal(6)
	assert_int(StaffRules.salaries_k(state)).is_equal(175)
	assert_int(state.committee.whole()).is_greater(50)


func _on_pause_requested(_reason: StringName) -> void:
	_pause_requests += 1


func _on_budget_changed(_funds_k: int) -> void:
	var clock: ClockState = _simulation.state.clock
	if TimeMath.is_day_start(clock.tick):
		_reports.append({"tick": clock.tick, "paused": clock.is_paused})


## A drag on the plan from [param from] to [param to] with the mouse, through the ghost's GUI
## entry (headless Godot picks no control under the pointer), as in test_corridor_paint.gd.
func _drag(base: BaseView, from: Vector2i, to: Vector2i) -> void:
	_mouse_move(base, from, 0)
	_mouse_button(base, true, from)
	await get_tree().process_frame
	var step: Vector2i = (to - from).sign()
	var cell: Vector2i = from
	while cell != to:
		cell += step
		_mouse_move(base, cell, MOUSE_BUTTON_MASK_LEFT)
	await get_tree().process_frame
	_mouse_button(base, false, to)
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


func _mouse_button(base: BaseView, pressed: bool, cell: Vector2i) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = _at(base, cell)
	base.get_build().get_ghost()._gui_input(event)


func _corridor_count(state: GameState) -> int:
	var count: int = 0
	for room: RoomState in state.base.rooms:
		if room.def_id == StartingBase.CORRIDOR_DEF:
			count += 1
	return count


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
