class_name RoomCardText
extends RefCounted
## The room panel's words and numbers (pure): what the room is doing and how far
## ("STUDY THE LOOM", 0.62), its power ("ON · 5 MW", "OFF", "+30 MW"), the staff line
## ("STAFF 2/4 · SPEED 67%") and the people in it.
## Bible: docs/content/interface-reference.md section 8 (room_panel)


## What [param room] is doing and its progress (0 to 1, or -1 for none).
static func work(state: GameState, room: RoomState, def: RoomDef) -> Array:
	if not room.is_built() or room.is_demolishing():
		var site: SiteProgress = SiteProgress.of_room(state, room)
		return [ProgressText.status(site).to_upper(), site.fraction]
	var bench: ResearchBench = state.research.bench_of(room.id)
	if not def.research_discipline.is_empty() and bench != null and bench.is_running():
		var project: ResearchDef = state.research_defs.get(bench.active)
		var name: String = "" if project == null else _tr(project.name_key)
		return [name.to_upper(), ResearchSpeed.progress(state, room.id)]
	return ["", -1.0]


## "ON · 5 MW", "OFF · 5 MW", "+30 MW" or "" for [param room] of [param def].
static func power(room: RoomState, def: RoomDef) -> String:
	if def.power_output_mw > 0.0:
		return "+%d MW" % roundi(def.power_output_mw)
	if def.power_draw_mw <= 0.0:
		return ""
	var on: String = _tr(&"BASE_POWER_ON" if room.powered_on else &"BASE_POWER_OFF")
	return "%s · %d MW" % [on, roundi(def.power_draw_mw)]


## The people working in [param room].
static func people(state: GameState, room: RoomState) -> Array[PersonState]:
	var out: Array[PersonState] = []
	for person: PersonState in state.staff.people:
		if person.room_id == room.id:
			out.append(person)
	return out


## "STAFF 2/4 · SPEED 67%" (the speed only for a research building), or "" for a room without slots.
static func staff(state: GameState, room: RoomState, def: RoomDef) -> String:
	if def.staff_slots <= 0:
		return ""
	var line: String = _tr(&"BASE_STAFF_LINE").format(
		{"n": people(state, room).size(), "of": def.staff_slots}
	)
	if not def.research_discipline.is_empty():
		line += " · " + _tr(&"BASE_SPEED").format({"pct": ResearchSpeed.percent(state, room)})
	return line


static func _tr(key: StringName) -> String:
	return TranslationServer.translate(key)
