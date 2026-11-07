## Soak test: a seeded bot plays one full in-game year headless, driving
## Simulation.advance_tick() directly. One run is uninterrupted; the other saves at every
## month close, loads the save into a new Simulation and carries on with the loaded copy.
## Both must end with the same to_dict(), which catches any state to_dict() forgets.
## Both runs are built by GameSetup from the real data/ content, so PowerSystem and
## GateSystem tick all year (and are rebuilt with the galaxy after every load); stored power
## must stay within 0..capacity, and never NaN, and allocation within supply, on every tick.
## The bot builds the first Capacitor Bank and sets its charge rate, then dials directly all
## year: Address Book entries, random addresses and
## now and then a real world's true address; it reads each new far Ring's console when a
## wormhole opens, which fills the book, and closes the wormhole.
## Run with scripts/soak.sh; scripts/test.sh skips this folder.
## Bible: technical-architecture.md#testing-and-tooling (Soak test),
## technical-architecture.md#save-system, gate-and-address-spec.md#the-dial-console
extends GdUnitTestSuite

const SaveServiceScript := preload("res://src/services/save_service.gd")
const SoakBot := preload("res://tests/soak/soak_bot.gd")

## Base seed of both runs.
const SEED: int = 20260101
## Days in the soak year (2026 is not a leap year).
const YEAR_DAYS: int = 365
## Ticks in the soak year: 525,600.
const YEAR_TICKS: int = YEAR_DAYS * TimeMath.TICKS_PER_DAY
## Month closes expected in the year: January to December.
const YEAR_MONTHS: int = 12
## Slot the save-and-load run writes at every month close.
const SLOT: StringName = &"soak_month"
## Time budget of the whole test, in milliseconds: a ceiling for slow or shared machines, not
## a target. A normal run takes about 55 s (decision log, 2026-11-01).
const BUDGET_MSEC: int = 90000

var _service: SaveServiceScript
var _defs: GameDefs
var _uninterrupted: SoakRun
var _reloaded: SoakRun


## One play-through: the current Simulation, its bot and what the run observed.
class SoakRun:
	extends RefCounted

	## The simulation being played; replaced by the loaded copy after each reload.
	var simulation: Simulation
	## The run's bot; it carries on across reloads.
	var bot: SoakBot = SoakBot.new()
	## Number of day_started events seen.
	var days_started: int = 0
	## Every month boundary (a day_started on the 1st; the engine has no month hook), in order:
	## {year, month (the one that ended), tick}.
	var months_closed: Array[Dictionary] = []
	## Every command_rejected event: {type, code}.
	var rejections: Array[Dictionary] = []
	## Number of times play switched to a freshly loaded Simulation.
	var switches: int = 0
	## True from a month boundary until the run handles it after the tick.
	var month_close_pending: bool = false
	## Ticks after which stored power was below 0 or above the capacity.
	var power_out_of_bounds: int = 0
	## Month closes after which the budget was below 0 or above the start plus a year's top
	## daily allocations and commendations, or the Committee state left its bounds.
	var budget_out_of_bounds: int = 0

	## Starts a run on a new game seeded with [param base_seed], built by GameSetup from
	## [param defs].
	func _init(base_seed: int, defs: GameDefs) -> void:
		var built: Result = GameSetup.build_new(GameState.new_game(base_seed, defs.balance), defs)
		var first: Simulation = built.value
		attach(first)

	## Counts the tick just run when stored power was NaN or left 0..capacity.
	func check_power() -> void:
		var state: GameState = simulation.state
		var stored: float = state.power.stored_mwh
		var sums: PackedFloat64Array = PowerRules.totals(state)
		if is_nan(stored) or stored < 0.0 or stored > PowerRules.capacity_of(state, sums):
			power_out_of_bounds += 1
		elif sums[PowerRules.DRAW] + PowerRules.charge_mw_of(state, sums) > sums[0]:
			power_out_of_bounds += 1

	## Counts the month close just run when the budget left 0 .. start + a year of top daily
	## allocations and a commendation a month, Confidence left 0..1000, the cost carry left
	## 0..29 or the last recorded balance is not the day's (docs/content/m27-daily-rhythm.md
	## sections 1 and 2): the bot only spends what it has and the allocation out-runs the costs.
	func check_budget() -> void:
		var state: GameState = simulation.state
		var balance: BalanceConfig = state.balance
		var committee: CommitteeState = state.committee
		var top_k: int = ConfidenceRules.daily_allocation_k(balance.daily_allocation_k, 100)
		var most: int = (
			balance.starting_budget_k
			+ YEAR_DAYS * top_k
			+ YEAR_MONTHS * ConfidenceRules.COMMENDATION_K
		)
		var funds: int = state.budget.funds_k
		if funds < 0 or funds > most:
			budget_out_of_bounds += 1
		if committee.confidence < ConfidenceRules.MIN or committee.confidence > ConfidenceRules.MAX:
			budget_out_of_bounds += 1
		if committee.cost_carry < 0 or committee.cost_carry >= ConfidenceRules.PERIOD_DAYS:
			budget_out_of_bounds += 1
		if committee.funds_history.is_empty() or committee.funds_history.back() > funds:
			budget_out_of_bounds += 1

	## True when [param tick] is midnight on the 1st of a month.
	static func is_month_start(tick: int) -> bool:
		return TimeMath.is_day_start(tick) and TimeMath.date_of(tick)["day"] == 1

	## Makes [param next] the simulation this run plays and listens to its signals.
	func attach(next: Simulation) -> void:
		simulation = next
		simulation.day_started.connect(_on_day_started)
		simulation.command_rejected.connect(_on_command_rejected)

	func _on_day_started(_day_index: int) -> void:
		days_started += 1
		var tick: int = simulation.state.clock.tick
		if not is_month_start(tick):
			return
		var ended: Dictionary = TimeMath.date_of(tick - 1)
		months_closed.append({"year": ended["year"], "month": ended["month"], "tick": tick})
		month_close_pending = true

	func _on_command_rejected(type: StringName, code: StringName) -> void:
		rejections.append({"type": type, "code": code})


