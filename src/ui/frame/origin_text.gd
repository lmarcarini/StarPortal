class_name OriginText
extends RefCounted
## Origin tracing (S06, docs/content/research-and-progression.md section 10): once
## researched, an incoming wormhole names who it comes from, and an incursion warning names
## its objective. "" before the research. Pure.
## Bible: docs/content/research-and-progression.md section 10


## " · KINDRED" for the incoming wormhole of [param state], or "".
static func incoming(state: GameState) -> String:
	if not ResearchPerks.has(state, ResearchPerks.ORIGIN_TRACING):
		return ""
	var faction: FactionDef = state.faction_defs.get(state.gate.incoming_faction)
	if faction == null:
		return ""
	return " · " + TranslationServer.translate(faction.name_key).to_upper()


## "  Objective: theft" for the warned incursion of [param state], or "".
static func objective(state: GameState) -> String:
	if not ResearchPerks.has(state, ResearchPerks.ORIGIN_TRACING):
		return ""
	var def: IncursionDef = state.incursion_defs.get(state.incursion.def_id)
	if def == null:
		return ""
	var name: String = TranslationServer.translate(
		StringName("INCURSION_OBJECTIVE_" + String(def.objective).to_upper())
	)
	return "  " + TranslationServer.translate(&"ALARM_OBJECTIVE").format({"name": name})
