class_name SlotText
extends RefCounted
## Pure formatting of a save list row: the slot name, in-game date, real date and version, or
## why the slot can't be loaded.
## Bible: docs/bible/technical-architecture.md#save-and-load (M4.6-02)


## "quicksave · 2026-01-03 14:00 · saved 2026-11-14 10:22 · v18" for a list_all_slots()
## [param entry]; an unusable one ends "· can't load: <reason>".
static func row(entry: Dictionary) -> String:
	var slot: String = str(entry.get("slot", ""))
	var unix: int = type_convert(entry.get("saved_at_unix", 0), TYPE_INT)
	var saved: String = real_date(unix)
	var error: StringName = StringName(str(entry.get("error", "")))
	if error != &"":
		return (
			"%s · %s · %s"
			% [
				slot,
				saved,
				TranslationServer.translate(&"SAVES_CANT_LOAD").format({"why": reason(error)})
			]
		)
	var tick: int = type_convert(entry.get("tick", 0), TYPE_INT)
	var version: int = type_convert(entry.get("format_version", 0), TYPE_INT)
	return "%s · %s · %s · v%d" % [slot, GateRoomFormat.date_time(tick), saved, version]


## "saved 2026-11-14 10:22" (local time) for [param unix] seconds.
static func real_date(unix: int) -> String:
	var bias: int = type_convert(Time.get_time_zone_from_system().get("bias", 0), TYPE_INT) * 60
	var text: String = Time.get_datetime_string_from_unix_time(unix + bias, true)
	return TranslationServer.translate(&"SAVES_SAVED_AT").format({"when": text.substr(0, 16)})


## The words for a load failure [param error_code].
static func reason(error_code: StringName) -> String:
	match error_code:
		&"newer_format_version", &"newer_version":
			return TranslationServer.translate(&"SAVES_NEWER")
		&"old_format_version":
			return TranslationServer.translate(&"UI_LOAD_OLD_SAVE")
	return TranslationServer.translate(&"SAVES_BROKEN")
