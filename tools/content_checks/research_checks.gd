class_name ContentCheckResearch
extends RefCounted
## Content checks for the research definitions (docs/content/m25-lean-start.md section 3):
## every unlock effect has a value UnlockRules accepts (effects live only in the defs, M4),
## list orders are unique, a project's
## needs come earlier in the list, every name and line key is in [param keys], and every def
## is in a known category (check_categories). Needs that point at missing or locked defs are
## the Registry's checks (ResearchDef). Pure; returns one line per problem.
## Bible: docs/content/m25-lean-start.md section 3, technical-architecture.md#data-model


## Returns the problems of the research [param categories]: unique orders, a name key in
## [param keys] (skipped when empty), and every def of [param research] in one of them.
static func check_categories(
	research: Array[ResearchDef],
	categories: Array[ResearchCategoryDef],
	keys: Dictionary[String, bool]
) -> Array[String]:
	var errors: Array[String] = []
	var orders: Dictionary[int, StringName] = {}
	var known: Dictionary[StringName, bool] = {}
	for category: ResearchCategoryDef in categories:
		known[category.id] = true
		if orders.has(category.order):
			errors.append("research category %s: order %d is taken" % [category.id, category.order])
		orders[category.order] = category.id
		if not keys.is_empty() and not keys.has(String(category.name_key)):
			errors.append("research category %s: text key is in no table" % category.id)
	for def: ResearchDef in research:
		if not known.has(def.category):
			errors.append("research %s: unknown category '%s'" % [def.id, def.category])
	return errors


## Returns the problems of [param research], checking text keys against [param keys] (the
## research and base tables; skipped when empty).
static func check(research: Array[ResearchDef], keys: Dictionary[String, bool]) -> Array[String]:
	var errors: Array[String] = []
	var orders: Dictionary[int, StringName] = {}
	var by_id: Dictionary[StringName, ResearchDef] = {}
	for def: ResearchDef in research:
		by_id[def.id] = def
		if orders.has(def.order):
			errors.append(
				"research %s: order %d also used by %s" % [def.id, def.order, orders[def.order]]
			)
		orders[def.order] = def.id
		for key: StringName in [def.name_key, def.line_key]:
			if not keys.is_empty() and not keys.has(String(key)):
				errors.append("research %s: text key '%s' is in no table" % [def.id, key])
	for def: ResearchDef in research:
		errors.append_array(_project_errors(def, by_id))
	return errors


static func _project_errors(
	def: ResearchDef, by_id: Dictionary[StringName, ResearchDef]
) -> Array[String]:
	var errors: Array[String] = []
	for effect: EffectDef in def.effects:
		if not effect_ok(effect):
			errors.append("research %s: bad effect %s" % [def.id, _describe(effect)])
	for effect: EffectDef in def.effects:
		if (
			effect is StudyArtefactEffect
			and not _requires_artefact(def, effect.get_references()[0])
		):
			errors.append(
				(
					"research %s: studies '%s' but does not require HasArtefact of it"
					% [def.id, effect.get_references()[0]]
				)
			)
	for need: StringName in def.needs:
		if by_id.has(need) and by_id[need].order >= def.order:
			errors.append("research %s: needs %s, which comes later in the list" % [def.id, need])
	return errors


## True when [param effect] is a story effect, and an unlock effect's value is one
## UnlockRules.apply() accepts.
static func effect_ok(effect: EffectDef) -> bool:
	if effect == null:
		return false
	var pair: Array = UnlockRules.unlock_pair(effect)
	if pair.is_empty():
		return true
	var effect_id: StringName = pair[0]
	return UnlockRules.apply(UnlockState.new(), effect_id, pair[1])


static func _describe(effect: EffectDef) -> String:
	if effect == null:
		return "<empty>"
	return str(UnlockRules.unlock_pair(effect))


static func _requires_artefact(def: ResearchDef, artefact: StringName) -> bool:
	for condition: ConditionDef in def.requires:
		if (
			condition is HasArtefactCondition
			and (condition as HasArtefactCondition).artefact == artefact
		):
			return true
	return false
