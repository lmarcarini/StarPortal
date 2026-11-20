extends RefCounted
## Seeded stand-in player for the soak test. It sets random flags (SetFlagCommand) about 20 times a
## day, pauses and resumes at random, and adds and releases system holds (TimeControl), a dozen or
## so a month. First it builds the first Capacitor Bank on the nearest valid spot to the Gate Room,
## waits for it, then gives it all the spare supply as its charge rate once. It then works the Ring
## on every call with no command waiting: with the Ring idle and no address picked it picks one (a
## console's Address Book entry the bank can power sometimes, a real world's true address now and
## then, a missing team's world first, otherwise a random well-formed one whose seal 1 the bank can
## reach) and dials it once charged (one it can never charge is dropped). On a lock it reads an
## unread console, extends the pole camera for a record not taken, works the probes (SoakProbes) and
## expeditions (SoakExpeditions), then closes the wormhole. Once the bank charges it builds a
## corridor off the Level 1 spine and a Research Lab, lowers the bank's charge rate by just enough
## to switch the lab on, researches R1-R6 in list order as each may start, and digs each extra level
## as research and money allow, one at a time. Every random draw comes from the run's own GameState
## stream &"soak_bot", so two runs from the same seed act identically, and a saved and reloaded
## state carries the stream on. The picked address is the bot's own, not game state: it carries on
## across reloads with the bot.
## Bible: technical-architecture.md#testing-and-tooling (Soak test),
## gate-and-address-spec.md#where-addresses-come-from (Ring consoles)

## RandomState stream the bot draws from.
const STREAM_ID: StringName = &"soak_bot"
## Largest gap between two actions while running, in ticks. Gaps are uniform in
## 1..MAX_ACTION_GAP, a mean of 72 ticks: about 20 actions per 1440-tick day.
const MAX_ACTION_GAP: int = 143
## Chance that a running action pauses the clock instead of submitting a command.
const PAUSE_CHANCE: float = 0.1
## Chance, per paused action, that the bot resumes; otherwise it submits a command.
const RESUME_CHANCE: float = 0.4
## Chances that a running action adds a hold instead of submitting a command, and, per paused
## (not held) action, that the bot adds a hold (checked after resume).
const HOLD_CHANCE: float = 0.02
const PAUSED_HOLD_CHANCE: float = 0.05
## Chances, per held action, that the bot releases a hold, adds another one, or makes a player
## pause/resume request (which only sets the mode after the hold); otherwise it submits a command.
const RELEASE_CHANCE: float = 0.4
const EXTRA_HOLD_CHANCE: float = 0.1
const HELD_REQUEST_CHANCE: float = 0.15
const HOLD_REASONS: Array[StringName] = [&"soak_hold_a", &"soak_hold_b", &"soak_hold_c"]
## Number of distinct flag keys (soak_flag_0 to soak_flag_<n - 1>); hold reasons above.
const FLAG_KEY_COUNT: int = 16
## Largest magnitude of a random int flag value.
const MAX_INT_VALUE: int = 1000000
## Chance that a newly picked address is an Address Book entry the bank can power (when the
## book holds one).
const BOOK_CHANCE: float = 0.3
## Chance that a newly picked address is a real world's true address.
const TARGET_CHANCE: float = 0.1
## The corridor run and the Workshop (the Engineering bench, M7) the bot builds on Level 1.
const LAB_LEVEL: int = 1
const LAB_CORRIDOR: Array[Vector2i] = [
	Vector2i(24, 9), Vector2i(24, 8), Vector2i(24, 7), Vector2i(24, 6), Vector2i(24, 5)
]
const LAB_DEF: StringName = &"room_workshop"
const LAB_ORIGIN: Vector2i = Vector2i(25, 5)
## Ticks an open wormhole stays open before the bot closes it.
const CLOSE_AFTER_TICKS: int = 5

