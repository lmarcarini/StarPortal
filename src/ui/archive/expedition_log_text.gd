class_name ExpeditionLogText
extends RefCounted
## Words an "expedition" Log entry (docs/content/m3-beyond-the-ring.md section 4) in the
## current locale: a field event (its title and text), "T-1 checked in from STILLWATER (a
## finding): one light injury.", a missed check-in, a
## member who did not survive a rescue, a rescued team, and a lost team ("No answer from T-1."
## when nobody answered the Signal).
## Bible: docs/content/m3-beyond-the-ring.md section 4

## Line key of each reason.
const LINE_KEYS: Dictionary[String, StringName] = {
	"checked_in": &"LOG_LINE_TEAM_CHECKED_IN",
	"missed": &"LOG_LINE_TEAM_MISSED",
	"deceased": &"LOG_LINE_TEAM_DECEASED",
	"rescued": &"LOG_LINE_TEAM_RESCUED",
	"lost": &"LOG_LINE_TEAM_LOST",
	"no_answer": &"LOG_LINE_TEAM_NO_ANSWER",
	"departed": &"LOG_LINE_TEAM_DEPARTED",
	"returned": &"LOG_LINE_TEAM_RETURNED",
}


## The line of an "expedition" entry's [param args] on the world named [param world].
static func line(args: Dictionary, world: String) -> String:
	if str(args.get("reason", "")) == "field_event":
		return field_event_line(args)
	var key: StringName = LINE_KEYS.get(str(args.get("reason", "")), &"")
	if key.is_empty():
		return ""
	return (
		_tr(key)
		. format(
			{
				"world": world,
				"name": str(args.get("name", "")),
				"survivors": type_convert(args.get("survivors", 0), TYPE_INT),
				"injuries": injuries(args),
				"objective":
				_tr(StringName("TEAM_OBJECTIVE_" + str(args.get("objective", "")).to_upper())),
				"team": str(args.get("team", "")),
				"day": _tr(StringName("TEAM_DAY_" + str(args.get("day", "finding")).to_upper())),
			}
		)
	)


## The line of a field event: its title, then its success text (the finding) or its failure
## text naming who rolled: "Thin ice: The ice broke under Dr Ana Reis: a light injury."
static func field_event_line(args: Dictionary) -> String:
	var def: FieldEventDef = FieldEvents.find(StringName(str(args.get("event_id", ""))))
	if def == null:
		return ""
	var part: String = "SUCCESS" if str(args.get("outcome", "")) == "finding" else "FAILURE"
	var text: String = _tr(StringName(def.text_key(part))).format({"name": str(args.get("name"))})
	var injury: StringName = injury_key(def, str(args.get("outcome", "")))
	if not injury.is_empty():
		text = "%s: %s." % [text.trim_suffix("."), _tr(injury)]
	return "%s: %s" % [_tr(StringName(def.text_key("TITLE"))), text]


## The key of the injury a field event actually caused, from the saved [param outcome] ("light"
## or "serious"): FIELD_OUTCOME_MEDIC when a medic turned [param def]'s serious setback light;
## empty for other outcomes.
static func injury_key(def: FieldEventDef, outcome: String) -> StringName:
	if outcome == "serious":
		return &"FIELD_OUTCOME_SERIOUS"
	if outcome != "light":
		return &""
	if def.setback == FieldEventDef.Setback.SERIOUS:
		return &"FIELD_OUTCOME_MEDIC"
	return &"FIELD_OUTCOME_LIGHT"


## The team's injuries in [param args] ("light", "serious"): "one light injury", "no
## injuries", "2 light injuries, one serious injury".
static func injuries(args: Dictionary) -> String:
	var light: int = type_convert(args.get("light", 0), TYPE_INT)
	var serious: int = type_convert(args.get("serious", 0), TYPE_INT)
	var parts: Array[String] = []
	if light > 0:
		parts.append(_count(light, &"TEAM_INJURY_LIGHT"))
	if serious > 0:
		parts.append(_count(serious, &"TEAM_INJURY_SERIOUS"))
	if parts.is_empty():
		return _tr(&"TEAM_INJURY_NONE")
	return ", ".join(parts)


static func _count(count: int, key: StringName) -> String:
	var suffix: String = "_ONE" if count == 1 else ""
	return _tr(StringName(String(key) + suffix)).format({"count": count})


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