func before_test() -> void:
	_service = SaveServiceScript.new()
	_service.saves_dir = "user://soak_saves_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	_defs = GameDefs.from_registry(Registry)


func after_test() -> void:
	_remove_dir(_service.saves_dir)
	_service.free()


## Plays the year twice, once uninterrupted and once reloading at every month close, and
## checks both saw the expected events, stayed within budget and ended in the same state.
func test_year_with_monthly_save_and_load_matches_uninterrupted_run() -> void:
	var started_msec := Time.get_ticks_msec()
	await assert_error(_play_both_runs).is_success()
	var elapsed_msec := Time.get_ticks_msec() - started_msec
	print(_summary(elapsed_msec))
	var expected_days := _expected_day_starts()
	var expected_closes := _expected_month_closes()
	for run: SoakRun in [_uninterrupted, _reloaded]:
		_assert_run_events(run, expected_days, expected_closes)
	assert_int(_reloaded.switches).is_equal(YEAR_MONTHS)
	assert_dict(_reloaded.simulation.state.to_dict()).is_equal(
		_uninterrupted.simulation.state.to_dict()
	)
	assert_int(elapsed_msec).is_less(BUDGET_MSEC)


## Returns the one-line report printed after the runs: duration and what was observed.
func _summary(elapsed_msec: int) -> String:
	var template := "soak: %d ticks x 2 runs in %.2f s; %d day_started, %d month boundaries, "
	template += "%d reloads, %d commands (%d while paused), %d pauses; %d dials (%d locks), "
	template += "%d closes, %d consoles read, %d pole cameras, %d book entries; "
	template += "%d picked (%d from the book, %d targets, %d dropped); "
	template += "%d staff moves, %d assigns; Confidence %d, funds $%dk"
	var bot: SoakBot = _reloaded.bot
	var values: Array = [
		YEAR_TICKS,
		elapsed_msec / 1000.0,
		_reloaded.days_started,
		_reloaded.months_closed.size(),
		_reloaded.switches,
		bot.commands_submitted,
		bot.commands_while_paused,
		bot.pauses,
		bot.dials,
		_locks(_reloaded),
		bot.closes,
		bot.consoles_read,
		bot.cameras_extended,
		_reloaded.simulation.state.address_book.entries.size(),
		bot.addresses_picked,
		bot.book_picked,
		bot.targets_picked,
		bot.addresses_dropped,
		bot.staff_moves,
		bot.staff_assigns,
		_reloaded.simulation.state.committee.confidence,
		_reloaded.simulation.state.budget.funds_k,
	]
	return template % values


