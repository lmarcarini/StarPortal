class_name LabText
extends RefCounted
## Text of the Lab station (interface-reference.md section 9): a tile's status line, the
## panel's GIVES lines and tiles, a bench's header and state, and discipline names and
## icons. Pure: reads the state, never changes it.
## Bible: docs/content/interface-reference.md section 9,
## docs/content/research-and-progression.md section 7

## What a tile's status line shows.
enum Status { DONE, RUNNING, QUEUED, NEW, OPEN }

## Icon of each discipline (tabs, tiles, benches).
const ICONS: Dictionary[StringName, StringName] = {
	&"engineering": &"base",
	&"science": &"lab",
	&"xenotech": &"gear",
	&"office": &"office",
	&"xenobiology": &"specimen",
}
## Short field of the staff each discipline needs ("SCI.").
const FIELD_KEYS: Dictionary[StringName, StringName] = {
	&"engineering": &"LAB_FIELD_ENG",
	&"science": &"LAB_FIELD_SCI",
	&"xenotech": &"LAB_FIELD_SCI",
	&"office": &"LAB_FIELD_ANA",
	&"xenobiology": &"LAB_FIELD_MED",
}
## Most GIVES lines shown.
const MOST_GIVES: int = 3


## The status of [param def]'s tile in [param state].
static func status(state: GameState, def: ResearchDef) -> Status:
	var research: ResearchState = state.research
	if research.is_done(def.id):
		return Status.DONE
	if not research.room_running(def.id).is_empty():
		return Status.RUNNING
	if not research.room_queuing(def.id).is_empty():
		return Status.QUEUED
	if research.is_new(def.id):
		return Status.NEW
	return Status.OPEN


## The tile's status line: "DONE", "62% · 4H LEFT", "QUEUED 1", "NEW" or "1D · $300K".
static func status_line(state: GameState, def: ResearchDef) -> String:
	match status(state, def):
		Status.DONE:
			return _tr(&"LAB_DONE")
		Status.RUNNING:
			return running_line(state, def)
		Status.QUEUED:
			var room: StringName = state.research.room_queuing(def.id)
			var place: int = state.research.bench_of(room).queue.find(def.id) + 1
			return _tr(&"LAB_QUEUED").format({"n": place})
		Status.NEW:
			return _tr(&"LAB_NEW")
	return "%s · %s" % [hours_short(def.hours), money_short(def.cost_k)]


## "62% · 4H LEFT" for the running [param def] ("62% · NO STAFF" when it cannot progress).
static func running_line(state: GameState, def: ResearchDef) -> String:
	var room: RoomState = state.base.find_room(state.research.room_running(def.id))
	if room == null:
		return ""
	var pct: int = floori(ResearchSpeed.progress(state, room.id) * 100.0)
	var left: int = ResearchSpeed.ticks_left(state, room)
	if left < 0:
		return "%d%% · %s" % [pct, _tr(&"LAB_NO_STAFF")]
	return "%d%% · %s" % [pct, _tr(&"LAB_LEFT").format({"time": ResearchText.duration(left)})]


## "4H", "1D" or "2D 6H" for [param hours] (the listed time).
static func hours_short(hours: int) -> String:
	var days: int = hours / 24
	var rest: int = hours % 24
	if days == 0:
		return "%dH" % rest
	if rest == 0:
		return "%dD" % days
	return "%dD %dH" % [days, rest]


## "$300K" or "$1.2M" for [param amount_k] thousand dollars.
static func money_short(amount_k: int) -> String:
	return BaseTableSetup.short_money(amount_k).to_upper()


## "SCIENCE · TIER 3".
static func discipline_line(def: ResearchDef) -> String:
	var tier: String = _tr(&"LAB_TIER").format({"n": def.tier})
	return "%s · %s" % [discipline_name(def.discipline).to_upper(), tier]


## The translated name of [param discipline].
static func discipline_name(discipline: StringName) -> String:
	return _tr(StringName("LAB_DISCIPLINE_" + String(discipline).to_upper()))


## The icon of [param discipline].
static func icon_of(discipline: StringName) -> StringName:
	return ICONS.get(discipline, &"lab")


## What [param def] gives, one short line each (its line split at sentences and "; ").
static func gives(def: ResearchDef) -> Array[String]:
	var found: Array[String] = []
	var text: String = _tr(def.line_key).replace("; ", ". ")
	for part: String in text.split(". ", false):
		var line: String = part.strip_edges().trim_suffix(".")
		if not line.is_empty() and found.size() < MOST_GIVES:
			found.append(line[0].to_upper() + line.substr(1))
	return found


## The panel's tiles of [param def]: [icon, text] for time, cost, staff, and pieces or
## specimens when it spends them.
static func needs_tiles(def: ResearchDef) -> Array[Array]:
	var tiles: Array[Array] = [
		[&"clock", hours_short(def.hours)],
		[&"funds", money_short(def.cost_k)],
		[&"people", "1 " + field(def.discipline)],
	]
	if def.piece_count > 0:
		tiles.append([&"crate", _tr(&"LAB_PIECES").format({"n": def.piece_count})])
	if def.specimen_count > 0:
		tiles.append([&"specimen", _tr(&"LAB_SPECIMENS").format({"n": def.specimen_count})])
	return tiles


## "SCI." for [param discipline]'s staff field.
static func field(discipline: StringName) -> String:
	var key: StringName = FIELD_KEYS.get(discipline, &"LAB_FIELD_SCI")
	return _tr(key)


## The bench's header right: "2/4 SCI." (staff of its field present / slots).
static func staff_line(state: GameState, room: RoomState) -> String:
	var def: RoomDef = state.room_defs.get(room.def_id)
	if def == null:
		return ""
	var present: int = 0
	for person: PersonState in StaffRules.working(state, room):
		if person.role == def.staff_role:
			present += 1
	return "%d/%d %s" % [present, def.staff_slots, field(def.research_discipline)]


## The bench's name: "RESEARCH LAB", "RESEARCH LAB 2" for the second of its kind.
static func bench_name(state: GameState, room: RoomState) -> String:
	var def: RoomDef = state.room_defs.get(room.def_id)
	var name: String = String(room.def_id) if def == null else _tr(def.name_key)
	var number: int = 0
	for other: RoomState in state.base.rooms:
		if other.def_id == room.def_id:
			number += 1
		if other == room:
			break
	return name.to_upper() if number <= 1 else "%s %d" % [name.to_upper(), number]


## Why START or ADD TO QUEUE refused, in plain words.
static func refusal(result: CommandResult, state: GameState) -> String:
	match result.error_code:
		&"bench_busy":
			return _tr(&"LAB_ERR_BENCH_BUSY")
		&"needs_building", &"wrong_building":
			return _tr(&"LAB_ERR_NO_BENCH")
		&"queue_full":
			return _tr(&"LAB_ERR_QUEUE_FULL")
		&"already_queued":
			return _tr(&"LAB_ERR_QUEUED")
		&"needs_pieces":
			return _tr(&"LAB_ERR_PIECES")
		&"needs_specimens":
			return _tr(&"LAB_ERR_SPECIMENS")
	return ResearchText.refusal(result, state)


static func _tr(key: StringName) -> String:
	return TranslationServer.translate(key)
