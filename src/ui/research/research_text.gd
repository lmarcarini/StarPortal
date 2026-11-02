class_name ResearchText
extends RefCounted
## Text of the Research tab (docs/content/m25-lean-start.md section 3): a node's state
## ("Start", "needs Lift shaft", "ACTIVE", "done ✓", "locked"), the header's current project
## and time left, the SELECTED panel's lines, and a refused command in plain words. Pure:
## reads the state, never changes it.
## Bible: docs/content/m25-lean-start.md section 3

## What a row shows in its state column.
enum Kind { START, NEEDS, ACTIVE, DONE, LOCKED }


## The kind of row [param def] is in [param state].
static func kind(state: GameState, def: ResearchDef) -> Kind:
	if def.is_locked():
		return Kind.LOCKED
	if state.research.is_done(def.id):
		return Kind.DONE
	if state.research.active == def.id:
		return Kind.ACTIVE
	if not first_unmet(state, def).is_empty():
		return Kind.NEEDS
	return Kind.START


## The first project [param def] needs that is not done in [param state], or &"".
static func first_unmet(state: GameState, def: ResearchDef) -> StringName:
	for need: StringName in def.needs:
		if not state.research.is_done(need):
			return need
	return &""


## The state line of [param def]'s node: "Start", "needs Excavation survey", "ACTIVE",
## "done ✓", "locked".
static func state_word(state: GameState, def: ResearchDef) -> String:
	match kind(state, def):
		Kind.LOCKED:
			return _tr(&"RESEARCH_STATE_LOCKED")
		Kind.DONE:
			return _tr(&"RESEARCH_STATE_DONE")
		Kind.ACTIVE:
			return _tr(&"RESEARCH_STATE_ACTIVE")
		Kind.NEEDS:
			return _tr(&"RESEARCH_STATE_NEEDS").format(
				{"name": name_of(state, first_unmet(state, def))}
			)
	return _tr(&"RESEARCH_STATE_START")


## The translated name of project [param project_id], or the id when it has no def.
static func name_of(state: GameState, project_id: StringName) -> String:
	var def: ResearchDef = state.research_defs.get(project_id)
	return _tr(def.name_key) if def != null else String(project_id)


## "Current: Excavation survey", or "No project running".
static func current(state: GameState) -> String:
	var def: ResearchDef = state.research_defs.get(state.research.active)
	if def == null:
		return _tr(&"RESEARCH_CURRENT_NONE")
	return _tr(&"RESEARCH_CURRENT").format({"name": _tr(def.name_key)})


## "1 d 6 h left" for the active project, with "paused: no lab on" while no lab is on; "".
static func time_left(state: GameState) -> String:
	if not state.research.is_running():
		return ""
	var key: StringName = &"RESEARCH_LEFT"
	if not ResearchRules.has_lab_on(state):
		key = &"RESEARCH_LEFT_PAUSED"
	return _tr(key).format({"time": duration(ResearchRules.ticks_left(state))})


## "1 d 6 h", "2 d" or "5 h" for [param ticks] in-game minutes, hours rounded up.
static func duration(ticks: int) -> String:
	var hours: int = ceili(maxi(0, ticks) / 60.0)
	var days: int = hours / 24
	hours -= days * 24
	if days == 0:
		return _tr(&"BASE_BUILD_HOURS").format({"n": hours})
	if hours == 0:
		return _tr(&"RESEARCH_DAYS").format({"n": days})
	return _tr(&"RESEARCH_DAYS_HOURS").format({"d": days, "h": hours})


## Why [param result] refused a research command, in [param state]'s words.
static func refusal(result: CommandResult, state: GameState) -> String:
	match result.error_code:
		&"needs_lab":
			return _tr(&"RESEARCH_ERR_NEEDS_LAB")
		&"research_running":
			return _tr(&"RESEARCH_ERR_RUNNING")
		&"needs_project":
			var need: ResearchDef = state.research_defs.get(StringName(result.detail))
			var name: String = _tr(need.name_key) if need != null else result.detail
			return _tr(&"RESEARCH_ERR_NEEDS_PROJECT").format({"name": name})
		&"insufficient_funds":
			return _tr(&"RESEARCH_ERR_FUNDS").format({"cost": result.detail})
		&"project_locked":
			return _tr(&"RESEARCH_LOCK_%s" % result.detail.to_upper())
	return _tr(&"RESEARCH_ERR_OTHER")


static func _tr(key: StringName) -> String:
	return TranslationServer.translate(key)
