class_name ContentCheckResearchReveal
extends RefCounted
## M7 checks of the research list (docs/content/research-and-progression.md sections 3 and
## 10): every project's discipline has a research building, and every reveal condition can be
## met: a known condition type whose counter, held thing, faction, room or project exists.
## Pure; one line per problem.
## Bible: docs/content/research-and-progression.md sections 3 and 10


## The problems of [param research] against [param rooms] and the [param ids] of every
## loaded def.
static func check(
	research: Array[ResearchDef], rooms: Array[RoomDef], ids: Dictionary[StringName, bool]
) -> Array[String]:
	var errors: Array[String] = []
	var housed: Dictionary[StringName, bool] = {}
	for room: RoomDef in rooms:
		if not room.research_discipline.is_empty():
			housed[room.research_discipline] = true
	for def: ResearchDef in research:
		if not housed.has(def.discipline):
			errors.append("research %s: no building researches '%s'" % [def.id, def.discipline])
		for condition: ConditionDef in def.reveal_when:
			var problem: String = _unmet(condition, ids)
			if not problem.is_empty():
				errors.append("research %s: reveal %s" % [def.id, problem])
	return errors


static func _unmet(condition: ConditionDef, ids: Dictionary[StringName, bool]) -> String:
	if condition is CountAtLeastCondition:
		var counter: StringName = (condition as CountAtLeastCondition).counter
		var known: Array = ProgressCounters.COUNTERS.values()
		known.append_array([ProgressCounters.LOCKS, ProgressCounters.ALIEN_TALKS])
		return "" if known.has(counter) else "counts unknown '%s'" % counter
	if condition is HeldAtLeastCondition:
		var what: StringName = (condition as HeldAtLeastCondition).what
		return "" if HeldAtLeastCondition.WHATS.has(what) else "holds unknown '%s'" % what
	if condition is PowerUsageAtLeastCondition:
		var percent: int = (condition as PowerUsageAtLeastCondition).percent
		return "" if percent > 0 and percent <= 100 else "needs %d%% power" % percent
	for reference: StringName in condition.get_references():
		if not ids.has(reference):
			return "references unknown '%s'" % reference
	if condition is StandingAtLeastCondition or condition is RoomBuiltCondition:
		return ""
	if condition is HasArtefactCondition or condition is ResearchDoneCondition:
		return ""
	return "uses a condition the reveal cannot meet"
