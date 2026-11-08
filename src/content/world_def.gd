class_name WorldDef
extends DefBase
## An authored Ring-bearing world (CAIRN now; story worlds later), placed in the same space as
## the anchors so its address follows from its position.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## gate-and-address-spec.md#dialing-outcomes-and-energy, technical-architecture.md#data-model

## State of a world's Ring as the dialing side sees it. BURIED and SHIELDED Rings answer a
## dial with Blocked.
enum RingStatus { OPEN, BURIED, SHIELDED }

## What the land looks like; picks the report templates and the scene's terrain.
enum Biome { BARREN, ICE, DESERT, STEPPE, FOREST }
## The air on the far side, as the pole camera samples it.
enum Atmosphere { NONE, THIN, BREATHABLE, TOXIC }
## Background radiation, as the pole camera measures it.
enum Radiation { NORMAL, RAISED, HIGH }
## What a sample canister or a team finds in the soil and water. UNKNOWN is only ever shown,
## never a world's true value.
enum Biohazard { UNKNOWN, NONE, LOW, HIGH }
## What lives there. UNKNOWN is only ever shown, never a world's true value.
enum Life { UNKNOWN, NONE, PLANTS, ANIMALS, PEOPLE }
## What has been built there. UNKNOWN is only ever shown, never a world's true value.
enum Structures { UNKNOWN, NONE, RUINS, WORKED_STONE, SETTLEMENT }
## How dangerous the far side is. UNKNOWN is only ever shown, never a world's true value.
enum Threat { UNKNOWN, LOW, MED, HIGH }
## The colour of the sky over the far Ring, as a picture shows it.
enum SkyColour { BLACK, VIOLET, PALE, BLUE, OVERCAST, OCHRE, GREEN }
## The sun as a picture shows it; HIDDEN behind cloud or below the horizon.
enum Sun { HIDDEN, WHITE, YELLOW, ORANGE, RED }

## Translation key of the world's name.
@export var name_key: StringName
## Position in light years, in the same space as the anchors.
@export var position_ly: Vector3i
## This world's Ring's origin glyph, 0..35.
@export var origin_glyph: int
## State of this world's Ring.
@export var ring_status: RingStatus = RingStatus.OPEN
## True when the far side is guarded: a lock here is a Hostile lock.
@export var is_guarded: bool = false
## True only for CAIRN, the player's home Ring.
@export var is_home: bool = false

## Facts of an authored world (docs/content/m3-beyond-the-ring.md section 3). Procedural worlds
## derive theirs (WorldFactRules); these fields are read only for authored worlds.
@export_group("Facts")
## The land.
@export var biome: Biome = Biome.BARREN
## The air.
@export var atmosphere: Atmosphere = Atmosphere.NONE
## The sky, as the world's dossier describes it.
@export var sky: SkyColour = SkyColour.BLACK
## The sun, as the world's dossier describes it.
@export var sun: Sun = Sun.WHITE
## Surface temperature at the Ring, in whole degrees Celsius.
@export var temperature_c: int = 0
## Background radiation.
@export var radiation: Radiation = Radiation.NORMAL
## True biohazard; never UNKNOWN.
@export var biohazard: Biohazard = Biohazard.NONE
## True life; never UNKNOWN.
@export var life: Life = Life.NONE
## True structures; never UNKNOWN.
@export var structures: Structures = Structures.NONE
## True threat; never UNKNOWN, and HIGH when [member is_guarded].
@export var threat: Threat = Threat.LOW
## Named things a team or the MOTH can go to, in the order a Look around lists them.
@export var targets: Array[WorldTargetDef] = []


## Returns the problems of the authored facts: an UNKNOWN true value, a guarded world whose
## threat is not HIGH, and a target with an empty or repeated id or an empty name key.
func get_content_errors(_defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = []
	var unknowns: Array[bool] = [
		biohazard == Biohazard.UNKNOWN,
		life == Life.UNKNOWN,
		structures == Structures.UNKNOWN,
		threat == Threat.UNKNOWN,
	]
	if unknowns.has(true):
		errors.append("a true fact is UNKNOWN")
	if is_guarded and threat != Threat.HIGH:
		errors.append("a guarded world must have threat HIGH")
	var seen: Dictionary[StringName, bool] = {}
	for target: WorldTargetDef in targets:
		if target == null or target.id.is_empty() or target.name_key.is_empty():
			errors.append("a target needs an id and a name key")
		elif seen.has(target.id):
			errors.append("target %s is repeated" % target.id)
		else:
			seen[target.id] = true
	return errors
