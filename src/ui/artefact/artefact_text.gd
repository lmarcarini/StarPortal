class_name ArtefactText
extends RefCounted
## Words about artefacts in the current locale: names and the hazard line.
## Bible: docs/content/m4-core-systems.md section 5


## "The Kindred Loom's hazard struck." for [param artefact_id].
static func hazard_line(artefact_id: StringName) -> String:
	return String(TranslationServer.translate(&"LOG_LINE_ARTEFACT_HAZARD")).format(
		{"name": StoryText.name_of(artefact_id)}
	)


## "Holding 1/2  At the gate: 1".
static func header(state: GameState) -> String:
	return (
		_tr(&"ARTEFACT_HEADER")
		. format(
			{
				"held": ArtefactRules.holding(state).size(),
				"capacity": ArtefactRules.capacity(state),
				"gate": ArtefactRules.at_gate(state).size(),
			}
		)
	)


## "Kindred Loom (Housed) in Artefact Vault (room 12). While on: research_speed_pct +10.
## Hazard 5 % a day outside Containment."
static func describe(state: GameState, record: ArtefactRecord) -> String:
	var def: ArtefactDef = state.artefact_defs.get(record.artefact)
	var parts: PackedStringArray = [
		(
			"%s (%s), %s"
			% [StoryText.name_of(record.artefact), _state_name(record), where(state, record)]
		)
	]
	if def != null:
		var effects: PackedStringArray = []
		for modifier: ModifierEffect in def.modifiers:
			effects.append(StoryText.preview(modifier))
		if not effects.is_empty():
			parts.append(_tr(&"ARTEFACT_WHILE_ON").format({"effects": ", ".join(effects)}))
		if def.hazard_chance_pct > 0:
			parts.append(_tr(&"ARTEFACT_HAZARD").format({"chance": def.hazard_chance_pct}))
	return ". ".join(parts)


## Where [param record] is: holding, at the gate or a room.
static func where(state: GameState, record: ArtefactRecord) -> String:
	if record.room_uid == ArtefactRecord.AT_GATE:
		return _tr(&"ARTEFACT_AT_GATE")
	if record.room_uid == ArtefactRecord.IN_HOLDING:
		return _tr(&"ARTEFACT_IN_HOLDING")
	return _tr(&"ARTEFACT_IN_ROOM").format({"room": room_name(state, record.room_uid)})


## "Artefact Vault (room 12)".
static func room_name(state: GameState, room_uid: int) -> String:
	var room: RoomState = state.base.find_room(ModifierRules.room_id_of(room_uid))
	var def: RoomDef = null if room == null else state.room_defs.get(room.def_id)
	var name: String = "?" if def == null else _tr(def.name_key)
	return "%s (%d)" % [name, room_uid]


## The words for a refusal code (unknown codes show as themselves).
static func refusal(code: StringName) -> String:
	var key: StringName = StringName("ARTEFACT_REFUSED_" + String(code).to_upper())
	var text: String = _tr(key)
	return String(code) if text == String(key) else text


static func _state_name(record: ArtefactRecord) -> String:
	var keys: Array[StringName] = [
		&"ARTEFACT_STATE_RECOVERED", &"ARTEFACT_STATE_HOUSED", &"ARTEFACT_STATE_STUDIED"
	]
	return _tr(keys[record.state])


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