## Commands submitted so far, running and paused.
var commands_submitted: int = 0
## Commands submitted while the clock was paused (they apply at once).
var commands_while_paused: int = 0
## Times the bot paused and resumed the clock.
var pauses: int = 0
var resumes: int = 0
## Holds the bot added (duplicates, which are no-ops, not counted) and released.
var holds_added: int = 0
var holds_released: int = 0
## Addresses the bot picked; of them Address Book entries and real worlds' addresses; and
## those it dropped unreachable.
var addresses_picked: int = 0
var book_picked: int = 0
var targets_picked: int = 0
var addresses_dropped: int = 0
## Every world whose true address the bot picked, in pick order, without repeats.
var targets: Array[StringName] = []
## Dials the bot started.
var dials: int = 0
## Wormholes the bot closed.
var closes: int = 0
## Far Ring consoles the bot read.
var consoles_read: int = 0
## Times the bot extended the pole camera.
var cameras_extended: int = 0
## Capacitor Bank builds the bot started.
var installs: int = 0
## Charge rates the bot set.
var charge_sets: int = 0
## Base builds the bot started (corridor runs and rooms), and digs.
var builds: int = 0
var digs: int = 0
## Commands the bot sent to get the lab on (charge lowered, lab switched on), and research
## projects it started.
var lab_steps: int = 0
var research_started: int = 0
## Hires and dismissals, assignments (SoakStaff) and defence moves (SoakSecurity) sent.
var staff_moves: int = 0
var staff_assigns: int = 0
var security_moves: int = 0
## Teams sent and rescues worked (SoakExpeditions; it also dials a missing team's world).
var expeditions := SoakExpeditions.new()

var _next_action_tick: int = 0
## The address the bot will dial next, or null.
var _picked: GateAddress = null
## Clock tick before which the picked address cannot be charged yet: the bot skips asking
## until then (with the Ring idle only an open wormhole drains the capacitors).
var _check_at_tick: int = 0


## Acts once on [param simulation] before its next tick: while running, on its action tick
## it commands, pauses or holds; while paused or held, every call is an action.
func act(simulation: Simulation) -> void:
	var clock: ClockState = simulation.state.clock
	var rng: RandomNumberGenerator = simulation.state.random.stream(STREAM_ID)
	if simulation.commands.pending_count() == 0:
		_work_ring(simulation, rng)
	if simulation.commands.pending_count() == 0 and charge_sets > 0:
		_work_base(simulation)
	if simulation.commands.pending_count() == 0 and SoakStaff.work(simulation):
		staff_moves += 1
	staff_assigns += int(simulation.commands.pending_count() == 0 and SoakStaff.assign(simulation))
	SoakStory.work(simulation)
	security_moves += int(SoakSecurity.work(simulation, rng))
	if not clock.is_paused and clock.tick < _next_action_tick:
		return
	if clock.mode == ClockState.Mode.HELD:
		_act_held(simulation, rng)
		return
	if clock.is_paused:
		_act_paused(simulation, rng)
		return
	_next_action_tick = clock.tick + rng.randi_range(1, MAX_ACTION_GAP)
	var roll: float = rng.randf()
	if roll < PAUSE_CHANCE:
		clock.is_paused = true
		pauses += 1
		return
	if roll < PAUSE_CHANCE + HOLD_CHANCE:
		_add_random_hold(clock, rng)
		return
	_submit_random_flag(simulation, rng)


## Builds the first Capacitor Bank and waits for it, then sets its charge rate; then, on a
## lock, works the wormhole; with the Ring idle, picks, drops or dials.
func _work_ring(simulation: Simulation, rng: RandomNumberGenerator) -> void:
	var state: GameState = simulation.state
	if state.power.charge_rates.is_empty():
		if installs == 0:
			simulation.submit(PowerFixture.build_first_bank(state))
			installs += 1
		return
	var starved: bool = state.power.charge_rates.values().max() == 0
	if charge_sets == 0 or (starved and PowerRules.spare_mw(state) >= 1.0):
		_set_full_charge(simulation)
		return
	var gate: GateState = state.gate
	if gate.mode == GateState.RingMode.LOCKED:
		_work_wormhole(simulation, rng)
		return
	if gate.mode != GateState.RingMode.IDLE or gate.has_incoming() or state.incursion.is_active():
		return
	if _picked == null:
		_pick_address(state, rng)
		return
	if state.clock.tick < _check_at_tick:
		return
	var ready_in: int = GateQueries.ticks_until_ready(state, _picked)
	_check_at_tick = state.clock.tick + maxi(ready_in - 1, 0)
	if ready_in < 0:
		_picked = null
		addresses_dropped += 1
	elif ready_in == 0:
		simulation.submit(DialCommand.create(_picked))
		_picked = null
		dials += 1


