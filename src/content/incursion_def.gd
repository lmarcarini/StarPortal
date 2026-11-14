class_name IncursionDef
extends DefBase
## An incursion a faction can send through the Ring (M4c): its groups (a unit type and a
## count each), one objective, the warning length and whether it gets through the Shutter.
## Bible: docs/content/m4c-incursions.md sections 1, 5 and 9

## The objectives an incursion can have.
const OBJECTIVES: Array[StringName] = [&"sabotage", &"theft", &"assault"]

## The faction that sends it.
@export var faction: StringName = &""
## Each group's UnitDef id; group_counts holds its number of units at the same index.
@export var group_units: Array[StringName] = []
## Units per group.
@export var group_counts: Array[int] = []
## One of OBJECTIVES.
@export var objective: StringName = &"sabotage"
## Ticks from the warning to the breach.
@export var warning_ticks: int = 30
## True when the Shutter does not stop it.
@export var breaches_shutter: bool = false


## The faction and every unit type.
func get_references() -> Array[StringName]:
	var found: Array[StringName] = [faction]
	found.append_array(group_units)
	return found


## Problems: no groups, mismatched or non-positive counts, a reference of the wrong kind, an
## unknown objective or warning ticks below 1.
func get_content_errors(defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = []
	if group_units.is_empty() or group_units.size() != group_counts.size():
		errors.append("needs one count per group and at least one group")
	for count: int in group_counts:
		if count < 1:
			errors.append("group counts must be at least 1")
	for unit: StringName in group_units:
		if defs.has(unit) and not defs[unit] is UnitDef:
			errors.append("%s is not a UnitDef" % unit)
	if defs.has(faction) and not defs[faction] is FactionDef:
		errors.append("%s is not a FactionDef" % faction)
	if not OBJECTIVES.has(objective):
		errors.append("objective must be one of %s" % str(OBJECTIVES))
	if warning_ticks < 1:
		errors.append("warning_ticks must be at least 1")
	return errors
