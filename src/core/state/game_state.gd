class_name GameState
extends RefCounted
## Root of all runtime state; the only thing saved. Sub-states are plain RefCounted
## classes that convert to and from JSON-safe dictionaries.
## Bible: technical-architecture.md#data-model

## Saved sections, in to_dict() order.
const _SECTIONS: Array[String] = [
	"clock",
	"random",
	"flags",
	"gate",
	"power",
	"base",
	"worlds",
	"archive",
	"address_book",
	"operations_log"
]

## The simulation clock.
var clock: ClockState = ClockState.new()
## Seeds and stream states for every random generator.
var random: RandomState = RandomState.new()
## Story and progress flags: StringName -> bool | int | String.
var flags: Dictionary = {}
## The Ring: mode, current dial and Dial Log.
var gate: GateState = GateState.new()
## Stored energy, capacity and plant output.
var power: PowerState = PowerState.new()
## Levels and rooms of the base.
var base: BaseState = BaseState.new()
## Galaxy seed, generator version and world statuses.
var worlds: WorldsState = WorldsState.new()
## Documents the player holds and has read.
var archive: ArchiveState = ArchiveState.new()
## Every address found or dialed.
var address_book: AddressBookState = AddressBookState.new()
## The operations log: what happened, oldest first.
var operations_log: LogState = LogState.new()
## Domain events waiting for the end of the tick. Transient: not in to_dict(), and
## new_game() and from_dict() start with an empty outbox.
var events: EventOutbox = EventOutbox.new()
## Tunable numbers, read only. Transient: not in to_dict(); GameSetup.build() sets it.
var balance: BalanceConfig = null
## The generated galaxy, read only. Transient: not in to_dict(); GameSetup.build() sets it
## from the saved galaxy seed and generator version.
var galaxy: GalaxyCatalogue = null


## Returns a fresh campaign state seeded with [param base_seed]. The galaxy seed is
## RandomState.derive_seed(base_seed, &"galaxy") and the generator version is
## WorldGenerator.GENERATOR_VERSION. With a [param balance], power starts at
## PowerState.starting(balance); without one it is all zero. The base is StartingBase.build()
## over [param balance], or over the BalanceConfig defaults without one.
static func new_game(base_seed: int, balance: BalanceConfig = null) -> GameState:
	var state := GameState.new()
	state.random.base_seed = base_seed
	state.worlds.galaxy_seed = RandomState.derive_seed(base_seed, &"galaxy")
	state.worlds.generator_version = WorldGenerator.GENERATOR_VERSION
	state.base = StartingBase.build(balance if balance != null else BalanceConfig.new())
	if balance != null:
		state.power = PowerState.starting(balance)
	return state


## Returns JSON-safe data for saving. Flag keys become Strings.
func to_dict() -> Dictionary:
	var flag_data: Dictionary = {}
	for key: Variant in flags:
		flag_data[str(key)] = flags[key]
	return {
		"clock": clock.to_dict(),
		"random": random.to_dict(),
		"flags": flag_data,
		"gate": gate.to_dict(),
		"power": power.to_dict(),
		"base": base.to_dict(),
		"worlds": worlds.to_dict(),
		"archive": archive.to_dict(),
		"address_book": address_book.to_dict(),
		"operations_log": operations_log.to_dict(),
	}


## Builds a GameState from saved [param data], e.g. after a JSON round trip. Flag keys
## become StringNames again, float flag values become ints, and unsupported values are
## dropped.
static func from_dict(data: Dictionary) -> GameState:
	var state := GameState.new()
	state.clock = ClockState.from_dict(_dict_or_empty(data.get("clock")))
	state.random = RandomState.from_dict(_dict_or_empty(data.get("random")))
	state.gate = GateState.from_dict(_dict_or_empty(data.get("gate")))
	state.power = PowerState.from_dict(_dict_or_empty(data.get("power")))
	state.base = BaseState.from_dict(_dict_or_empty(data.get("base")))
	state.worlds = WorldsState.from_dict(_dict_or_empty(data.get("worlds")))
	state.archive = ArchiveState.from_dict(_dict_or_empty(data.get("archive")))
	state.address_book = AddressBookState.from_dict(_dict_or_empty(data.get("address_book")))
	state.operations_log = LogState.from_dict(_dict_or_empty(data.get("operations_log")))
	var flag_data: Dictionary = _dict_or_empty(data.get("flags"))
	for key: Variant in flag_data:
		var flag_value: Variant = flag_data[key]
		if flag_value is float:
			flag_value = type_convert(flag_value, TYPE_INT)
		if not (flag_value is bool or flag_value is int or flag_value is String):
			continue
		state.flags[StringName(str(key))] = flag_value
	return state