func _play_both_runs() -> void:
	_uninterrupted = SoakRun.new(SEED, _defs)
	_play(_uninterrupted, false)
	_reloaded = SoakRun.new(SEED, _defs)
	_play(_reloaded, true)


## Plays [param run] to the end of the year. Ticks advance only while the clock runs; while
## it is paused the bot keeps acting until it resumes. With [param reload_each_month], every
## month close saves, loads into a new Simulation and continues on that copy.
func _play(run: SoakRun, reload_each_month: bool) -> void:
	var bot: SoakBot = run.bot
	while run.simulation.state.clock.tick < YEAR_TICKS:
		bot.act(run.simulation)
		if run.simulation.state.clock.is_paused:
			continue
		run.simulation.advance_tick()
		run.check_power()
		if not run.month_close_pending:
			continue
		run.month_close_pending = false
		run.check_budget()
		if reload_each_month:
			_reload(run)


## Saves the run's state, loads it into a new Simulation and switches the run to it, then
## checks the run now drives the loaded copy rather than the original.
func _reload(run: SoakRun) -> void:
	var before: Dictionary = run.simulation.state.to_dict()
	var saved: Result = _service.save_game(run.simulation.state, SLOT)
	assert_bool(saved.is_ok).override_failure_message(str(saved.error_code)).is_true()
	var loaded: Result = _service.load_game(SLOT, _defs)
	assert_bool(loaded.is_ok).override_failure_message(str(loaded.error_code)).is_true()
	var original: Simulation = run.simulation
	var loaded_state: GameState = loaded.value
	assert_bool(loaded_state == run.simulation.state).is_false()
	var built: Result = GameSetup.build(loaded_state, _defs)
	assert_bool(built.is_ok).override_failure_message(str(built.error_code)).is_true()
	var copy: Simulation = built.value
	assert_dict(copy.state.to_dict()).is_equal(before)
	run.attach(copy)
	assert_object(run.simulation).is_same(copy)
	assert_object(run.simulation).is_not_same(original)
	run.switches += 1


## Checks [param run] saw the day starts and month closes TimeMath predicts, no rejected
## commands, and only bool, int or String flag values.
func _assert_run_events(
	run: SoakRun, expected_days: int, expected_closes: Array[Dictionary]
) -> void:
	assert_int(run.days_started).is_equal(YEAR_DAYS)
	assert_int(run.days_started).is_equal(expected_days)
	assert_int(run.months_closed.size()).is_equal(YEAR_MONTHS)
	assert_array(run.months_closed).is_equal(expected_closes)
	assert_array(run.rejections).is_empty()
	assert_int(run.simulation.state.clock.tick).is_equal(YEAR_TICKS)
	assert_int(run.power_out_of_bounds).is_equal(0)
	var state: GameState = run.simulation.state
	var capacity: float = PowerRules.capacity_mwh(state)
	assert_float(state.power.stored_mwh).is_between(0.0, capacity)
	assert_float(capacity).is_equal(_defs.balance.capacitor_bank_capacity_mwh)
	assert_int(state.power.charge_rates.size()).is_equal(1)
	assert_int(run.bot.installs).is_equal(1)
	assert_int(run.bot.charge_sets).is_equal(1)
	_assert_run_base(run)
	_assert_run_ring(run)
	var commands: int = run.bot.commands_submitted
	assert_int(commands).is_between(15 * YEAR_DAYS, 25 * YEAR_DAYS)
	assert_int(run.bot.commands_while_paused).is_greater(0)
	assert_int(run.bot.pauses).is_greater(0)
	assert_bool(run.simulation.state.flags.is_empty()).is_false()
	for key: StringName in run.simulation.state.flags:
		var value: Variant = run.simulation.state.flags[key]
		(
			assert_bool(value is bool or value is int or value is String)
			. override_failure_message("flag %s is a %s" % [key, type_string(typeof(value))])
			. is_true()
		)


