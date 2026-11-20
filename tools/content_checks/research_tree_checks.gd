class_name ContentCheckResearchTree
extends RefCounted
## Checks that keep a large research tree sound (m4-core-systems.md section 7 (6)): no needs
## cycle, no need on a project that can never be visible (a story project no
## UnlockResearchEffect reveals), unique orders within a discipline; and a size report (projects
## per branch, the deepest chain). Pure; one line per problem.
## Bible: docs/content/m4-core-systems.md section 7 (6)


## The problems of [param research]; [param revealed] holds every project some
## UnlockResearchEffect reveals (from anywhere in the content).
static func check(
	research: Array[ResearchDef], revealed: Dictionary[StringName, bool]
) -> Array[String]:
	var by_id: Dictionary[StringName, ResearchDef] = {}
	for def: ResearchDef in research:
		by_id[def.id] = def
	var errors: Array[String] = _cycle_errors(by_id)
	var orders: Dictionary[String, StringName] = {}
	for def: ResearchDef in research:
		var key: String = "%s/%d" % [def.discipline, def.order]
		if orders.has(key):
			errors.append(
				"research %s: order %d repeats %s in its branch" % [def.id, def.order, orders[key]]
			)
		orders[key] = def.id
		for need: StringName in def.needs:
			var other: ResearchDef = by_id.get(need)
			if other != null and _never_visible(other, revealed):
				errors.append(
					"research %s: needs %s, which can never become visible" % [def.id, need]
				)
	return errors


## True when [param def] is a story project that nothing reveals.
static func _never_visible(def: ResearchDef, revealed: Dictionary[StringName, bool]) -> bool:
	return def.story and not revealed.has(def.id)


## Every project an UnlockResearchEffect names in [param defs] (any definition kind; nested
## lists inside conversations included).
static func revealed_ids(defs: Array[DefBase]) -> Dictionary[StringName, bool]:
	var found: Dictionary[StringName, bool] = {}
	for def: DefBase in defs:
		var effects: Array[EffectDef] = []
		if def is ConversationDef:
			effects = (def as ConversationDef).all_effects()
		else:
			for property: Dictionary in def.get_property_list():
				if property["type"] == TYPE_ARRAY and property["usage"] & PROPERTY_USAGE_STORAGE:
					var property_name: StringName = property["name"]
					var values: Array = def.get(property_name)
					for value: Variant in values:
						if value is EffectDef:
							var effect: EffectDef = value
							effects.append(effect)
		for effect: EffectDef in effects:
			if effect is UnlockResearchEffect:
				found[(effect as UnlockResearchEffect).project] = true
	return found


## "Branch: count" lines and the deepest needs chain, for the validator's report.
static func report(research: Array[ResearchDef]) -> Array[String]:
	var by_id: Dictionary[StringName, ResearchDef] = {}
	var counts: Dictionary[StringName, int] = {}
	for def: ResearchDef in research:
		by_id[def.id] = def
		counts[def.discipline] = counts.get(def.discipline, 0) + 1
	var lines: Array[String] = []
	var branches: Array = counts.keys()
	branches.sort()
	for branch: StringName in branches:
		lines.append("research: %s has %d project(s)" % [branch, counts[branch]])
	var deepest: int = 0
	var memo: Dictionary[StringName, int] = {}
	for id: StringName in by_id:
		deepest = maxi(deepest, _depth(id, by_id, memo, 0))
	lines.append("research: deepest needs chain is %d project(s)" % deepest)
	return lines


static func _depth(
	id: StringName,
	by_id: Dictionary[StringName, ResearchDef],
	memo: Dictionary[StringName, int],
	guard: int
) -> int:
	if memo.has(id):
		return memo[id]
	var def: ResearchDef = by_id.get(id)
	if def == null or guard > by_id.size():
		return 0
	var best: int = 0
	for need: StringName in def.needs:
		best = maxi(best, _depth(need, by_id, memo, guard + 1))
	memo[id] = best + 1
	return best + 1


## One error per project on a needs cycle (depth-first, colours 1 on path / 2 done).
static func _cycle_errors(by_id: Dictionary[StringName, ResearchDef]) -> Array[String]:
	var errors: Array[String] = []
	var colour: Dictionary[StringName, int] = {}
	for id: StringName in by_id:
		if colour.get(id, 0) == 0 and _visit(id, by_id, colour):
			errors.append("research %s: its needs form a cycle" % id)
	return errors


static func _visit(
	id: StringName, by_id: Dictionary[StringName, ResearchDef], colour: Dictionary[StringName, int]
) -> bool:
	if colour.get(id, 0) == 1:
		return true
	if colour.get(id, 0) == 2 or not by_id.has(id):
		return false
	colour[id] = 1
	for need: StringName in by_id[id].needs:
		if _visit(need, by_id, colour):
			colour[id] = 2
			return true
	colour[id] = 2
	return false
