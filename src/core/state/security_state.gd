class_name SecurityState
extends RefCounted
## The base's defenders (M4c): its squads, one per Security Post with soldiers, and each
## soldier's fighting health by person id (absent = full).
## Saved shape: {"squads": [SquadState], "health": {person id: int}}.
## Bible: docs/content/m4c-incursions.md sections 2 and 9

## Saved keys, in to_dict() order.
const KEYS: Array[String] = ["squads", "health"]

## Squads in post order.
var squads: Array[SquadState] = []
## Health of soldiers who have been hit, by person id.
var health: Dictionary[StringName, int] = {}


## The squad of Security Post [param room_id], or null.
func squad_of(room_id: StringName) -> SquadState:
	for squad: SquadState in squads:
		if squad.post_room == room_id:
			return squad
	return null


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var squad_data: Array = []
	for squad: SquadState in squads:
		squad_data.append(squad.to_dict())
	return {"squads": squad_data, "health": SaveFields.write_int_map(health)}


## Builds one from valid saved [param data].
static func from_dict(data: Dictionary) -> SecurityState:
	var state := SecurityState.new()
	for item: Dictionary in SaveFields.dicts_in(data.get("squads")):
		state.squads.append(SquadState.from_dict(item))
	state.health = SaveFields.read_int_map(data.get("health"))
	return state


## Errors of saved [param data]; two squads cannot share a post.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	errors.append_array(
		SaveFields.record_list_errors(data["squads"], "squads", SquadState.validate_dict)
	)
	errors.append_array(SaveFields.int_map_errors(data["health"], "health", false))
	if errors.is_empty():
		var posts: Array[StringName] = []
		for squad: SquadState in SecurityState.from_dict(data).squads:
			if posts.has(squad.post_room):
				errors.append("two squads share post %s" % squad.post_room)
			posts.append(squad.post_room)
	return errors