## Checks [param run] worked the Ring all year: it dialed, locked (a true target address, at
## least), read consoles, dialed from the Address Book, closed, and the Dial Log holds every
## dial; every world with a status is named by the Address Book entry that locked it, and every
## console the bot read is marked read.
func _assert_run_ring(run: SoakRun) -> void:
	var state: GameState = run.simulation.state
	var bot: SoakBot = run.bot
	assert_int(bot.dials).is_greater(YEAR_DAYS)
	assert_int(state.gate.dial_log.size()).is_between(bot.dials - 1, bot.dials)
	assert_int(bot.targets_picked).is_greater(0)
	assert_int(_locks(run)).is_greater(0)
	assert_int(bot.closes).is_greater(0)
	assert_int(bot.consoles_read).is_greater(0)
	assert_int(state.worlds.consoles_read.size()).is_equal(bot.consoles_read)
	assert_int(state.worlds.horizon_records.size()).is_between(1, bot.cameras_extended)
	assert_int(bot.book_picked).is_greater(0)
	var named: Array[StringName] = []
	for entry: AddressEntry in state.address_book.entries:
		named.append(entry.world_id)
	for world_id: StringName in state.worlds.statuses:
		assert_bool(named.has(world_id)).override_failure_message(world_id).is_true()


## Checks [param run] built the corridor run and the lab, switched the lab on, researched R1-R6
## and dug every extra level, and the budget stayed in bounds at every month close.
func _assert_run_base(run: SoakRun) -> void:
	var state: GameState = run.simulation.state
	assert_int(run.budget_out_of_bounds).is_equal(0)
	assert_int(run.bot.builds).is_equal(2)
	assert_int(run.bot.digs).is_equal(_defs.balance.dig_level_costs_k.size())
	assert_int(state.base.level_count).is_equal(
		_defs.balance.starting_levels + _defs.balance.dig_level_costs_k.size()
	)
	assert_int(state.base.digging_level()).is_equal(0)
	var lab: RoomState = PowerFixture.first_room(state, SoakBot.LAB_DEF)
	assert_object(lab).is_not_null()
	assert_bool(lab.is_built()).is_true()
	assert_bool(lab.powered_on).is_true()
	assert_int(run.bot.research_started).is_equal(SoakResearch.ORDER.size())
	assert_int(run.bot.staff_moves).is_greater(1)
	assert_int(run.bot.staff_assigns).is_greater(0)
	assert_array(state.research.done).is_equal(SoakResearch.ORDER)
	assert_bool(state.research.is_running()).is_false()
	assert_int(state.unlocks.dig_depth).is_equal(4)


## Locks and hostile locks in [param run]'s Dial Log.
func _locks(run: SoakRun) -> int:
	var count: int = 0
	for entry: DialLogEntry in run.simulation.state.gate.dial_log:
		if DialOutcome.is_lock(entry.outcome):
			count += 1
	return count


## Counts the ticks in 1..YEAR_TICKS that TimeMath says start a day.
func _expected_day_starts() -> int:
	var count := 0
	for tick: int in range(1, YEAR_TICKS + 1):
		if TimeMath.is_day_start(tick):
			count += 1
	return count


## Lists the month closes TimeMath implies for ticks 1..YEAR_TICKS: {year, month, tick}.
func _expected_month_closes() -> Array[Dictionary]:
	var closes: Array[Dictionary] = []
	for day: int in range(1, YEAR_DAYS + 1):
		var tick: int = day * TimeMath.TICKS_PER_DAY
		if not SoakRun.is_month_start(tick):
			continue
		var ended: Dictionary = TimeMath.date_of(tick - 1)
		closes.append({"year": ended["year"], "month": ended["month"], "tick": tick})
	return closes


func _remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
