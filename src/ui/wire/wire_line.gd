class_name WireLine
extends RefCounted
## The one short line under a wire card's title (interface-reference.md section 4: no
## sentences on the wire): "Research Lab · 2 scientists", "3 candidates available", the caller,
## the request. Empty when a kind has none. Pure.
## Bible: docs/content/interface-reference.md section 4 (the wire)


## The line of [param card] in [param state].
static func of(card: WireCardData, state: GameState) -> String:
	match card.kind:
		&"lab_idle", &"research_done":
			return _tr(&"WIRE_LINE_LAB").format({"n": _count(state, &"role_scientist")})
		&"candidate_waiting":
			return _candidate(state)
		&"phone_call":
			return _caller(state)
		&"request_offered", &"new_research":
			return card.detail
		&"incoming_call":
			return _tr(&"WIRE_LINE_INCOMING")
	return ""


static func _count(state: GameState, role: StringName) -> int:
	return state.staff.people.filter(func(p: PersonState) -> bool: return p.role == role).size()


static func _candidate(state: GameState) -> String:
	var count: int = state.recruitment.candidates.size()
	if count == 0:
		return ""
	return _tr(&"WIRE_LINE_CANDIDATES").format({"n": count})


static func _caller(state: GameState) -> String:
	var index: int = ContactRules.next_pending(state, &"phone")
	if index < 0:
		return ""
	var faction_id: StringName = state.factions.pending[index].faction
	var faction: FactionDef = state.faction_defs.get(faction_id)
	return String(faction_id) if faction == null else _tr(faction.name_key)


static func _tr(key: StringName) -> String:
	return TranslationServer.translate(key)
