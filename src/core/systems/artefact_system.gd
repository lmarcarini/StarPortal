class_name ArtefactSystem
extends SimSystem
## Once a day, each held artefact with a hazard that is not housed in a containment-class room
## rolls its hazard_chance_pct on its own random stream; a hit applies its hazard effects and
## posts artefact_hazard (Log line and a non-pausing message).
## Bible: docs/content/m4-core-systems.md section 5 (Hazard)


## Returns &"artefacts".
func get_id() -> StringName:
	return &"artefacts"


## Nothing per tick.
@warning_ignore("unused_parameter")
func tick(state: GameState) -> void:  # gdlint: ignore=unused-argument
	pass


## The daily hazard rolls, in arrival order; then specimens past their days spoil (M7-03).
func on_day(state: GameState) -> void:
	var rng: RandomNumberGenerator = state.random.stream(get_id())
	for record: ArtefactRecord in state.artefacts.items.duplicate():
		var def: ArtefactDef = state.artefact_defs.get(record.artefact)
		if (
			def == null
			or def.hazard_chance_pct <= 0
			or is_contained(state, record)
			or _controlled(record)
		):
			continue
		if rng.randi_range(0, 99) < def.hazard_chance_pct:
			StoryRules.apply_all(state, def.hazard, def.id)
			state.events.post(&"artefact_hazard", [def.id])
	SpecimenRules.spoil(state)
	XenoPerks.recharge(state)


# A studied artefact's hazard is under control (X01).
static func _controlled(record: ArtefactRecord) -> bool:
	return record.state == ArtefactRecord.ArtefactState.STUDIED


## True when [param record] sits in a room whose class is containment.
static func is_contained(state: GameState, record: ArtefactRecord) -> bool:
	if record.room_uid < 0:
		return false
	var room: RoomState = state.base.find_room(ModifierRules.room_id_of(record.room_uid))
	var def: RoomDef = null if room == null else state.room_defs.get(room.def_id)
	return def != null and def.artefact_class == &"containment"
