class_name ArchiveLogRow
extends Button
## One operations log entry: the in-game date and time, its kind as an icon (and as the
## tooltip), one translated line (the row growing to fit
## a line that wraps) ("Dialed: No gate", "Locked SILL", "Received: Order No. 1") and,
## for a dial, the address as glyphs. The row is a focusable button so a gamepad can step
## through (and scroll) the log; pressing it does nothing. The static helpers word an entry for
## the row and for the search.
## Bible: game-design.md#core-loop (Archive: the operations log)

## Kind filter keys, in [constant LogEntry.KINDS] order.
const KIND_KEYS: Array[StringName] = [
	&"LOG_KIND_DIAL",
	&"LOG_KIND_LOCK",
	&"LOG_KIND_CLOSE",
	&"LOG_KIND_DOCUMENT",
	&"LOG_KIND_CONSOLE",
	&"LOG_KIND_HORIZON",
	&"LOG_KIND_POWER",
	&"LOG_KIND_RESEARCH",
	&"LOG_KIND_STAFF",
	&"LOG_KIND_COMMITTEE",
]
## Height of a row of one line, and what each extra line adds.
const _ROW_HEIGHT: float = 52.0
const _LINE_HEIGHT: float = 22.0
## Line keys of the close reasons.
const _CLOSE_KEYS: Dictionary[String, StringName] = {
	"player": &"LOG_LINE_CLOSE_PLAYER",
	"timeout": &"LOG_LINE_CLOSE_TIMEOUT",
	"power": &"LOG_LINE_CLOSE_POWER",
}

var _entry: LogEntry = null
var _state: GameState = null
## Lower-case search_text() of the entry, in the current locale.
var _search: String = ""

@onready var _date: Label = %Date
@onready var _icon: LogKindIcon = %Icon
@onready var _line: Label = %Line
@onready var _strip: AddressStrip = %Strip


func _ready() -> void:
	_show()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _entry != null:
		_search = search_text(_entry, _state).to_lower()
		_show()


## Shows [param entry]; world names come from [param state] (may be null).
func setup(entry: LogEntry, state: GameState) -> void:
	_entry = entry
	_state = state
	_search = search_text(entry, state).to_lower()
	if is_node_ready():
		_show()


## Returns the entry shown.
func get_entry() -> LogEntry:
	return _entry


## True when the entry is of [param kind] (any kind when empty) and its search text contains
## [param query] (lower case; anything when empty).
func matches(kind: StringName, query: String) -> bool:
	if _entry == null or (not kind.is_empty() and _entry.kind != kind):
		return false
	return query.is_empty() or _search.contains(query)


## Returns the line shown.
func get_line_text() -> String:
	return _line.text


## Returns the translated line of [param entry], naming worlds from [param state].
static func line_for(entry: LogEntry, state: GameState) -> String:
	var world: String = _world_name(entry.world_id, state)
	match entry.kind:
		&"dial":
			var outcome: int = DialOutcome.from_key(StringName(str(entry.args.get("outcome", ""))))
			return _tr(&"LOG_LINE_DIAL").format({"outcome": GateRoomFormat.outcome_name(outcome)})
		&"lock":
			var key: StringName = &"LOG_LINE_LOCK"
			if entry.args.get("hostile", false) == true:
				key = &"LOG_LINE_LOCK_HOSTILE"
			return _tr(key).format({"world": world})
		&"close":
			var reason: String = str(entry.args.get("reason", "player"))
			var close_key: StringName = _CLOSE_KEYS.get(reason, &"LOG_LINE_CLOSE_PLAYER")
			return _tr(close_key).format({"world": world})
		&"document":
			var id: StringName = StringName(str(entry.args.get("document_id", "")))
			var title: String = DocumentText.title(Registry.get_def(id) as DocumentDef)
			return _tr(&"LOG_LINE_DOCUMENT").format({"title": title})
		&"console":
			return _tr(&"LOG_LINE_CONSOLE").format({"world": world})
		&"horizon":
			return _tr(&"LOG_LINE_HORIZON").format({"world": world})
		&"power":
			if entry.args.has("room"):
				return finished_room_line(entry.args)
			var capacity: float = type_convert(entry.args.get("capacity_mwh", 0), TYPE_FLOAT)
			return _tr(&"LOG_LINE_POWER").format({"capacity": GateRoomFormat.energy(capacity)})
		&"research":
			var project: ResearchDef = (
				Registry.get_def(StringName(str(entry.args.get("project_id", "")))) as ResearchDef
			)
			if project == null:
				return ""
			var line: String = _tr(&"LOG_LINE_RESEARCH").format(
				{"name": _tr(project.name_key), "line": _tr(project.line_key)}
			)
			var level: int = first_dug_level(project.id)
			if level > 0:
				line += " " + _tr(&"LOG_LINE_RESEARCH_DIG").format({"n": level})
			return line
		&"staff":
			return staff_line(entry.args)
		&"committee":
			return CommitteeText.log_line(entry.args)
		&"expedition":
			return ExpeditionLogText.line(entry.args, world)
	return ""