## On an open wormhole: operates or stands by (SoakGateOps); reads the console, extends the
## camera for a new record, else closes after CLOSE_AFTER_TICKS.
func _work_wormhole(simulation: Simulation, rng: RandomNumberGenerator) -> void:
	SoakGateOps.work(simulation, rng)
	var state: GameState = simulation.state
	var gate: GateState = state.gate
	var worlds: WorldsState = state.worlds
	if not worlds.is_console_read(gate.connected_world_id):
		simulation.submit(ReadConsoleCommand.new())
		consoles_read += 1
	elif worlds.is_pole_camera_out():
		return
	elif not worlds.is_horizon_record_taken(gate.connected_world_id):
		simulation.submit(ExtendPoleCameraCommand.new())
		cameras_extended += 1
	elif SoakProbes.work(simulation) or expeditions.work(simulation):
		return
	elif state.clock.tick - gate.lock_started_tick >= CLOSE_AFTER_TICKS:
		if state.conversations.active == null:
			simulation.submit(CloseWormholeCommand.new())
			closes += 1


func _pick_address(state: GameState, rng: RandomNumberGenerator) -> void:
	_picked = SoakExpeditions.rescue_address(state)
	if _picked != null:
		return
	var origin: int = state.galaxy.home().origin_glyph
	var first_glyphs: Array[int] = _reachable_first_glyphs(state)
	var roll: float = rng.randf()
	var book: Array[AddressEntry] = _reachable_book_entries(state, first_glyphs)
	if roll < BOOK_CHANCE and not book.is_empty():
		var entry: AddressEntry = book[rng.randi_range(0, book.size() - 1)]
		_picked = _address_from_key(entry.address_key)
		book_picked += 1
	elif roll < BOOK_CHANCE + TARGET_CHANCE:
		var worlds: Array[StringName] = _reachable_worlds(state, first_glyphs)
		var target: StringName = worlds[rng.randi_range(0, worlds.size() - 1)]
		_picked = state.galaxy.address_of(target, origin)
		targets_picked += 1
		if not targets.has(target):
			targets.append(target)
	else:
		_picked = random_address(rng, origin, first_glyphs)
	addresses_picked += 1


## The Address Book's console entries, in book order, whose seal 1 is one of
## [param first_glyphs] and whose seal 8 is CAIRN's origin: what a player could dial from the
## book with this bank. Entries the bot dialed itself are left out: the book keeps every dial,
## so they would crowd out what the consoles found.
static func _reachable_book_entries(
	state: GameState, first_glyphs: Array[int]
) -> Array[AddressEntry]:
	var origin: int = state.galaxy.home().origin_glyph
	var found: Array[AddressEntry] = []
	for entry: AddressEntry in state.address_book.entries:
		if entry.source != AddressEntry.Source.CONSOLE:
			continue
		var address: GateAddress = _address_from_key(entry.address_key)
		if address.origin == origin and first_glyphs.has(address.coordinates[0]):
			found.append(entry)
	return found


## The GateAddress whose key() is [param key].
static func _address_from_key(key: String) -> GateAddress:
	var seals: Array[int] = []
	for part: String in key.split("-"):
		seals.append(int(part))
	var origin: int = seals.pop_back()
	return GateAddress.create(seals, origin)


## Worlds other than CAIRN whose true address starts with one of [param first_glyphs], in
## catalogue order. The bot cheats on purpose: it plays the soak, not the puzzle.
static func _reachable_worlds(state: GameState, first_glyphs: Array[int]) -> Array[StringName]:
	var home: WorldRecord = state.galaxy.home()
	var found: Array[StringName] = []
	for world: WorldRecord in state.galaxy.all_worlds():
		if world.id == home.id:
			continue
		var address: GateAddress = state.galaxy.address_of(world.id, home.origin_glyph)
		if first_glyphs.has(address.coordinates[0]):
			found.append(world.id)
	return found


## Glyphs other than the home origin whose anchor, as seal 1, needs no more lock energy than
## the bank can hold. Lock energy depends on seal 1 only.
static func _reachable_first_glyphs(state: GameState) -> Array[int]:
	var capacity: float = PowerRules.capacity_mwh(state)
	var origin: int = state.galaxy.home().origin_glyph
	var others: Array[int] = []
	for glyph: int in GateAddress.GLYPH_COUNT:
		if glyph != origin:
			others.append(glyph)
	var reachable: Array[int] = []
	for glyph: int in others:
		var coordinates: Array[int] = [glyph]
		for other: int in others:
			if other != glyph and coordinates.size() < GateAddress.COORDINATE_COUNT:
				coordinates.append(other)
		var probe := GateAddress.create(coordinates, origin)
		if GateQueries.lock_energy_mwh(state, probe) <= capacity:
			reachable.append(glyph)
	return reachable


