class_name SaveMigrator
extends RefCounted
## Brings saved data forward to the current save format, one version at a time.
## Each step is a function Dictionary -> Dictionary that turns data at version N into data
## at version N + 1. Steps are pure: no side effects, no autoloads.
## M2, M2.5 (v12, docs/content/m25-lean-start.md section 7), M2.6 (v13,
## docs/content/m26-staff-and-money.md section 8) and M2.7 (v14,
## docs/content/m27-daily-rhythm.md section 7) and M3 (v15,
## docs/content/m3-beyond-the-ring.md section 9) are clean breaks: saves older
## than [constant OLDEST_VERSION] are not migrated but
## rejected with &"old_format_version" (owner ruling on card #133). Steps for later versions
## go in built_in_steps().
## Bible: technical-architecture.md#save-system

## The save format version the game writes and loads.
const TARGET_VERSION: int = 22
## The oldest save format the game still loads; older saves fail with &"old_format_version".
const OLDEST_VERSION: int = 15


## Returns the built-in steps, keyed by the version they migrate from. (A function, not a
## constant: a Callable is not a constant expression.)
static func built_in_steps() -> Dictionary[int, Callable]:
	var built_in: Dictionary[int, Callable] = {
		15: _v15_to_v16,
		16: _v16_to_v17,
		17: _v17_to_v18,
		18: _v18_to_v19,
		19: _v19_to_v20,
		20: _v20_to_v21,
		21: _v21_to_v22
	}
	return built_in


