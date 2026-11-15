class_name AfterActionText
extends RefCounted
## The after-action report's lines (M4c-13), from an incursion_ended report: attacker,
## objective, result, damage, artefacts, injuries and the Confidence change.
## Bible: docs/content/m4c-incursions.md section 7


## Every line of [param report].
static func lines(report: Dictionary, state: GameState) -> Array[String]:
	var found: Array[String] = [_tr(&"AAR_ATTACKER").format({"name": attacker(report, state)})]
	var objective: String = str(report.get("objective", ""))
	found.append(
		_tr(&"AAR_OBJECTIVE").format({"name": _tr(StringName("AAR_OBJ_" + objective.to_upper()))})
	)
	found.append(_tr(StringName("AAR_RESULT_" + str(report.get("outcome", "left")).to_upper())))
	var damaged: Array = _list(report, "damaged")
	if not damaged.is_empty():
		var names: PackedStringArray = []
		for room_id: Variant in damaged:
			names.append(_room_name(state, StringName(str(room_id))))
		found.append(_tr(&"AAR_DAMAGED").format({"list": ", ".join(names)}))
	for key: String in ["lost", "recovered"]:
		var items: Array = _list(report, key)
		if not items.is_empty():
			found.append(_tr(StringName("AAR_" + key.to_upper())).format({"count": items.size()}))
	var injured: Array = _list(report, "injured")
	var hurt: Array = _list(report, "hurt")
	if injured.size() + hurt.size() > 0:
		found.append(_tr(&"AAR_INJURED").format({"count": injured.size() + hurt.size()}))
	var change: int = type_convert(report.get("confidence", 0), TYPE_INT)
	found.append(_tr(&"AAR_CONFIDENCE").format({"change": "%+d" % change}))
	return found


## One line for the Log: attacker and result.
static func summary(report: Dictionary, state: GameState) -> String:
	var all: Array[String] = lines(report, state)
	return "%s — %s" % [all[0], all[2]]


## The attacking faction's name.
static func attacker(report: Dictionary, state: GameState) -> String:
	var def: IncursionDef = state.incursion_defs.get(StringName(str(report.get("def", ""))))
	var faction: FactionDef = null if def == null else state.faction_defs.get(def.faction)
	return _tr(faction.name_key) if faction != null else _tr(&"FACTION_UNKNOWN")


# The list under [param key]: an array, or (from the Log) a string joined with ", ".
static func _list(report: Dictionary, key: String) -> Array:
	var value: Variant = report.get(key, [])
	if value is String:
		var text: String = value
		return Array(text.split(", ", false))
	return value if value is Array else []


static func _room_name(state: GameState, room_id: StringName) -> String:
	var room: RoomState = state.base.find_room(room_id)
	var def: RoomDef = null if room == null else state.room_defs.get(room.def_id)
	return _tr(def.name_key) if def != null else String(room_id)


static func _tr(key: StringName) -> String:
	return TranslationServer.translate(key)
