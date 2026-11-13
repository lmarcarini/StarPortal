class_name ResearchDef
extends DefBase
## Definition of a research project (docs/content/m25-lean-start.md section 3): its place in
## the list, cost, days, the projects it needs and the unlock effects it applies when done. A
## locked slot (a later unlock shown at the bottom of the list) has a [member lock] reason and
## no cost, days, needs or effects. Read only at runtime.
## Bible: docs/content/m25-lean-start.md section 3, technical-architecture.md#data-model

## Lock reasons of a slot that research cannot start yet.
const LOCKS: Array[StringName] = [&"alien_find", &"staff"]

## Position in the Research list, lowest first; unique among projects.
@export var order: int = 0
## Money paid in full at start, in thousands of dollars; at least 0.
@export var cost_k: int = 0
## In-game days the project takes while the clock runs and a lab is on; at least 1.
@export var days: int = 1
## Ids of the projects that must be done before this one starts.
@export var needs: Array[StringName] = []
## The unlocks, each an [effect id, value] pair for UnlockRules.apply_to_game().
@export var effects: Array[EffectDef] = []
## Empty for a project; one of [constant LOCKS] for a later slot.
@export var lock: StringName = &""
## Id of the ResearchCategoryDef whose sub-tab shows this project or slot.
@export var category: StringName = &""
## Translation key of the name ("Unknown" for a locked slot).
@export var name_key: StringName = &""
## Translation key of the one-line effect ("Up to 3 Capacitor Banks.") or, for a locked
## slot, of the reason ("Requires an alien find").
@export var line_key: StringName = &""


## True for a later slot that cannot be started.
func is_locked() -> bool:
	return not lock.is_empty()


## The projects this one needs, and its category.
func get_references() -> Array[StringName]:
	var found: Array[StringName] = needs.duplicate()
	if not category.is_empty():
		found.append(category)
	return found


## Problems against the other loaded [param defs]: needs that are not projects (or are this
## one), no category or one that is not a ResearchCategoryDef, a bad cost or time, an unknown
## lock, a project without effects, or a locked slot that has a cost, needs or effects. The
## effect pairs themselves are checked by the content validator (ContentCheckResearch), since
## content may not depend on the simulation.
func get_content_errors(defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = []
	for need: StringName in needs:
		var other: DefBase = defs.get(need)
		var project: ResearchDef = other as ResearchDef
		if need == id or (other != null and (project == null or project.is_locked())):
			errors.append("needs '%s', which is not another open project" % need)
	var group: DefBase = defs.get(category)
	if category.is_empty() or (group != null and not group is ResearchCategoryDef):
		errors.append("has category '%s', which is not a research category" % category)
	if cost_k < 0 or days < 1:
		errors.append("needs cost_k >= 0 and days >= 1")
	if is_locked():
		if not lock in LOCKS:
			errors.append("has unknown lock '%s'" % lock)
		if cost_k != 0 or not needs.is_empty() or not effects.is_empty():
			errors.append("is locked but has a cost, needs or effects")
		return errors
	if effects.is_empty():
		errors.append("has no effects")
	return errors
