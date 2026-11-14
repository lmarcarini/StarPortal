class_name AlertText
extends RefCounted
## The line each alert shows in the list, translated, with names looked up in the content
## and the state.
## Bible: docs/content/interface-pass.md section 3 (Alerts)


## The line of [param entry], with names read from [param state].
static func line(entry: AlertEntry, state: GameState) -> String:
	var values: Dictionary = entry.args.duplicate()
	match entry.kind:
		&"research_done":
			values["name"] = _def_name(entry.target, &"name_key")
		&"request_due":
			values["name"] = _def_name(
				StringName(str(entry.args.get("request_id", ""))), &"title_key"
			)
			var ticks: int = type_convert(entry.args.get("ticks", 0), TYPE_INT)
			values["time"] = TopBarText.time_left(ticks)
		&"artefact_at_gate", &"artefact_hazard":
			values["name"] = _def_name(
				StringName(str(entry.args.get("artefact_id", ""))), &"name_key"
			)
		&"team_check_in":
			values["name"] = AddressBookText.name_of_world(entry.target, state)
		&"funds_red":
			var funds: int = type_convert(entry.args.get("funds", 0), TYPE_INT)
			values["funds"] = MoneyLabel.format_k(funds)
	return TranslationServer.translate(key_of(entry.kind)).format(values)


## The translation key of [param kind].
static func key_of(kind: StringName) -> StringName:
	return StringName("ALERT_" + String(kind).to_upper())


## The status lamp name of [param severity]: good for info, warn, alarm; off for none.
static func lamp_status(severity: StringName) -> StringName:
	match severity:
		AlertEntry.INFO:
			return &"good"
		AlertEntry.WARN:
			return &"warn"
		AlertEntry.ALARM:
			return &"alarm"
	return &"off"


static func _def_name(id: StringName, field: StringName) -> String:
	if id == &"" or not Registry.has_def(id):
		return String(id)
	var def: DefBase = Registry.get_def(id)
	var key: Variant = def.get(field)
	if key == null:
		return String(id)
	return TranslationServer.translate(StringName(str(key)))
