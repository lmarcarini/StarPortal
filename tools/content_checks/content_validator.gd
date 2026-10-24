class_name ContentValidator
extends RefCounted
## Runs every content check against a loaded Registry and the real CSV tables, and returns the
## problems, one line each. The headless script tools/validate_content.gd prints them and turns
## them into an exit code. Tool code only; never referenced by the game.
## Bible: technical-architecture.md#testing-and-tooling

const RegistryScript := preload("res://src/content/registry.gd")
## Galaxy seeds checked by default: 1..20.
const DEFAULT_SEEDS: int = 20


## Returns the problems found in [param registry] (already loaded with load_all(), whose own
## errors are passed as [param load_errors]), checking the galaxies of seeds 1..[param seeds].
## Prints a progress line per stage when [param is_verbose].
static func run(
	registry: RegistryScript, load_errors: Array[String], seeds: int, is_verbose: bool
) -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(load_errors)
	errors.append_array(_check_content(registry))
	_say(is_verbose, "content: %d problem(s) so far" % errors.size())
	if not errors.is_empty():
		_say(is_verbose, "galaxy checks skipped until the content is valid")
		return errors
	var started: int = Time.get_ticks_msec()
	errors.append_array(_check_seeds(registry, seeds))
	_say(is_verbose, "%d seed(s) checked in %d ms" % [seeds, Time.get_ticks_msec() - started])
	return errors


## Checks 2, 3, 4, the balance tunables and the documents: everything that needs no generated
## galaxy.
static func _check_content(registry: RegistryScript) -> Array[String]:
	var errors: Array[String] = []
	var glyphs: Array[GlyphDef] = []
	for def: DefBase in registry.get_all_of(GlyphDef):
		glyphs.append(def as GlyphDef)
	errors.append_array(
		ContentCheckGlyphs.check(glyphs, ContentSource.read_keys(ContentSource.GLYPH_TABLE))
	)
	errors.append_array(ContentCheckBalance.check(registry.balance()))
	var field: AnchorFieldDef = ContentSource.home_field(registry)
	for def: DefBase in registry.get_all_of(AnchorFieldDef):
		var each: AnchorFieldDef = def as AnchorFieldDef
		errors.append_array(ContentCheckWorlds.check_field(each, each == field))
	if field == null:
		errors.append("expected exactly one anchor field for the home domain")
		return errors
	var worlds: Array[WorldDef] = ContentSource.authored_worlds(registry)
	errors.append_array(ContentCheckWorlds.check_worlds(worlds, field.positions_ly))
	errors.append_array(ContentCheckWorlds.check_unique_addresses(worlds, field.positions_ly))
	errors.append_array(_check_documents(registry, worlds, field.positions_ly))
	return errors


## The document checks: answers, reach, keys in both locales, pairs, far-side readings, decoys.
static func _check_documents(
	registry: RegistryScript, worlds: Array[WorldDef], anchors_ly: Array[Vector3i]
) -> Array[String]:
	var documents: Array[DocumentDef] = []
	for def: DefBase in registry.get_all_of(DocumentDef):
		documents.append(def as DocumentDef)
	var table: Dictionary[String, PackedStringArray] = ContentCheckDocuments.read_table(
		ContentCheckDocuments.TABLE
	)
	var errors: Array[String] = []
	errors.append_array(ContentCheckDocuments.check_answers(documents, worlds, anchors_ly))
	errors.append_array(ContentCheckDocuments.check_reach(worlds, anchors_ly, registry.balance()))
	errors.append_array(ContentCheckDocuments.check_keys(documents, table))
	errors.append_array(ContentCheckDocuments.check_pairs(documents))
	errors.append_array(
		ContentCheckDocuments.check_far_side(
			documents, worlds, anchors_ly, ContentCheckDocuments.far_side_readings()
		)
	)
	errors.append_array(
		ContentCheckDocuments.check_decoys(
			ContentCheckDocuments.decoys(), worlds, anchors_ly, documents
		)
	)
	return errors


## Check 5, and that no decoy is a real address, for seeds 1..[param seeds].
static func _check_seeds(registry: RegistryScript, seeds: int) -> Array[String]:
	var errors: Array[String] = []
	for seed_number: int in range(1, seeds + 1):
		var galaxy: GalaxyCatalogue = ContentSource.galaxy(registry, seed_number)
		var worlds: Array[WorldRecord] = galaxy.all_worlds()
		var found: Array[String] = ContentCheckGalaxy.check(
			worlds, galaxy.anchors_ly(), GeneratorParams.new(), registry.balance()
		)
		found.append_array(
			ContentCheckDocuments.check_galaxy_decoys(ContentCheckDocuments.decoys(), galaxy)
		)
		for line: String in found:
			errors.append("seed %d: %s" % [seed_number, line])
	return errors


static func _say(is_verbose: bool, text: String) -> void:
	if is_verbose:
		print("validate: " + text)
