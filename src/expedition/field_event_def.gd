class_name FieldEventDef
extends RefCounted
## One field event of the pool (docs/content/m3-beyond-the-ring.md section 4, Risk model): the
## role whose best member rolls, its own difficulty (1 to 4), where it can happen (objectives,
## biomes and the lowest true threat; empty lists mean any) and its setback on failure. Its
## texts are FIELD_EVENT_<ID>_TITLE, _SUCCESS (the finding, or nothing bad) and _FAILURE.
## Bible: docs/content/m3-beyond-the-ring.md section 4

## What a failed check costs: a wasted day (no finding), a light or a serious injury to the
## member who rolled (serious only on difficulty 4), or a missed check-in.
enum Setback { WASTED, LIGHT, SERIOUS, MISSED }

## Saved and reported names of the setbacks, indexed by Setback value.
const SETBACK_NAMES: Array[String] = ["wasted", "light", "serious", "missed"]
## Lowest and highest own difficulty.
const MIN_DIFFICULTY: int = 1
const MAX_DIFFICULTY: int = 4

## Stable id; the text keys derive from it.
var id: StringName = &""
## Role id (StartingStaff) whose best team member rolls.
var role: StringName = &""
## The event's own difficulty, 1 to 4.
var difficulty: int = MIN_DIFFICULTY
## The setback on failure.
var setback: Setback = Setback.WASTED
## Objectives (ExpeditionState.Objective) it can happen on; empty for any.
var objectives: Array[int] = []
## Biomes (WorldDef.Biome) it can happen on; empty for any.
var biomes: Array[int] = []
## Lowest true threat (WorldDef.Threat) it can happen at.
var min_threat: WorldDef.Threat = WorldDef.Threat.LOW


## A new event [param event_id] rolled by [param event_role] at [param own_difficulty], costing
## [param event_setback] on failure; set objectives, biomes and min_threat after.
static func create(
	event_id: StringName, event_role: StringName, own_difficulty: int, event_setback: Setback
) -> FieldEventDef:
	var def := FieldEventDef.new()
	def.id = event_id
	def.role = event_role
	def.difficulty = own_difficulty
	def.setback = event_setback
	return def


## True when it can happen on [param objective] on a world of [param facts].
func fits(objective: int, facts: WorldFacts) -> bool:
	if not objectives.is_empty() and not objective in objectives:
		return false
	if not biomes.is_empty() and not int(facts.biome) in biomes:
		return false
	return facts.threat >= min_threat


## The translation key of its [param part]: "TITLE", "SUCCESS" or "FAILURE".
func text_key(part: String) -> String:
	return "FIELD_EVENT_%s_%s" % [String(id).to_upper(), part]