## v15 → v16 (M4, docs/content/m4-core-systems.md section 9): adds the empty factions,
## conversations, requests and artefacts sections, an empty research queue and revealed list
## and no incoming wormhole. Factions start empty in an old save (no standings, none met).
static func _v15_to_v16(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	if not out.get("state") is Dictionary:
		return out
	var state: Dictionary = out["state"]
	state["factions"] = FactionsState.new().to_dict()
	state["conversations"] = ConversationsState.new().to_dict()
	state["requests"] = RequestsState.new().to_dict()
	state["artefacts"] = ArtefactsState.new().to_dict()
	for key: String in ["research", "gate"]:
		if not state.get(key) is Dictionary:
			continue
		var section: Dictionary = state[key]
		if key == "research":
			section["queue"] = []
			section["revealed"] = []
		else:
			section["incoming"] = {}
	return out


## Returns [param data] migrated to [constant TARGET_VERSION] with the built-in steps.
## Fails with &"bad_format_version", &"old_format_version" (below
## [constant OLDEST_VERSION]), &"newer_format_version", &"missing_migration_step" or
## &"migration_failed". The input dictionary is never modified.
## v17 (M4.7-02): the clock gains its slow reasons and overrides, both empty.
static func _v16_to_v17(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	if not out.get("state") is Dictionary:
		return out
	var state: Dictionary = out["state"]
	if state.get("clock") is Dictionary:
		var clock: Dictionary = state["clock"]
		clock["slows"] = []
		clock["overridden"] = []
	return out


## v18 (M4.7-04): the gate gains operating, false.
static func _v17_to_v18(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	if not out.get("state") is Dictionary:
		return out
	var state: Dictionary = out["state"]
	if state.get("gate") is Dictionary:
		var gate: Dictionary = state["gate"]
		gate["operating"] = false
	return out


## v19 (M4c-02): empty incursion, security and outcome sections, and no blast doors.
static func _v18_to_v19(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	if not out.get("state") is Dictionary:
		return out
	var state: Dictionary = out["state"]
	state["incursion"] = IncursionState.new().to_dict()
	state["security"] = SecurityState.new().to_dict()
	state["outcome"] = OutcomeState.new().to_dict()
	if state.get("base") is Dictionary:
		var base: Dictionary = state["base"]
		base["doors"] = []
	return out


## v20 (M4c-10): the Shutter, open.
static func _v19_to_v20(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	if not out.get("state") is Dictionary:
		return out
	var state: Dictionary = out["state"]
	if state.get("gate") is Dictionary:
		var gate: Dictionary = state["gate"]
		gate["shutter"] = "open"
	return out


## v21 (M4c-20): MOTHs are built to order from a researched rack; an old save keeps its
## MOTHs, gets Survey drones done and a built rack in the Gate Room.
static func _v20_to_v21(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	if not out.get("state") is Dictionary:
		return out
	var state: Dictionary = out["state"]
	if state.get("research") is Dictionary:
		var research: Dictionary = state["research"]
		if research.get("done") is Array:
			var done: Array = research["done"]
			if not done.has("survey_drones"):
				done.append("survey_drones")
	var base: Dictionary = SaveFields.dict_or_empty(state.get("base"))
	for room: Dictionary in SaveFields.dicts_in(base.get("rooms")):
		if room.get("def_id") == "room_gate":
			var items: Array = room.get("installations", [])
			items.append(
				{"def": "installation_moth_rack", "build_ticks_left": 0, "paid_k": 0, "health": 0}
			)
			room["installations"] = items
	return out


## v22 (M4.8-02, docs/content/dialogue-screen.md section 7): a conversation holds the clock
## instead of slowing it. A running conversation gets a phase (LINE; GameSetup puts one at a
## choice at CHOICE), no cut-off and the conversation hold; the old conversation slow goes.
static func _v21_to_v22(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	if not out.get("state") is Dictionary:
		return out
	var state: Dictionary = out["state"]
	var clock: Dictionary = SaveFields.dict_or_empty(state.get("clock"))
	for key: String in ["slows", "overridden"]:
		if clock.get(key) is Array:
			var keys: Array = clock[key]
			clock[key] = keys.filter(func(entry: Variant) -> bool: return entry != "conversation")
	var conversations: Dictionary = SaveFields.dict_or_empty(state.get("conversations"))
	var active: Dictionary = SaveFields.dict_or_empty(conversations.get("active"))
	if active.is_empty():
		return out
	active["phase"] = "line"
	active["cut_off"] = false
	if clock.get("holds") is Array and not clock.is_empty():
		var holds: Array = clock["holds"]
		if holds.is_empty():
			clock["mode_after_hold"] = "running" if clock.get("mode") == "running" else "paused"
			clock["mode"] = "held"
		if not holds.has("conversation"):
			holds.append("conversation")
	return out


static func migrate(data: Dictionary) -> Result:
	var version_result := read_version(data)
	if not version_result.is_ok:
		return version_result
	var version: int = version_result.value
	if version < OLDEST_VERSION:
		return Result.fail(
			&"old_format_version",
			"save is v%d, this game reads v%d and later" % [version, OLDEST_VERSION]
		)
	return migrate_with_steps(data, built_in_steps(), TARGET_VERSION)


## Returns [param data] migrated to [param target] by running [param steps] in version
## order. [param steps] maps a from-version to a Callable(Dictionary) -> Dictionary.
## After each step "format_version" is set to the step's to-version.
static func migrate_with_steps(
	data: Dictionary, steps: Dictionary[int, Callable], target: int
) -> Result:
	var version_result := read_version(data)
	if not version_result.is_ok:
		return version_result
	var version: int = version_result.value
	if version > target:
		return Result.fail(
			&"newer_format_version", "save is v%d, this game reads up to v%d" % [version, target]
		)
	var current: Dictionary = data.duplicate(true)
	while version < target:
		if not steps.has(version):
			return Result.fail(&"missing_migration_step", "no step from v%d" % version)
		var migrated: Variant = steps[version].call(current)
		if not migrated is Dictionary:
			return Result.fail(&"migration_failed", "step from v%d returned no data" % version)
		current = migrated
		version += 1
		current["format_version"] = version
	return Result.ok(current)


## Returns the whole-number "format_version" of [param data] as an int, or fails with
## &"bad_format_version" when it is missing, not a number, fractional, negative or above
## [constant JsonLimits.MAX_EXACT_INT] (2^53, so the float-to-int conversion never
## overflows).
static func read_version(data: Dictionary) -> Result:
	var raw: Variant = data.get("format_version")
	if not (raw is int or raw is float):
		return Result.fail(&"bad_format_version", "format_version is missing or not a number")
	var as_float: float = raw
	var limit: float = float(JsonLimits.MAX_EXACT_INT)
	if not (as_float == floorf(as_float) and as_float >= 0.0 and as_float <= limit):
		return Result.fail(&"bad_format_version", "format_version %s is invalid" % str(raw))
	var version: int = raw
	return Result.ok(version)
