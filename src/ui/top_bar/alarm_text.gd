class_name AlarmText
extends RefCounted
## The alarm strip's words (M4c-11): during the warning the countdown (and when the
## attackers can get through a closed Shutter, that they can); once they are in, the levels
## they were last seen on; and the Overrun countdown while it runs.
## Bible: docs/content/m4c-incursions.md sections 6 and 7


## The strip text for [param state], or "" when there is no incursion.
static func strip(state: GameState) -> String:
	var incursion: IncursionState = state.incursion
	if not incursion.is_active():
		return ""
	if incursion.phase == IncursionState.Phase.WARNING:
		var text: String = _tr(&"ALARM_INCOMING").format({"ticks": incursion.countdown})
		var def: IncursionDef = state.incursion_defs.get(incursion.def_id)
		if def != null and def.breaches_shutter and ShutterRules.is_installed(state):
			text += "  " + _tr(&"ALARM_BREACHES_SHUTTER")
		return text
	var text: String = _tr(&"ALARM_INTRUDERS").format({"levels": levels(state)})
	var left: int = FailureRules.overrun_left(state)
	if left >= 0:
		text += "  " + _tr(&"ALARM_OVERRUN").format({"ticks": left})
	return text


## The levels intruders were seen on, "1" or "1, 2"; "?" when none is seen.
static func levels(state: GameState) -> String:
	var found: Array[int] = []
	for group: IntruderGroup in state.incursion.groups:
		if SightRules.visible(state, group) and not found.has(group.pos().z):
			found.append(group.pos().z)
	found.sort()
	if found.is_empty():
		return "?"
	return ", ".join(found.map(func(level: int) -> String: return str(level)))


static func _tr(key: StringName) -> String:
	return TranslationServer.translate(key)
