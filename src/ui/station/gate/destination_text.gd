class_name DestinationText
extends RefCounted
## Pure rules for the destination rack: a card's address, name and status icons from an
## Address Book entry, the rack's order (pinned, then a world with a team on it, then the most
## recently dialled) and its filters.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Destinations)

## Rack filters, cycled by the filter key.
enum Filter { ALL, TEAM, UNVISITED }


## The address [param entry] holds.
static func address_of(entry: AddressEntry) -> GateAddress:
	var seals: Array[int] = AddressEntry.glyphs_of(entry.address_key)
	return GateAddress.create(seals.slice(0, seals.size() - 1), seals[seals.size() - 1])


## The card's name: the world's name once reached, else "" (the card shows the glyphs).
static func title_of(entry: AddressEntry, state: GameState) -> String:
	return AddressBookText.world_text(entry, state)


## Status icons for [param entry] (HardwareIcons ids), most telling first.
static func icons_of(entry: AddressEntry, state: GameState) -> Array[StringName]:
	var icons: Array[StringName] = []
	if has_team(entry, state):
		icons.append(&"team")
	if entry.last_outcome == DialOutcome.Kind.HOSTILE_LOCK:
		icons.append(&"threat")
	if entry.world_id.is_empty():
		return icons
	var status: WorldsState.WorldStatus = state.worlds.status_of(entry.world_id)
	if status >= WorldsState.WorldStatus.CONTACTED:
		icons.append(&"people")
	if status >= WorldsState.WorldStatus.SURVEYED:
		icons.append(&"surveyed")
	if status >= WorldsState.WorldStatus.PROBED:
		icons.append(&"probed")
	if status == WorldsState.WorldStatus.LOCKED:
		icons.append(&"gate")
	return icons


## True when a team is out on [param entry]'s world.
static func has_team(entry: AddressEntry, state: GameState) -> bool:
	var trip: ExpeditionState = state.expedition
	return not entry.world_id.is_empty() and trip.is_out() and trip.world_id == entry.world_id


## The entries to show under [param filter], in rack order; [param pins] holds pinned keys.
static func ordered(
	state: GameState, pins: Dictionary[String, bool], filter: Filter
) -> Array[AddressEntry]:
	var shown: Array[AddressEntry] = []
	for entry: AddressEntry in state.address_book.entries:
		if _passes(entry, state, filter):
			shown.append(entry)
	shown.sort_custom(
		func(a: AddressEntry, b: AddressEntry) -> bool: return _before(a, b, state, pins)
	)
	return shown


static func _before(
	a: AddressEntry, b: AddressEntry, state: GameState, pins: Dictionary[String, bool]
) -> bool:
	var ra: float = _rank(a, state, pins)
	var rb: float = _rank(b, state, pins)
	if ra != rb:
		return ra > rb
	return a.address_key < b.address_key


static func _passes(entry: AddressEntry, state: GameState, filter: Filter) -> bool:
	match filter:
		Filter.TEAM:
			return has_team(entry, state)
		Filter.UNVISITED:
			return entry.last_dialed_tick < 0 or entry.world_id.is_empty()
	return true


## Sort key: pinned, then team there, then last dialled tick (never dialled last).
static func _rank(entry: AddressEntry, state: GameState, pins: Dictionary[String, bool]) -> float:
	var rank: float = float(entry.last_dialed_tick + 1)
	if has_team(entry, state):
		rank += 1.0e12
	if pins.get(entry.address_key, false):
		rank += 1.0e14
	return rank