## Returns human-readable errors for saved [param data], empty when it is valid: "clock", "random",
## "flags", "gate", "power", "base", "worlds", "archive", "address_book" and "operations_log"
## must be objects, the
## sub-states must pass their own validate_dict(), and every flag must be a bool, a String or a
## whole number with absolute value at most [constant JsonLimits.MAX_EXACT_INT] (larger numbers do
## not survive JSON, whether they arrive as ints or as floats). The Ring's "dial_started_tick" and
## "lock_started_tick", every Dial Log entry's "tick", every document's "received_tick" and every
## Address Book entry's "last_dialed_tick" and every operations log entry's "tick" must not be
## later than the clock's tick. Errors from a
## sub-state are prefixed with its key, e.g. "clock: 'tick' is not a whole number ...".
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in _SECTIONS:
		if not data.has(key):
			errors.append("missing '%s'" % key)
		elif not data[key] is Dictionary:
			errors.append("'%s' is not an object" % key)
	if not errors.is_empty():
		return errors
	for key: String in _SECTIONS:
		var section: Dictionary = data[key]
		for error: String in _section_errors(key, section):
			errors.append(key + ": " + error)
	var flag_data: Dictionary = data["flags"]
	for key: Variant in flag_data:
		if not _is_flag_value(flag_data[key]):
			errors.append("flag '%s' is not a bool, String or whole number" % str(key))
	if errors.is_empty():
		var clock_data: Dictionary = data["clock"]
		var gate_data: Dictionary = data["gate"]
		errors.append_array(_ring_tick_errors(clock_data, gate_data))
		var now: float = clock_data["tick"]
		errors.append_array(_record_tick_errors(now, data))
	return errors


## Errors of the sub-state saved under [param key]; flags are checked by the caller.
static func _section_errors(key: String, section: Dictionary) -> Array[String]:
	match key:
		"clock":
			return ClockState.validate_dict(section)
		"random":
			return RandomState.validate_dict(section)
		"gate":
			return GateState.validate_dict(section)
		"power":
			return PowerState.validate_dict(section)
		"base":
			return BaseState.validate_dict(section)
		"worlds":
			return WorldsState.validate_dict(section)
		"archive":
			return ArchiveState.validate_dict(section)
		"address_book":
			return AddressBookState.validate_dict(section)
		"operations_log":
			return LogState.validate_dict(section)
	return []


## Errors for Ring and Dial Log ticks later than the clock tick, in valid
## [param clock_data] and [param gate_data].
static func _ring_tick_errors(clock_data: Dictionary, gate_data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var now: float = clock_data["tick"]
	for key: String in ["dial_started_tick", "lock_started_tick"]:
		var tick: float = gate_data[key]
		if tick > now:
			errors.append("gate: '%s' is later than the clock tick" % key)
	var log_data: Array = gate_data["dial_log"]
	for index: int in log_data.size():
		var entry: Dictionary = log_data[index]
		var entry_tick: float = entry["tick"]
		if entry_tick > now:
			errors.append("gate: dial_log %d 'tick' is later than the clock tick" % index)
	return errors


## Errors for Archive and Address Book ticks later than the clock tick [param now], in valid
## [param data].
static func _record_tick_errors(now: float, data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var archive_data: Dictionary = data["archive"]
	var ticks: Dictionary = archive_data["received_tick"]
	for document_id: Variant in ticks:
		var tick: float = ticks[document_id]
		if tick > now:
			errors.append(
				"archive: received_tick of '%s' is later than the clock tick" % document_id
			)
	var book_data: Dictionary = data["address_book"]
	var entries: Array = book_data["entries"]
	for index: int in entries.size():
		var entry: Dictionary = entries[index]
		var dialed_tick: float = entry["last_dialed_tick"]
		if dialed_tick > now:
			errors.append(
				"address_book: entries %d 'last_dialed_tick' is later than the clock tick" % index
			)
	var log_data: Dictionary = data["operations_log"]
	if LogState.from_dict(log_data).last_tick() > now:
		errors.append("operations_log: the newest entry's 'tick' is later than the clock tick")
	return errors


static func _is_flag_value(value: Variant) -> bool:
	if value is bool or value is String:
		return true
	return JsonLimits.is_exact_int(value)


static func _dict_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
