class_name ContentSource
extends RefCounted
## Reads the real content for the tools: a private Registry instance (the autoload is not ready
## in a `--script` run), the translation keys of the CSV tables, and the galaxy of a seed.
## Tool code only: nothing in `src/` refers to it and `tools/` is never exported.
## Bible: technical-architecture.md#testing-and-tooling

const RegistryScript := preload("res://src/content/registry.gd")
## Folder of the per-area translation tables.
const LOCALIZATION_DIR: String = "res://localization/"
## The table of glyph names and pictures.
const GLYPH_TABLE: String = "glyphs.csv"
## The table of clue texts and sources.
const CLUE_TABLE: String = "clues.csv"
## Id of the home domain's anchor field.
const HOME_DOMAIN: StringName = &"home"


## Returns a new Registry with everything under [param root] loaded. The caller frees it.
## Content errors are not returned here: call load_all() again to read them.
static func new_registry() -> RegistryScript:
	return RegistryScript.new()


## Returns the keys of the table [param file_name] (e.g. "glyphs.csv") that have a non-empty
## English text, each mapped to true. Empty when the file cannot be read.
static func read_keys(file_name: String) -> Dictionary[String, bool]:
	var keys: Dictionary[String, bool] = {}
	var file: FileAccess = FileAccess.open(LOCALIZATION_DIR + file_name, FileAccess.READ)
	if file == null:
		return keys
	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() > 1 and not row[0].is_empty() and not row[1].strip_edges().is_empty():
			keys[row[0]] = true
	return keys


## Returns the anchor field of the home domain, or null when there is not exactly one.
static func home_field(registry: RegistryScript) -> AnchorFieldDef:
	var found: Array[AnchorFieldDef] = []
	for def: DefBase in registry.get_all_of(AnchorFieldDef):
		var field: AnchorFieldDef = def as AnchorFieldDef
		if field.domain_id == HOME_DOMAIN:
			found.append(field)
	if found.size() != 1:
		return null
	return found[0]


## Returns every authored world in [param registry].
static func authored_worlds(registry: RegistryScript) -> Array[WorldDef]:
	var worlds: Array[WorldDef] = []
	for def: DefBase in registry.get_all_of(WorldDef):
		worlds.append(def as WorldDef)
	return worlds


## Returns the galaxy of [param seed]: the home anchors, every authored world and the default
## generator parameters. The registry must hold a valid home field and one home world.
@warning_ignore("shadowed_global_identifier")
static func galaxy(registry: RegistryScript, seed: int) -> GalaxyCatalogue:
	var anchors: Array[Vector3i] = home_field(registry).positions_ly
	var worlds: Array[WorldRecord] = WorldGenerator.generate(
		seed, anchors, authored_worlds(registry), GeneratorParams.new(), registry.balance()
	)
	return GalaxyCatalogue.build(worlds, anchors)
