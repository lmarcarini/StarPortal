extends RefCounted
## Scripted M1.5 player for the flow test: drives a Simulation built by GameSetup.build_new()
## the way the Gate Room does, one command at a time with the clock paused (a command then
## applies at once) and ticks run by hand. It knows the approved answers of the four puzzles
## (docs/content/m15-puzzles.md) and nothing else about the galaxy; it learns console
## addresses only from the Address Book. After each lock it extends the pole camera for the
## world's horizon record.
## Bible: roadmap.md (M1.5 check), technical-architecture.md#testing-and-tooling

## The four puzzles in play order: world id, seals 1 to 7 of the approved answer, and the
## documents its horizon record delivers (the next puzzle's documents and the world's dossier).
const PUZZLES: Array[Dictionary] = [
	{
		"world": &"world_sill",
		"glyphs": [35, 24, 29, 10, 19, 22, 8],
		"delivers": [&"doc_lintel_note", &"doc_lintel_rubbing", &"doc_sill_dossier"],
	},
	{
		"world": &"world_lintel",
		"glyphs": [35, 19, 10, 15, 5, 6, 4],
		"delivers":
		[
			&"doc_lintel_dossier",
			&"doc_milestone_frame_1",
			&"doc_milestone_frame_2",
			&"doc_milestone_letter",
			&"doc_milestone_record",
		],
	},
	{
		"world": &"world_milestone",
		"glyphs": [35, 22, 19, 3, 24, 29, 34],
		"delivers": [&"doc_milestone_dossier", &"doc_stillwater_note", &"doc_stillwater_song"],
	},
	{
		"world": &"world_stillwater",
		"glyphs": [35, 10, 24, 19, 29, 8, 15],
		"delivers": [&"doc_stillwater_dossier"],
	},
]
## The documents of a new game, in id order.
const START_DOCUMENTS: Array[StringName] = [&"doc_sill_order", &"doc_sill_sketch"]
## Most ticks the player waits for anything (an install, a charge, a dial) before giving up.
const MAX_WAIT_TICKS: int = 5000

## The simulation being played.
var simulation: Simulation
## Every command_rejected seen: {type, code}.
var rejections: Array[Dictionary] = []
## Ticks the player ran by hand.
var ticks_run: int = 0


## Plays [param played], which must be paused.
func _init(played: Simulation) -> void:
	simulation = played
	simulation.command_rejected.connect(
		func(type: StringName, code: StringName) -> void:
			rejections.append({"type": type, "code": code})
	)


## The game state.
func state() -> GameState:
	return simulation.state


## Returns CAIRN's address with seals 1 to 7 [param glyphs].
func address(glyphs: Array) -> GateAddress:
	var coordinates: Array[int] = []
	coordinates.assign(glyphs)
	return GateAddress.create(coordinates, state().galaxy.home().origin_glyph)


## Runs one tick.
func step() -> void:
	simulation.advance_tick()
	ticks_run += 1


## Installs the capacitor bank and runs the clock until it is in; returns the ticks it took,
## or -1 when the install was refused or never finished.
func install_bank() -> int:
	if not simulation.submit(InstallCapacitorsCommand.new()).is_ok:
		return -1
	var started: int = state().clock.tick
	while state().power.banks_installed == 0:
		if state().clock.tick - started > MAX_WAIT_TICKS:
			return -1
		step()
	return state().clock.tick - started


## Runs the clock until the bank holds [param target]'s lock energy; false when it never does.
func wait_for_charge(target: GateAddress) -> bool:
	var waited: int = 0
	while GateQueries.ticks_until_ready(state(), target) != 0:
		if GateQueries.ticks_until_ready(state(), target) < 0 or waited > MAX_WAIT_TICKS:
			return false
		step()
		waited += 1
	return true


## Dials [param target] and runs the clock until the dial resolves; returns the newest Dial Log
## entry, or null when the dial was refused or never resolved.
func dial(target: GateAddress) -> DialLogEntry:
	if not simulation.submit(DialCommand.create(target)).is_ok:
		return null
	var waited: int = 0
	while state().gate.mode == GateState.RingMode.DIALING:
		if waited > MAX_WAIT_TICKS:
			return null
		step()
		waited += 1
	return state().gate.dial_log.back()


## Reads the open wormhole's console; returns the Address Book entries it added, newest
## first, or an empty array when refused.
func read_console() -> Array[AddressEntry]:
	var before: int = state().address_book.entries.size()
	var added: Array[AddressEntry] = []
	if not simulation.submit(ReadConsoleCommand.new()).is_ok:
		return added
	var after: int = state().address_book.entries.size()
	added.assign(state().address_book.entries.slice(0, after - before))
	return added


## Extends the pole camera through the open wormhole and runs the clock until it takes the
## horizon record; returns the documents that arrived, in arrival order, or an empty array when
## refused or the camera came back with nothing.
func extend_pole_camera() -> Array[StringName]:
	var arrived: Array[StringName] = []
	var before: int = state().archive.received.size()
	if not simulation.submit(ExtendPoleCameraCommand.new()).is_ok:
		return arrived
	while state().worlds.is_pole_camera_out():
		step()
	arrived.assign(state().archive.received.slice(before))
	return arrived


## Closes the open wormhole; false when refused.
func close_wormhole() -> bool:
	return simulation.submit(CloseWormholeCommand.new()).is_ok


## The Address Book's console entries the bank can ever power and whose world is still unknown,
## oldest first: what a player would try next. Reads only the book and the charge rule.
func reachable_console_entries() -> Array[AddressEntry]:
	var found: Array[AddressEntry] = []
	for entry: AddressEntry in state().address_book.entries:
		if entry.source != AddressEntry.Source.CONSOLE or entry.last_outcome >= 0:
			continue
		var target: GateAddress = parse_key(entry.address_key)
		if GateQueries.lock_energy_mwh(state(), target) <= state().power.capacity_mwh:
			found.push_front(entry)
	return found


## Returns the GateAddress whose key() is [param key], e.g. "35-24-29-10-19-22-8-2".
static func parse_key(key: String) -> GateAddress:
	var seals: Array[int] = []
	for part: String in key.split("-"):
		seals.append(int(part))
	var origin: int = seals.pop_back()
	return GateAddress.create(seals, origin)
