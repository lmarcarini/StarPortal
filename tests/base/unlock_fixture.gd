class_name UnlockFixture
extends RefCounted
## Test helper: the M2.5 research projects (the open ones, in list order) read from the loaded
## ResearchDefs, now that their effects live only in data (M4-21).


## Every M2.5 project (orders 1 to 7)'s unlock pairs, by id, in list order.
static func projects() -> Dictionary:
	var defs: Array[ResearchDef] = []
	for def: DefBase in Registry.get_all_of(ResearchDef):
		var research: ResearchDef = def
		if research.order <= 7:
			defs.append(research)
	defs.sort_custom(func(a: ResearchDef, b: ResearchDef) -> bool: return a.order < b.order)
	var found: Dictionary = {}
	for def: ResearchDef in defs:
		var pairs: Array = []
		for effect: EffectDef in def.effects:
			var pair: Array = UnlockRules.unlock_pair(effect)
			if not pair.is_empty():
				pairs.append(pair)
		found[def.id] = pairs
	return found


## Applies project [param project_id]'s unlock effects to [param unlocks]; false when unknown.
static func apply_project(unlocks: UnlockState, project_id: StringName) -> bool:
	return UnlockRules.apply_project(unlocks, Registry.get_def(project_id) as ResearchDef)


## Every loaded ResearchDef by id.
static func research() -> Dictionary[StringName, ResearchDef]:
	var found: Dictionary[StringName, ResearchDef] = {}
	for def: DefBase in Registry.get_all_of(ResearchDef):
		found[def.id] = def as ResearchDef
	return found
