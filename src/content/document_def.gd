class_name DocumentDef
extends DefBase
## A hand-made document or object the player can hold in the Archive: a field note, an image, a
## dossier, a captured log, a faction gift or an artefact. Its puzzle, if any, gives an address
## once understood, usually read together with a second document ([member pair_id]).
## [member answer_glyphs] is the puzzle's answer, checked by the Registry; it is never shown.
## Bible: gate-and-address-spec.md#where-addresses-come-from,
## technical-architecture.md#data-model, game-design.md#factions-requests-and-politics

## What the document is. NOTE: field notes and letters. IMAGE: a rubbing, photo or drawing.
## DOSSIER: a government file. LOG: a captured record. GIFT: a faction's gift. ARTEFACT:
## markings on something brought back through the Ring.
enum Kind { NOTE, IMAGE, DOSSIER, LOG, GIFT, ARTEFACT }

## Number of glyphs in an answer: the seven coordinate seals. Content depends on nothing, so
## this repeats GateAddress.COORDINATE_COUNT.
const ANSWER_SIZE: int = 7
## Number of glyphs on a Ring (GateAddress.GLYPH_COUNT).
const GLYPH_COUNT: int = 36

## What the document is.
@export var kind: Kind
## Translation key of the title.
@export var title_key: StringName
## Translation key of the text; &"" for a pure image.
@export var body_key: StringName
## Optional picture; placeholder art for now.
@export var image: Texture2D
## Translation key of who wrote or gave it, e.g. &"DOC_SOURCE_SURVEY_1958".
@export var source_key: StringName
## Id of the WorldDef the document is about, or &"" for none.
@export var world_id: StringName = &""
## The seven coordinate glyphs its puzzle gives, nearest anchor first, or empty when it holds
## no address. Seven distinct glyphs 0..35, none of them CAIRN's origin glyph.
@export var answer_glyphs: PackedInt32Array
## Id of another DocumentDef read together with this one, or &"" for none.
@export var pair_id: StringName = &""


## Returns [member world_id] and [member pair_id] when set, so the Registry reports either
## when it names no loaded definition.
func get_references() -> Array[StringName]:
	var references: Array[StringName] = []
	if not world_id.is_empty():
		references.append(world_id)
	if not pair_id.is_empty():
		references.append(pair_id)
	return references


## Returns errors against every loaded definition [param defs]: [member world_id] must name a
## WorldDef and [member pair_id] another DocumentDef (missing ids are reported as references);
## a non-empty [member answer_glyphs] must be seven distinct glyphs 0..35 without the home
## world's origin glyph, so a home WorldDef must be loaded.
func get_content_errors(defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = []
	if defs.has(world_id) and not defs[world_id] is WorldDef:
		errors.append('world_id "%s" is not a WorldDef' % world_id)
	if pair_id == id:
		errors.append("pair_id names the document itself")
	elif defs.has(pair_id) and not defs[pair_id] is DocumentDef:
		errors.append('pair_id "%s" is not a DocumentDef' % pair_id)
	if not answer_glyphs.is_empty():
		errors.append_array(answer_errors(answer_glyphs, _home_origin(defs)))
	return errors


## Returns errors for answer [param glyphs] against the home Ring's [param home_origin] (-1
## when no home world is loaded): seven distinct glyphs 0..35, none of them the origin.
static func answer_errors(glyphs: PackedInt32Array, home_origin: int) -> Array[String]:
	var errors: Array[String] = []
	if glyphs.size() != ANSWER_SIZE:
		errors.append("answer_glyphs has %d glyphs, not %d" % [glyphs.size(), ANSWER_SIZE])
	for index: int in glyphs.size():
		var glyph: int = glyphs[index]
		if glyph < 0 or glyph >= GLYPH_COUNT:
			errors.append("answer glyph %d is %d, not a glyph from 0 to 35" % [index + 1, glyph])
		elif glyphs.find(glyph) != index:
			errors.append("answer glyph %d repeats glyph %d" % [index + 1, glyph])
		elif glyph == home_origin:
			errors.append("answer glyph %d is CAIRN's origin glyph %d" % [index + 1, glyph])
	if home_origin < 0:
		errors.append("no home world is loaded to check answer_glyphs against")
	return errors


## The origin glyph of the first loaded home WorldDef, or -1 when there is none.
static func _home_origin(defs: Dictionary[StringName, DefBase]) -> int:
	for def: DefBase in defs.values():
		if def is WorldDef and (def as WorldDef).is_home:
			return (def as WorldDef).origin_glyph
	return -1
