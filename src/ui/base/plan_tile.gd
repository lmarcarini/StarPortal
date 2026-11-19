class_name PlanTile
extends RefCounted
## What one room tile on the Base plan shows (pure, from the state): its def, name, state
## (&"on", &"off", &"site"), the Ring for the Gate Room, a site's progress and caption, and its
## staff slots with the role letters of the people in them.
## Bible: docs/content/interface-reference.md section 8

var def_id: StringName = &""
var name: String = ""
var state: StringName = &"off"
var gate: bool = false
var progress: float = 0.0
var caption: String = ""
var slots: int = 0
var letters: Array[String] = []


## The tile of [param room] built from [param def] in [param state_now], with [param site]
## (SiteProgress or null).
static func of(room: RoomState, def: RoomDef, state_now: GameState, site: SiteProgress) -> PlanTile:
	var tile: PlanTile = PlanTile.new()
	tile.def_id = room.def_id
	tile.name = TranslationServer.translate(def.name_key).to_upper()
	var plan_state: StringName = BasePlanPainter.state_of(room, def)
	tile.state = {BasePlanPainter.ON: &"on", BasePlanPainter.OFF: &"off"}.get(plan_state, &"site")
	tile.gate = room.def_id == &"room_gate"
	if site != null:
		tile.progress = clampf(site.fraction, 0.0, 1.0)
		tile.caption = "%s · %s" % [tile.name, ProgressText.caption(site).to_upper()]
	tile.slots = def.staff_slots
	if state_now != null:
		for person: PersonState in state_now.staff.people:
			if person.room_id == room.id and tile.letters.size() < tile.slots:
				tile.letters.append(_letter(person.role))
	return tile


static func _letter(role: StringName) -> String:
	var def: RoleDef = Registry.get_def(role) as RoleDef
	var text: String = String(role) if def == null else TranslationServer.translate(def.name_key)
	return text.left(1).to_upper()
