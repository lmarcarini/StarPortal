class_name ActorCues
extends RefCounted
## Which floor cue an event starts at the Gate station. Pure: the floor actors layer plays
## the cue; the simulation never waits for it.
## Bible: docs/content/interface-rethink.md section 2 (Show it happening)

## Cues.
enum Cue {
	NONE, TEAM_OUT, TEAM_IN, MOTH_OUT, MOTH_IN, CANISTER_OUT, CAMERA_PUSH, CRATE, INTRUDERS, SHUTTER
}

## Event name to cue.
const BY_EVENT: Dictionary[StringName, Cue] = {
	&"team_sent": Cue.TEAM_OUT,
	&"team_returned": Cue.TEAM_IN,
	&"team_rescued": Cue.TEAM_IN,
	&"moth_launched": Cue.MOTH_OUT,
	&"moth_recalled": Cue.MOTH_IN,
	&"moth_delivered": Cue.MOTH_IN,
	&"canister_launched": Cue.CANISTER_OUT,
	&"camera_extended": Cue.CAMERA_PUSH,
	&"artefact_arrived": Cue.CRATE,
	&"incursion_breached": Cue.INTRUDERS,
	&"shutter_changed": Cue.SHUTTER,
}
## Real seconds each cue lasts at full motion.
const SECONDS: Dictionary[Cue, float] = {
	Cue.TEAM_OUT: 7.0,
	Cue.TEAM_IN: 7.0,
	Cue.MOTH_OUT: 2.5,
	Cue.MOTH_IN: 2.5,
	Cue.CANISTER_OUT: 3.0,
	Cue.CAMERA_PUSH: 2.0,
	Cue.CRATE: 3.0,
	Cue.INTRUDERS: 5.0,
	Cue.SHUTTER: 1.0,
}
## Seconds a cue takes as a fade when motion is reduced.
const FADE_SECONDS: float = 0.6


## The cue event [param event_name] starts, or NONE.
static func cue_of(event_name: StringName) -> Cue:
	return BY_EVENT.get(event_name, Cue.NONE)


## How long [param cue] runs, with motion [param reduced] or not.
static func duration(cue: Cue, reduced: bool) -> float:
	if reduced:
		return FADE_SECONDS
	return SECONDS.get(cue, 1.0)


## How many figures walk in [param cue] for a team of [param team_size].
static func figures(cue: Cue, team_size: int) -> int:
	match cue:
		Cue.TEAM_OUT, Cue.TEAM_IN:
			return maxi(1, team_size)
		Cue.INTRUDERS:
			return 3
	return 0


## Point at share [param t] (0..1) along [param path].
static func along(path: PackedVector2Array, t: float) -> Vector2:
	if path.is_empty():
		return Vector2.ZERO
	if path.size() == 1:
		return path[0]
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	var want: float = clampf(t, 0.0, 1.0) * total
	for i: int in range(1, path.size()):
		var seg: float = path[i - 1].distance_to(path[i])
		if want <= seg and seg > 0.0:
			return path[i - 1].lerp(path[i], want / seg)
		want -= seg
	return path[path.size() - 1]
