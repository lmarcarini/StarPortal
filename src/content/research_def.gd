class_name ResearchDef
extends DefBase
## Definition of a research project (docs/content/m25-lean-start.md section 3): its place in
## the list, cost, days, the projects it needs, the conditions it requires (M4), whether it is
## hidden or shown locked until then, and the effects it applies when done. Read only at
## runtime.
## Bible: docs/content/m25-lean-start.md section 3, docs/content/m4-core-systems.md section 7

## How a project whose needs or requirements are unmet shows: &"locked" (drawn, with its
## reasons) or &"hidden" (not drawn until available, revealed or done).
const REVEALS: Array[StringName] = [&"locked", &"hidden"]

## Position in the Research list, lowest first; unique among projects.
@export var order: int = 0
## Money paid in full at start, in thousands of dollars; at least 0.
@export var cost_k: int = 0
## In-game days the project takes while the clock runs and a lab is on; at least 1.
@export var days: int = 1
## Ids of the projects that must be done before this one starts.
@export var needs: Array[StringName] = []
## Conditions beyond needs that must all hold to start it (artefact held, standing, flag...).
@export var requires: Array[ConditionDef] = []
## One of [constant REVEALS].
@export var reveal: StringName = &"locked"
## What finishing it does: unlock effects, story effects and modifiers.
@export var effects: Array[EffectDef] = []
## Id of the ResearchCategoryDef whose sub-tab shows this project or slot.
@export var category: StringName = &""
## Translation key of the name.
@export var name_key: StringName = &""
## Translation key of the one-line effect ("Up to 3 Capacitor Banks.").
@export var line_key: StringName = &""


## True when it shows only once available, revealed or done.
func is_hidden() -> bool:
	return reveal == &"hidden"


## The projects this one needs, and its category.
func get_references() -> Array[StringName]:
	var found: Array[StringName] = needs.duplicate()
	if not category.is_empty():
		found.append(category)
	return found


## Problems against the other loaded [param defs]: needs that are not projects (or are this
## one), no category or one that is not a ResearchCategoryDef, a bad cost or time, an unknown
## reveal, or a project without effects. The
## effect pairs themselves are checked by the content validator (ContentCheckResearch), since
## content may not depend on the simulation.
func get_content_errors(defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = []
	for need: StringName in needs:
		var other: DefBase = defs.get(need)
		var project: ResearchDef = other as ResearchDef
		if need == id or (other != null and project == null):
			errors.append("needs '%s', which is not another project" % need)
	var group: DefBase = defs.get(category)
	if category.is_empty() or (group != null and not group is ResearchCategoryDef):
		errors.append("has category '%s', which is not a research category" % category)
	if cost_k < 0 or days < 1:
		errors.append("needs cost_k >= 0 and days >= 1")
	if not reveal in REVEALS:
		errors.append("has unknown reveal '%s'" % reveal)
	if effects.is_empty():
		errors.append("has no effects")
	return errors
