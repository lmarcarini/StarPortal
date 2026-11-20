class_name ResearchPerks
extends RefCounted
## The flags research sets to switch on a new verb or plan (M7: research-and-progression.md
## section 10), read by the rules they change. Pure.
## Bible: docs/content/research-and-progression.md section 10

## E10: the blast door plan.
const BLAST_DOOR: StringName = &"plan_blast_door"
## The BUILD tray's id of the blast door (BuildPalette.DOOR_ID).
const DOOR_ID: StringName = &"blast_door"
## E14: a stopped wave costs no charge.
const SHUTTER_MK2: StringName = &"shutter_mk2"
## E17: the MOTH relays a hail.
const MOTH_RELAY: StringName = &"moth_relay"
## E19: teams can stay up to twice as long.
const FIELD_CAMP: StringName = &"field_camp"
## S01: the charge gauge marks what a dial needs.
const GATE_CALIBRATION: StringName = &"gate_calibration"
## S02: the pole camera brings a world picture and its sky.
const HORIZON_PHOTOGRAPHY: StringName = &"horizon_photography"
## S03: a world's hazards are known on lock.
const ATMOSPHERIC_SAMPLING: StringName = &"atmospheric_sampling"
## S04: the alien panel marks glyphs seen in the clipped document.
const GLYPH_FREQUENCY: StringName = &"glyph_frequency"
## S06: incoming wormholes show their origin; warnings show their objective.
const ORIGIN_TRACING: StringName = &"origin_tracing"
## S09: alien text in documents is partly translated.
const XENOLINGUISTICS: StringName = &"xenolinguistics"
## S11 prefix: "envoys_<faction>" gives that faction's daily favour.
const ENVOYS_PREFIX: String = "envoys_"


## True when research has set [param flag] in [param state].
static func has(state: GameState, flag: StringName) -> bool:
	return state != null and state.flags.get(flag, false) == true


## The rooms the BUILD tray offers in [param state]: its unlocked rooms, and the blast door
## once its plan is known.
static func plans(state: GameState) -> Array[StringName]:
	var found: Array[StringName] = state.unlocks.rooms.duplicate()
	if has(state, BLAST_DOOR):
		found.append(DOOR_ID)
	return found