## A random well-formed address: seven distinct glyphs other than [param origin], then it.
## Seal 1 is drawn from [param first_glyphs] when that is not empty.
static func random_address(
	rng: RandomNumberGenerator, origin: int, first_glyphs: Array[int]
) -> GateAddress:
	var glyphs: Array[int] = []
	for glyph: int in GateAddress.GLYPH_COUNT:
		if glyph != origin:
			glyphs.append(glyph)
	var coordinates: Array[int] = []
	if not first_glyphs.is_empty():
		var first: int = first_glyphs[rng.randi_range(0, first_glyphs.size() - 1)]
		coordinates.append(first)
		glyphs.erase(first)
	while coordinates.size() < GateAddress.COORDINATE_COUNT:
		coordinates.append(glyphs.pop_at(rng.randi_range(0, glyphs.size() - 1)))
	return GateAddress.create(coordinates, origin)


func _act_paused(simulation: Simulation, rng: RandomNumberGenerator) -> void:
	var roll: float = rng.randf()
	if roll < RESUME_CHANCE:
		simulation.state.clock.is_paused = false
		resumes += 1
		return
	if roll < RESUME_CHANCE + PAUSED_HOLD_CHANCE:
		_add_random_hold(simulation.state.clock, rng)
		return
	_submit_random_flag(simulation, rng)
	commands_while_paused += 1


func _act_held(simulation: Simulation, rng: RandomNumberGenerator) -> void:
	var clock: ClockState = simulation.state.clock
	var roll: float = rng.randf()
	if roll < RELEASE_CHANCE:
		var reason: StringName = clock.holds[rng.randi_range(0, clock.holds.size() - 1)]
		if TimeControl.release_hold(clock, reason):
			holds_released += 1
		return
	if roll < RELEASE_CHANCE + EXTRA_HOLD_CHANCE:
		_add_random_hold(clock, rng)
		return
	if roll < RELEASE_CHANCE + EXTRA_HOLD_CHANCE + HELD_REQUEST_CHANCE:
		clock.is_paused = rng.randf() < 0.5
		return
	_submit_random_flag(simulation, rng)
	commands_while_paused += 1


func _add_random_hold(clock: ClockState, rng: RandomNumberGenerator) -> void:
	var reason: StringName = HOLD_REASONS[rng.randi_range(0, HOLD_REASONS.size() - 1)]
	if TimeControl.add_hold(clock, reason):
		holds_added += 1


func _submit_random_flag(simulation: Simulation, rng: RandomNumberGenerator) -> void:
	var key := StringName("soak_flag_%d" % rng.randi_range(0, FLAG_KEY_COUNT - 1))
	simulation.submit(SetFlagCommand.create(key, _random_value(rng)))
	commands_submitted += 1


## Returns a random bool, int or String flag value.
func _random_value(rng: RandomNumberGenerator) -> Variant:
	match rng.randi_range(0, 2):
		0:
			return rng.randf() < 0.5
		1:
			return rng.randi_range(-MAX_INT_VALUE, MAX_INT_VALUE)
		_:
			return "value_%d" % rng.randi()


## Builds the corridor run, then the lab against it once the run's site stands; then gets the
## lab on, starts the next project and digs the next level whenever allowed and affordable.
## Sends at most one command per call and never a refused one.
func _work_base(simulation: Simulation) -> void:
	var state: GameState = simulation.state
	var next: Command = null
	if builds == 0:
		var run: Array[Vector2i] = LAB_CORRIDOR.duplicate()
		next = PaintCorridorCommand.create(LAB_LEVEL, run)
	elif builds == 1:
		next = PlaceRoomCommand.create(LAB_DEF, LAB_LEVEL, LAB_ORIGIN)
	if next != null:
		if next.validate(state).is_ok:
			simulation.submit(next)
			builds += 1
		return
	if SoakResearch.work_lab(simulation, LAB_DEF):
		lab_steps += 1
		return
	if SoakResearch.work_research(simulation, SoakResearch.ORDER):
		research_started += 1
		return
	if state.base.digging_level() != 0 or digs >= state.balance.dig_level_costs_k.size():
		return
	next = DigLevelCommand.new()
	if next.validate(state).is_ok:
		simulation.submit(next)
		digs += 1


## Gives the first bank all the spare supply, up to its maximum, as its charge rate.
func _set_full_charge(simulation: Simulation) -> void:
	var state: GameState = simulation.state
	var bank: StringName = state.power.charge_rates.keys()[0]
	var def: RoomDef = state.room_defs[StartingBase.CAPACITOR_BANK_DEF]
	var rate: int = state.power.charge_rates[bank] + floori(PowerRules.spare_mw(state))
	rate = mini(rate, floori(def.max_charge_rate_mw))
	simulation.submit(SetChargeRateCommand.create(bank, rate))
	charge_sets += 1