## The line of a "staff" entry's [param args]: "Research Lab staffed: 2 scientists." for the
## first room of a type, "Staff unassigned from Workshop: 2." for a room coming down.
static func staff_line(args: Dictionary) -> String:
	if str(args.get("reason", "")) == "arrived":
		return arrival_line(args)
	if str(args.get("reason", "")) == "lent":
		return _tr(&"LOG_LINE_STAFF_LENT").format(
			{
				"name": str(args.get("name", "")),
				"skill": type_convert(args.get("skill", 0), TYPE_INT)
			}
		)
	var def: RoomDef = Registry.get_def(StringName(str(args.get("room", "")))) as RoomDef
	var room: String = "" if def == null else _tr(def.name_key)
	var count: int = type_convert(args.get("count", 0), TYPE_INT)
	if str(args.get("reason", "")) != String(StaffChanges.AUTO_ASSIGNED):
		return _tr(&"LOG_LINE_STAFF_RELEASED").format({"room": room, "count": count})
	var role: RoleDef = null if def == null else Registry.get_def(def.staff_role) as RoleDef
	var people: String = str(count)
	if role != null:
		people = _tr(role.count_one_key if count == 1 else role.count_key).format({"count": count})
	return _tr(&"LOG_LINE_STAFFED").format({"room": room, "people": people})


## The line of a hired person's arrival: "Dr Ana Ferreira (Scientist, skill 4) has arrived."
static func arrival_line(args: Dictionary) -> String:
	var role: RoleDef = Registry.get_def(StringName(str(args.get("role", "")))) as RoleDef
	return (
		_tr(&"LOG_LINE_STAFF_ARRIVED")
		. format(
			{
				"name": str(args.get("name", "")),
				"role": "" if role == null else _tr(role.name_key),
				"skill": type_convert(args.get("skill", 0), TYPE_INT),
			}
		)
	)


## The line of a finished room's "power" entry [param args]: charging lowered for it, or it
## stayed off with the refusal reason; or, with "rooms_off", a plant gone off and what its supply
## took (also the Base tab's message line).
static func finished_room_line(args: Dictionary) -> String:
	var def: RoomDef = Registry.get_def(StringName(str(args.get("room", "")))) as RoomDef
	var room: String = "" if def == null else _tr(def.name_key)
	if args.has("rooms_off"):
		var off: int = type_convert(args["rooms_off"], TYPE_INT)
		if off > 0:
			return _tr(&"BASE_MSG_SUPPLY_ROOMS_OFF").format({"room": room, "n": off})
		return _tr(&"BASE_MSG_SUPPLY_CHARGING").format(
			{"room": room, "mw": args.get("charge_mw", 0)}
		)
	if args.has("charge_mw"):
		return _tr(&"BASE_MSG_CHARGING_LOWERED").format({"room": room, "mw": args["charge_mw"]})
	var reason: String = _tr(&"BASE_POWER_REFUSED_SPARE").format(
		{"need": args.get("need_mw", 0), "spare": args.get("spare_mw", 0)}
	)
	return _tr(&"BASE_MSG_FINISHED_OFF").format({"room": room, "reason": reason})


## Returns the text the search matches for [param entry]: its line, its kind's name and, for a
## dial, the glyph names of its address.
static func search_text(entry: LogEntry, state: GameState) -> String:
	var parts: PackedStringArray = [line_for(entry, state), _tr(kind_key(entry.kind))]
	var address: GateAddress = address_of(entry)
	if address != null:
		parts.append(GateRoomFormat.address_text(address))
	return " ".join(parts)


## Returns the filter key of [param kind]; empty for an unknown kind.
static func kind_key(kind: StringName) -> StringName:
	var index: int = LogEntry.KINDS.find(kind)
	return KIND_KEYS[index] if index >= 0 else &""


## Returns the dialed address of a "dial" [param entry], or null.
static func address_of(entry: LogEntry) -> GateAddress:
	var key: String = str(entry.args.get("address", ""))
	if entry.kind != &"dial" or not AddressEntry.is_valid_key(key):
		return null
	var seals: Array[int] = AddressEntry.glyphs_of(key)
	var origin: int = seals.pop_back()
	return GateAddress.create(seals, origin)


func _show() -> void:
	if _entry == null:
		return
	_date.text = GateRoomFormat.date_time(_entry.tick)
	_icon.kind = _entry.kind
	tooltip_text = tr(kind_key(_entry.kind))
	_line.text = line_for(_entry, _state)
	var extra_lines: int = _line.text.count("\n")
	custom_minimum_size.y = _ROW_HEIGHT + _LINE_HEIGHT * extra_lines
	var address: GateAddress = address_of(_entry)
	_strip.visible = address != null
	_strip.setup(address)


static func _world_name(world_id: StringName, state: GameState) -> String:
	if world_id.is_empty():
		return _tr(&"GATE_WORMHOLE_UNNAMED")
	return AddressBookText.name_of_world(world_id, state)


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))


## The first level research project [param project_id] lets the player dig (one past the
## deepest any other project allows below its own depth), or 0 when it digs nothing.
## Bible: docs/content/m25-lean-start.md section 3
static func first_dug_level(project_id: StringName) -> int:
	var depth: int = _dig_depth(project_id)
	if depth == 0:
		return 0
	var below: int = 1
	for other: StringName in UnlockRules.PROJECTS:
		var other_depth: int = _dig_depth(other)
		if other_depth < depth:
			below = maxi(below, other_depth)
	return below + 1


static func _dig_depth(project_id: StringName) -> int:
	for pair: Array in UnlockRules.PROJECTS.get(project_id, []):
		if pair[0] == UnlockRules.EFFECT_DIG_DEPTH:
			return type_convert(pair[1], TYPE_INT)
	return 0
