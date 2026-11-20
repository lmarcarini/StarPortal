class_name SpecimenText
extends RefCounted
## Words for a specimen in holding (M7-03): "Plants from SILL · spoils in 4 d", or "kept cold"
## while a cold store runs. Pure.
## Bible: docs/content/research-and-progression.md section 10


## The holding line of [param record] in [param state].
static func line(state: GameState, record: SpecimenRecord) -> String:
	var kind: String = _tr(StringName("SPECIMEN_KIND_" + String(record.kind).to_upper()))
	var head: String = _tr(&"SPECIMEN_FROM").format(
		{"kind": kind, "world": AddressBookText.name_of_world(record.world_id, state)}
	)
	var left: int = SpecimenRules.days_left(state, record)
	var tail: String = (
		_tr(&"SPECIMEN_COLD") if left < 0 else _tr(&"SPECIMEN_SPOILS").format({"days": left})
	)
	return "%s · %s" % [head, tail]


static func _tr(key: StringName) -> String:
	return TranslationServer.translate(key)
