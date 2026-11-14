class_name ResearchTreeLayout
extends RefCounted
## Where each node of a Research sub-tab sits (docs/content/m25-lean-start.md section 3):
## the column is the prerequisite depth within the category (0 for a project that needs
## nothing in it, else one more than the deepest need in it), and the row is the place in
## that column in list order. Needs in another category do not move a node; they become
## labelled stubs. Pure and deterministic: the same defs always give the same layout.
## Bible: docs/content/m25-lean-start.md section 3


## The defs of [param defs] in [param category], in list order.
static func in_category(defs: Array[ResearchDef], category: StringName) -> Array[ResearchDef]:
	var found: Array[ResearchDef] = []
	for def: ResearchDef in defs:
		if def.category == category:
			found.append(def)
	found.sort_custom(func(a: ResearchDef, b: ResearchDef) -> bool: return a.order < b.order)
	return found


## {id: Vector2i(column, row)} for every def of [param defs] in [param category].
static func cells(
	defs: Array[ResearchDef], category: StringName
) -> Dictionary[StringName, Vector2i]:
	var depth: Dictionary[StringName, int] = {}
	var rows: Dictionary[int, int] = {}
	var found: Dictionary[StringName, Vector2i] = {}
	for def: ResearchDef in in_category(defs, category):
		var column: int = 0
		for need: StringName in def.needs:
			if depth.has(need):
				column = maxi(column, depth[need] + 1)
		depth[def.id] = column
		var row: int = rows.get(column, 0)
		rows[column] = row + 1
		found[def.id] = Vector2i(column, row)
	return found


## The [need, project] pairs inside [param category]: one line each in the tree.
static func edges(defs: Array[ResearchDef], category: StringName) -> Array[Array]:
	var placed: Dictionary[StringName, Vector2i] = cells(defs, category)
	var found: Array[Array] = []
	for def: ResearchDef in in_category(defs, category):
		for need: StringName in def.needs:
			if placed.has(need):
				found.append([need, def.id])
	return found


## The needs of [param def] that lie outside its category: one labelled stub each.
static func stubs(defs: Array[ResearchDef], def: ResearchDef) -> Array[StringName]:
	var placed: Dictionary[StringName, Vector2i] = cells(defs, def.category)
	var found: Array[StringName] = []
	for need: StringName in def.needs:
		if not placed.has(need):
			found.append(need)
	return found


## The needs of [param def] outside the cells [param placed] (from cells()), without computing
## the layout again: the fast form of stubs() for a whole tree.
static func stubs_in(
	placed: Dictionary[StringName, Vector2i], def: ResearchDef
) -> Array[StringName]:
	var found: Array[StringName] = []
	for need: StringName in def.needs:
		if not placed.has(need):
			found.append(need)
	return found
