class_name TargetStates
extends RefCounted
## Saved state of world targets that changes in play: which objects a MOTH Close look marked
## recoverable and which a team has recovered. Kept here, in the saved world state, never on
## the shared WorldTarget data. A target with no entry is neither. A state only goes up.
## Saved shape: {world id: {target id: "recoverable" | "recovered"}}.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (Close look) and section 4 (Recover)

## How far a target has come; NONE is never stored.
enum State { NONE, RECOVERABLE, RECOVERED }

## Saved names of the states, indexed by State value.
const STATE_NAMES: Array[String] = ["none", "recoverable", "recovered"]

## By world id: {target id (StringName): State}.
var by_world: Dictionary[StringName, Dictionary] = {}


## The state of [param target_id] on [param world_id]; NONE when none is stored.
func state_of(world_id: StringName, target_id: StringName) -> State:
	var targets: Dictionary = by_world.get(world_id, {})
	return targets.get(target_id, State.NONE)


## True when [param target_id] on [param world_id] is recoverable and not yet recovered: a
## Recover may try it (again, after a failed attempt).
func is_recoverable(world_id: StringName, target_id: StringName) -> bool:
	return state_of(world_id, target_id) == State.RECOVERABLE


## Raises [param target_id] on [param world_id] to [param state]; false, changing nothing,
## when it is not higher. Call through WorldProgress.raise_target().
func raise(world_id: StringName, target_id: StringName, state: State) -> bool:
	if world_id.is_empty() or target_id.is_empty() or state <= state_of(world_id, target_id):
		return false
	if not by_world.has(world_id):
		by_world[world_id] = {}
	by_world[world_id][target_id] = state
	return true


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	var data: Dictionary = {}
	for world_id: StringName in by_world:
		var targets: Dictionary = {}
		for target_id: StringName in by_world[world_id]:
			targets[String(target_id)] = STATE_NAMES[by_world[world_id][target_id]]
		data[String(world_id)] = targets
	return data


## Builds the states from saved [param data]; unreadable entries are dropped.
static func from_dict(data: Dictionary) -> TargetStates:
	var states := TargetStates.new()
	for world_id: Variant in data:
		if not data[world_id] is Dictionary:
			continue
		var targets: Dictionary = data[world_id]
		for target_id: Variant in targets:
			var state: int = STATE_NAMES.find(str(targets[target_id]))
			if state > State.NONE:
				states.raise(StringName(str(world_id)), StringName(str(target_id)), state as State)
	return states


## Errors for saved [param data], empty when valid: non-empty world and target ids, each state
## "recoverable" or "recovered".
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for world_id: Variant in data:
		if str(world_id).is_empty() or not data[world_id] is Dictionary:
			errors.append("targets of '%s' are not an object of a world id" % world_id)
			continue
		var targets: Dictionary = data[world_id]
		for target_id: Variant in targets:
			var state: Variant = targets[target_id]
			if str(target_id).is_empty():
				errors.append("a target of '%s' has an empty id" % world_id)
			elif not state is String or STATE_NAMES.find(state) <= State.NONE:
				errors.append(
					"target %s/%s is not one of %s" % [world_id, target_id, STATE_NAMES.slice(1)]
				)
	return errors
