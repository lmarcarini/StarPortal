class_name ContentCheckResearch
extends RefCounted
## Content checks for the research definitions (docs/content/m25-lean-start.md section 3):
## every effect is an [effect id, value] pair UnlockRules accepts, the open projects are
## exactly UnlockRules.PROJECTS with the same effects, list orders are unique, a project's
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
	for project_id: StringName in UnlockRules.PROJECTS:
		if not by_id.has(project_id):
			errors.append("research %s: in UnlockRules.PROJECTS but has no def" % project_id)
	return errors


static func _project_errors(
	def: ResearchDef, by_id: Dictionary[StringName, ResearchDef]
) -> Array[String]:
	var errors: Array[String] = []
	for pair: Variant in def.effects:
		if not effect_ok(pair):
			errors.append("research %s: bad effect %s" % [def.id, str(pair)])
	for need: StringName in def.needs:
		if by_id.has(need) and by_id[need].order >= def.order:
			errors.append("research %s: needs %s, which comes later in the list" % [def.id, need])
	if def.is_locked():
		return errors
	if not UnlockRules.PROJECTS.has(def.id):
		errors.append("research %s: not in UnlockRules.PROJECTS" % def.id)
	elif str(UnlockRules.PROJECTS[def.id]) != str(def.effects):
		errors.append("research %s: effects differ from UnlockRules.PROJECTS" % def.id)
	return errors


## True when [param pair] is an [effect id, value] pair UnlockRules.apply() accepts.
static func effect_ok(pair: Variant) -> bool:
	if not pair is Array:
		return false
	var entry: Array = pair
	if entry.size() != 2:
		return false
	if not (entry[0] is StringName or entry[0] is String):
		return false
	return UnlockRules.apply(UnlockState.new(), StringName(str(entry[0])), entry[1])
