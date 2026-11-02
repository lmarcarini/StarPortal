class_name SaveMigrator
extends RefCounted
## Brings saved data forward to the current save format, one version at a time.
## Each step is a function Dictionary -> Dictionary that turns data at version N into data
## at version N + 1. Steps are pure: no side effects, no autoloads.
## M2, M2.5 (v12, docs/content/m25-lean-start.md section 7) and M2.6 (v13,
## docs/content/m26-staff-and-money.md section 8) are clean breaks: saves older
## than [constant OLDEST_VERSION] are not migrated but
## rejected with &"old_format_version" (owner ruling on card #133). Steps for later versions
## go in built_in_steps().
## Bible: technical-architecture.md#save-system

## The save format version the game writes and loads.
const TARGET_VERSION: int = 13
## The oldest save format the game still loads; older saves fail with &"old_format_version".
const OLDEST_VERSION: int = 13


## Returns the built-in steps, keyed by the version they migrate from; none yet since the M2.6
## clean break. (A function, not a constant: a Callable is not a constant expression.)
static func built_in_steps() -> Dictionary[int, Callable]:
	var built_in: Dictionary[int, Callable] = {}
	return built_in


## Returns [param data] migrated to [constant TARGET_VERSION] with the built-in steps.
## Fails with &"bad_format_version", &"old_format_version" (below
## [constant OLDEST_VERSION]), &"newer_format_version", &"missing_migration_step" or
## &"migration_failed". The input dictionary is never modified.
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
