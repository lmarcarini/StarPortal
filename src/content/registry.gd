extends Node
## Autoload that loads every content definition ([DefBase]) under `data/` at start-up into one
## dictionary keyed by id and validates it, so broken content is caught before the game runs.
## It reports empty ids, duplicate ids (naming both files), references to missing ids and files
## that are not definitions; invalid files are skipped and everything else stays available.
##
## Definitions are read-only at runtime. A loaded Resource is shared by everything that loads
## the same path, so the Registry never writes to a loaded definition, and neither may callers.
## Bible: technical-architecture.md#data-model, technical-architecture.md#testing-and-tooling

## Root folder loaded on start-up.
const DATA_ROOT: String = "res://data"
## Extension of definition files.
const DEFINITION_EXTENSION: String = ".tres"
## Suffix an exported build gives to remapped resource files (e.g. converted to binary).
const REMAP_SUFFIX: String = ".remap"

var _defs: Dictionary[StringName, DefBase] = {}
var _sources: Dictionary[StringName, String] = {}


func _ready() -> void:
	var errors: Array[String] = load_all(DATA_ROOT).value
	if not OS.is_debug_build():
		return
	for error: String in errors:
		push_error("Registry: " + error)


## Clears the registry, then loads and validates every `.tres` under [param root], recursively.
## Files are listed through [method ResourceLoader.list_directory], so this also works in
## exported builds, where files may carry a `.remap` suffix.
## Always returns an ok [Result]; its value is the [code]Array[String][/code] of content errors,
## empty when the content is valid.
func load_all(root: String = DATA_ROOT) -> Result:
	_defs.clear()
	_sources.clear()
	var errors: Array[String] = []
	if not DirAccess.dir_exists_absolute(root):
		errors.append("%s: content folder not found" % root)
		return Result.ok(errors)
	var paths: Array[String] = []
	_collect_paths(root, paths)
	paths.sort()
	for path: String in paths:
		_register(path, errors)
	_check_references(errors)
	return Result.ok(errors)


## Returns the definition with [param id], or null when none is loaded.
func get_def(id: StringName) -> DefBase:
	if not _defs.has(id):
		return null
	return _defs[id]


## Returns every loaded definition that is an instance of [param script] (or of a script that
## extends it), in load order. Empty when [param script] is null.
func get_all_of(script: Script) -> Array[DefBase]:
	var found: Array[DefBase] = []
	if script == null:
		return found
	for def: DefBase in _defs.values():
		if is_instance_of(def, script):
			found.append(def)
	return found


## Returns true when a definition with [param id] is loaded.
func has_def(id: StringName) -> bool:
	return _defs.has(id)


## Returns the [BalanceConfig] (id &"balance"), or null when none is loaded.
func balance() -> BalanceConfig:
	var def: DefBase = get_def(BalanceConfig.BALANCE_ID)
	return def as BalanceConfig


## Returns the path to load for directory entry [param entry] of [param dir] when the entry is a
## definition file, or "" otherwise. A `.remap` suffix is stripped, because an exported build
## loads a remapped resource through its original name.
static func definition_path(dir: String, entry: String) -> String:
	var file_name: String = entry.trim_suffix(REMAP_SUFFIX)
	if not file_name.ends_with(DEFINITION_EXTENSION):
		return ""
	return dir.path_join(file_name)


static func _collect_paths(dir: String, into: Array[String]) -> void:
	for entry: String in ResourceLoader.list_directory(dir):
		if entry.ends_with("/"):
			_collect_paths(dir.path_join(entry.trim_suffix("/")), into)
			continue
		var path: String = definition_path(dir, entry)
		if not path.is_empty() and not into.has(path):
			into.append(path)


func _register(path: String, errors: Array[String]) -> void:
	var resource: Resource = ResourceLoader.load(path)
	if resource == null:
		errors.append("%s: could not be loaded" % path)
		return
	if not resource is DefBase:
		errors.append("%s: is not a DefBase definition" % path)
		return
	var def: DefBase = resource as DefBase
	if def.id.is_empty():
		errors.append("%s: empty id" % path)
		return
	if _defs.has(def.id):
		errors.append('duplicate id "%s" in %s and %s' % [def.id, _sources[def.id], path])
		return
	_defs[def.id] = def
	_sources[def.id] = path


func _check_references(errors: Array[String]) -> void:
	for def_id: StringName in _defs:
		for reference: StringName in _defs[def_id].get_references():
			if not _defs.has(reference):
				errors.append(
					'%s: "%s" references missing id "%s"' % [_sources[def_id], def_id, reference]
				)
