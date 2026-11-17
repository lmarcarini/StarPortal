class_name TeamCardText
extends RefCounted
## The team card's words (pure): "T-1 · SURVEY · SILL", the time left "1D 6H" and the due date
## "DUE 04 JAN".
## Bible: docs/content/interface-reference.md section 5 (team_card)

## The team's call sign (one team in the field at a time).
const CALL_SIGN: String = "T-1"


## "T-1 · SURVEY · SILL" for the team out in [param state].
static func title(state: GameState) -> String:
	var plan: ExpeditionState = state.expedition
	var mission: String = (
		"STATION_MISSION_KEY_" + ExpeditionState.OBJECTIVE_NAMES[plan.objective].to_upper()
	)
	var world: String = AddressBookText.name_of_world(plan.world_id, state)
	return _tr(&"STATION_TEAM_TITLE").format(
		{"team": CALL_SIGN, "mission": _tr(mission), "world": world.to_upper()}
	)


## "1D 6H" left until the team is due.
static func time_left(state: GameState) -> String:
	var ticks: int = maxi(0, TeamContactRules.due_tick_of(state.expedition) - state.clock.tick)
	var hours: int = ticks / 60
	return "%dD %dH" % [hours / 24, hours % 24]


## "DUE 04 JAN".
static func due(state: GameState) -> String:
	var tick: int = TeamContactRules.due_tick_of(state.expedition)
	if tick < 0:
		return ""
	var date: Dictionary = TimeMath.date_of(tick)
	var month: String = _tr("COMMAND_MONTH_%d" % date["month"]).to_upper()
	return _tr(&"STATION_TEAM_DUE").format({"date": "%02d %s" % [date["day"], month]})


static func _tr(key: String) -> String:
	return TranslationServer.translate(key)
