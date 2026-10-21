class_name SaveMigrator
extends RefCounted
## Brings saved data forward to the current save format, one version at a time.
## Each step is a function Dictionary -> Dictionary that turns data at version N into data
## at version N + 1. Steps are pure: no side effects, no autoloads.
## Bible: technical-architecture.md#save-system

## The save format version the game writes and loads.
const TARGET_VERSION: int = 1

## Built-in steps, keyed by the version they migrate from. Version 1 is the first format,
## so there is none yet. A v1 -> v2 change adds [code]1: _v1_to_v2[/code] here.
const STEPS: Dictionary[int, Callable] = {}


## Returns [param data] migrated to [constant TARGET_VERSION] with the built-in steps.
## Fails with &"bad_format_version", &"newer_format_version", &"missing_migration_step"
## or &"migration_failed". The input dictionary is never modified.
static func migrate(data: Dictionary) -> Result:
	return migrate_with_steps(data, STEPS, TARGET_VERSION)


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
## &"bad_format_version" when it is missing, not a number, fractional or negative.
static func read_version(data: Dictionary) -> Result:
	var raw: Variant = data.get("format_version")
	if not (raw is int or raw is float):
		return Result.fail(&"bad_format_version", "format_version is missing or not a number")
	var as_float: float = raw
	if as_float != floorf(as_float) or as_float < 0.0:
		return Result.fail(&"bad_format_version", "format_version %s is invalid" % str(raw))
	var version: int = raw
	return Result.ok(version)
