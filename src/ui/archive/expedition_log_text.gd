class_name ExpeditionLogText
extends RefCounted
## Words an "expedition" Log entry (docs/content/m3-beyond-the-ring.md section 4) in the
## current locale: "T-1 checked in from STILLWATER: one light injury.", a missed check-in, a
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
}


## The line of an "expedition" entry's [param args] on the world named [param world].
static func line(args: Dictionary, world: String) -> String:
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
			}
		)
	)


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
