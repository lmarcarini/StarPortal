class_name AppearanceRules
extends RefCounted
## The appearance record of a staff member (docs/content/portraits.md, "The appearance
## record"): plain data rolled once from a seeded generator, saved with the person, and drawn
## by the UI. Same generator state, same record. The option lists and weights follow the
## prototype's make_person() (tools/portraits/pixel_portraits.py): no full beard on young
## staff, grey hair likely on older staff, glasses likelier in a lab coat or shirt and tie.
## Saved shape: {"sex", "age", "skin", "hair_colour", "eye_colour", "head", "face_width",
## "jaw", "eyes", "brows", "nose", "mouth", "facial_hair", "hair", "accessory", "field",
## "variant"}; "skin", "hair_colour" and "eye_colour" are palette indices, "face_width" an
## offset from -1 to 1, every other value a string from its list.
## Bible: docs/content/portraits.md

## Sexes.
const SEXES: Array[String] = ["female", "male"]
## Chance (out of 100) that a record is female, as in the prototype (0.45).
const FEMALE_PERCENT: int = 45
## Ages, weighted adult twice.
const AGES: Array[String] = ["young", "adult", "older"]
const AGE_WEIGHTS: Array[int] = [1, 2, 1]
## Skin tones (palette indices 0..5).
const SKIN_TONES: int = 6
## Hair colours: indices 0..8 are natural, 9..11 the greys.
const HAIR_COLOURS: int = 12
const NATURAL_HAIR_COLOURS: int = 9
## Eye colours (palette indices 0..4).
const EYE_COLOURS: int = 5
## Chance (out of 100) that older staff go grey; then (out of 100) that a man's hair recedes.
const GREY_PERCENT: int = 65
const RECEDE_PERCENT: int = 40
## Chance (out of 100) of glasses in a GLASSES_VARIANTS uniform.
const GLASSES_PERCENT: int = 40
const GLASSES_VARIANTS: Array[String] = ["labcoat", "shirt_tie"]
const HEADS: Array[String] = ["round", "oval", "square", "long"]
const JAWS: Array[String] = ["narrow", "broad", "angular"]
const EYES: Array[String] = ["small", "round", "narrow"]
const BROWS: Array[String] = ["straight", "angled", "thick"]
const NOSES: Array[String] = ["short", "long", "wide"]
const MOUTHS: Array[String] = ["thin", "wide", "neutral"]
const ACCESSORIES: Array[String] = ["none", "glasses", "patch", "scar"]
const ACCESSORY_WEIGHTS: Array[int] = [12, 3, 1, 2]
const FACIAL_HAIR: Array[String] = ["none", "stubble", "moustache", "beard"]
const FACIAL_HAIR_WEIGHTS: Array[int] = [6, 2, 1, 2]
## Every hair style; women draw from FEMALE_HAIR, men from MALE_HAIR (military twice).
const HAIR: Array[String] = [
	"military", "buzz", "side", "messy", "curly", "receding", "bald", "long", "ponytail", "bun"
]
const FEMALE_HAIR: Array[String] = ["ponytail", "long", "curly", "bun", "side", "messy", "military"]
const MALE_HAIR: Array[String] = [
	"military", "military", "buzz", "side", "messy", "curly", "receding", "bald"
]
## Uniform variants by field.
const VARIANTS: Dictionary[String, Array] = {
	"military": ["standard", "officer", "expedition", "casual", "command"],
	"science": ["labcoat", "shirt_tie", "overalls", "casual"],
	"engineering": ["coverall", "vest", "jacket", "casual"],
	"office": ["suit", "shirt_tie", "sweater", "blazer"],
	"medicine": ["scrubs", "labcoat", "fatigues"],
}
## The field (uniform and accent colour) of each role.
const ROLE_FIELDS: Dictionary[StringName, String] = {
	StartingStaff.SCIENTIST: "science",
	StartingStaff.ENGINEER: "engineering",
	StartingStaff.ANALYST: "office",
	StartingStaff.SOLDIER: "military",
	StartingStaff.MEDIC: "medicine",
}
## Field of a role with no entry in ROLE_FIELDS.
const DEFAULT_FIELD: String = "office"
## Keys whose value is a string from a list, with that list.
const _STRING_FIELDS: Dictionary[String, Array] = {
	"sex": SEXES,
	"age": AGES,
	"head": HEADS,
	"jaw": JAWS,
	"eyes": EYES,
	"brows": BROWS,
	"nose": NOSES,
	"mouth": MOUTHS,
	"facial_hair": FACIAL_HAIR,
	"hair": HAIR,
	"accessory": ACCESSORIES,
}
## Keys whose value is a palette index, with the palette size.
const _INDEX_FIELDS: Dictionary[String, int] = {
	"skin": SKIN_TONES, "hair_colour": HAIR_COLOURS, "eye_colour": EYE_COLOURS
}


## The field of [param role] (scientist: "science"); [constant DEFAULT_FIELD] when unknown.
static func field_for_role(role: StringName) -> String:
	return ROLE_FIELDS.get(role, DEFAULT_FIELD)


