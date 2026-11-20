class_name ResearchDef
extends DefBase
## Definition of a research project (docs/content/research-and-progression.md sections 2-5):
## its discipline, tier, cost, hours, the projects it needs, the conditions that reveal it and
## those it requires to start, the artefacts and specimens it spends, and the effects it
## applies when done. Nothing shows until revealed. Read only at
## runtime.
## Bible: docs/content/research-and-progression.md sections 2-5

## The disciplines; each is researched in its own building (RoomDef.research_discipline).
const DISCIPLINES: Array[StringName] = [
	&"engineering", &"science", &"office", &"xenotech", &"xenobiology"
]

## Position in its discipline's list, lowest first; unique among projects.
@export var order: int = 0
## The discipline (one of [constant DISCIPLINES]): which buildings run it.
@export var discipline: StringName = &""
## Tier 1 to 4 (docs/content/research-and-progression.md section 5); 5 for alien core.
@export var tier: int = 1
## Money paid in full at start, in thousands of dollars; at least 0.
@export var cost_k: int = 0
## In-game hours the project takes for a standard crew; at least 1.
@export var hours: int = 1
## Ids of the projects that must be done before this one shows or starts.
@export var needs: Array[StringName] = []
## Conditions that must all hold for the project to show ("Shows when"); once shown it stays.
@export var reveal_when: Array[ConditionDef] = []
## Conditions beyond needs that must all hold to start it (an artefact held...).
@export var requires: Array[ConditionDef] = []
## A story placeholder: never shown until the story reveals it.
@export var story: bool = false
## Artefact consumed on start (docs section 4, "costs alien pieces"), or &"" for none.
@export var piece_artefact: StringName = &""
## How many of [member piece_artefact] are consumed on start; at least 0.
@export var piece_count: int = 0
## Specimens of alien life consumed on start; at least 0.
@export var specimen_count: int = 0
## What finishing it does: unlock effects, story effects and modifiers.
@export var effects: Array[EffectDef] = []
## Id of the old ResearchCategoryDef (M2.5 Research tab), or &"" (retired with M7).
@export var category: StringName = &""
## Translation key of the name.
@export var name_key: StringName = &""
## Translation key of the one-line effect ("Up to 3 Capacitor Banks.").
@export var line_key: StringName = &""


## The projects this one needs, and its category.
func get_references() -> Array[StringName]:
	var found: Array[StringName] = needs.duplicate()
	if not category.is_empty():
		found.append(category)
	return found


## Problems against the other loaded [param defs]: needs that are not projects (or are this
## one), a category that is not a ResearchCategoryDef, an unknown discipline, a bad cost,
## time, tier or material cost, or a project without effects. The
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
	if group != null and not group is ResearchCategoryDef:
		errors.append("has category '%s', which is not a research category" % category)
	if not discipline in DISCIPLINES:
		errors.append("has unknown discipline '%s'" % discipline)
	if cost_k < 0 or hours < 1 or tier < 1 or tier > 5:
		errors.append("needs cost_k >= 0, hours >= 1 and tier 1 to 5")
	if piece_count < 0 or specimen_count < 0 or (piece_count > 0) == piece_artefact.is_empty():
		errors.append("needs counts >= 0 and an artefact exactly when pieces are spent")
	if effects.is_empty():
		errors.append("has no effects")
	return errors
