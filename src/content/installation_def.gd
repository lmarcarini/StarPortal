class_name InstallationDef
extends DefBase
## An upgrade fitted to a room or a blast door (M4c-18): unlocked by research, then built
## from the room's panel for money and time like a small site. It works while its host room
## is on and not damaged; its modifiers then join the modifier totals.
## Bible: docs/content/m4c-incursions.md section 6

## Host value meaning a blast door.
const DOOR_HOST: StringName = &"door"

## Name and what it does (translation keys).
@export var name_key: StringName = &""
@export var effect_key: StringName = &""
## RoomDef ids it can be fitted to, or [constant DOOR_HOST]; empty means any room except
## corridors, lifts and stairs.
@export var hosts: Array[StringName] = []
## The research project that unlocks it; &"" when none is needed.
@export var requires_research: StringName = &""
## Price in $k and build time in ticks.
@export var cost_k: int = 0
@export var build_ticks: int = 60
## How many of it one host can carry.
@export var max_per_host: int = 1
## Health for installations that can be destroyed (sentry guns); 0 when they cannot.
@export var health: int = 0
## Lasting effects while active (ModifierEffects).
@export var effects: Array[EffectDef] = []


## The research project and the room hosts.
func get_references() -> Array[StringName]:
	var found: Array[StringName] = []
	if not requires_research.is_empty():
		found.append(requires_research)
	for host: StringName in hosts:
		if host != DOOR_HOST:
			found.append(host)
	return found


## Problems: no name, negative cost, build ticks or max per host below 1, a host that is not
## a RoomDef, research that is not a ResearchDef.
func get_content_errors(defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = []
	if name_key.is_empty():
		errors.append("needs name_key")
	if cost_k < 0 or build_ticks < 1 or max_per_host < 1 or health < 0:
		errors.append("needs cost_k >= 0, build_ticks >= 1, max_per_host >= 1, health >= 0")
	for host: StringName in hosts:
		if host != DOOR_HOST and defs.has(host) and not defs[host] is RoomDef:
			errors.append("host %s is not a RoomDef" % host)
	if defs.has(requires_research) and not defs[requires_research] is ResearchDef:
		errors.append("%s is not a ResearchDef" % requires_research)
	return errors


## True when it can be fitted to a blast door.
func fits_door() -> bool:
	return hosts.has(DOOR_HOST)


## True when it can be fitted to a room of [param room_def_id].
func fits_room(room_def_id: StringName) -> bool:
	if hosts.is_empty():
		return not BasePaths.HALLS.has(room_def_id)
	return hosts.has(room_def_id)