## A record for someone of [param field] drawn with [param rng] only. An unknown field rolls
## as [constant DEFAULT_FIELD]. Same generator state, same record.
static func roll(rng: RandomNumberGenerator, field: String) -> Dictionary:
	var uniform_field: String = field if VARIANTS.has(field) else DEFAULT_FIELD
	var female: bool = rng.randi_range(1, 100) <= FEMALE_PERCENT
	var record: Dictionary = {
		"sex": SEXES[0] if female else SEXES[1],
		"age": _weighted(rng, AGES, AGE_WEIGHTS),
		"skin": rng.randi_range(0, SKIN_TONES - 1),
		"hair_colour": rng.randi_range(0, NATURAL_HAIR_COLOURS - 1),
		"eye_colour": rng.randi_range(0, EYE_COLOURS - 1),
		"head": _pick(rng, HEADS),
		"face_width": rng.randi_range(-1, 1),
		"jaw": _pick(rng, JAWS),
		"eyes": _pick(rng, EYES),
		"brows": _pick(rng, BROWS),
		"nose": _pick(rng, NOSES),
		"mouth": _pick(rng, MOUTHS),
		"accessory": _weighted(rng, ACCESSORIES, ACCESSORY_WEIGHTS),
		"field": uniform_field,
	}
	_roll_hair(rng, record, female)
	var variants: Array = VARIANTS[uniform_field]
	record["variant"] = str(variants[rng.randi_range(0, variants.size() - 1)])
	if record["variant"] in GLASSES_VARIANTS and rng.randi_range(1, 100) <= GLASSES_PERCENT:
		record["accessory"] = "glasses"
	return record


## A record for [param field] from a generator seeded with [param seed_text] (the fixed
## starting crew and first candidate list, which have no stream draw).
static func roll_seeded(seed_text: String, field: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	return roll(rng, field)


## Human-readable errors of saved [param record], empty when valid: every key present, the
## string fields from their lists, the palette indices in range, "face_width" from -1 to 1,
## "variant" one of its "field"'s variants.
static func validate(record: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in _STRING_FIELDS:
		var options: Array = _STRING_FIELDS[key]
		if not (record.get(key) is String and str(record.get(key)) in options):
			errors.append("appearance '%s' is not one of %s" % [key, ", ".join(options)])
	for key: String in _INDEX_FIELDS:
		if not _is_int_in(record.get(key), 0, _INDEX_FIELDS[key] - 1):
			errors.append("appearance '%s' is not a whole number in range" % key)
	if not _is_int_in(record.get("face_width"), -1, 1):
		errors.append("appearance 'face_width' is not -1, 0 or 1")
	var field: Variant = record.get("field")
	if not (field is String and VARIANTS.has(field)):
		errors.append("appearance 'field' is not a known field")
	elif not (record.get("variant") is String and record.get("variant") in VARIANTS[field]):
		errors.append("appearance 'variant' is not a variant of %s" % field)
	return errors


## [param record] with whole floats (from JSON) turned back into ints.
static func from_saved(record: Dictionary) -> Dictionary:
	var out: Dictionary = record.duplicate()
	for key: String in ["skin", "hair_colour", "eye_colour", "face_width"]:
		var value: Variant = out.get(key)
		if value is float:
			var number: float = value
			out[key] = int(number)
	return out


static func _roll_hair(rng: RandomNumberGenerator, record: Dictionary, female: bool) -> void:
	if female:
		record["hair"] = _pick(rng, FEMALE_HAIR)
		record["facial_hair"] = "none"
	else:
		record["hair"] = _pick(rng, MALE_HAIR)
		record["facial_hair"] = _weighted(rng, FACIAL_HAIR, FACIAL_HAIR_WEIGHTS)
	if record["age"] == "older" and rng.randi_range(1, 100) <= GREY_PERCENT:
		record["hair_colour"] = rng.randi_range(NATURAL_HAIR_COLOURS, HAIR_COLOURS - 1)
		if not female and rng.randi_range(1, 100) <= RECEDE_PERCENT:
			record["hair"] = "receding"
	if record["age"] == "young" and record["facial_hair"] == "beard":
		record["facial_hair"] = "stubble"


static func _pick(rng: RandomNumberGenerator, options: Array[String]) -> String:
	return options[rng.randi_range(0, options.size() - 1)]


static func _weighted(
	rng: RandomNumberGenerator, options: Array[String], weights: Array[int]
) -> String:
	var total: int = 0
	for weight: int in weights:
		total += weight
	var roll_value: int = rng.randi_range(1, total)
	for index: int in options.size():
		roll_value -= weights[index]
		if roll_value <= 0:
			return options[index]
	return options[options.size() - 1]


static func _is_int_in(value: Variant, low: int, high: int) -> bool:
	var number: int = 0
	if value is int:
		number = value
	elif value is float:
		var real: float = value
		if real != floorf(real):
			return false
		number = int(real)
	else:
		return false
	return number >= low and number <= high
