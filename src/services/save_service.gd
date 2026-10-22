extends Node
## Autoload. Saves GameState to versioned JSON files, loads them back, keeps three rotating
## autosaves and lists the slots on disk. Saves are plain JSON read with FileAccess, never
## Resources, because a .tres loaded from a user folder can run embedded scripts.
## File shape: {"format_version", "game_version", "saved_at_unix", "tick", "state"}.
## Error codes: &"bad_slot_name", &"missing_file", &"read_failed", &"corrupt_json",
## &"bad_format_version", &"newer_format_version", &"missing_migration_step",
## &"migration_failed", &"corrupt_save", &"invalid_state", &"write_failed",
## &"delete_failed".
## Bible: technical-architecture.md#save-system

## Version of the file format written by save_game().
const FORMAT_VERSION: int = SaveMigrator.TARGET_VERSION
## Number of rotating autosave slots: autosave_1 (newest) to autosave_3 (oldest).
const AUTOSAVE_SLOTS: int = 3
## Slot name prefix of the autosaves; the slot index (1 to AUTOSAVE_SLOTS) follows it.
const AUTOSAVE_PREFIX: String = "autosave_"
## Extension of a save file: <slot>.json.
const FILE_EXTENSION: String = ".json"
## Suffix of the temporary file a save is written to before the rename: <slot>.json.tmp.
const TEMP_SUFFIX: String = ".tmp"
## The only characters allowed in a slot name.
const SLOT_NAME_CHARS: String = "abcdefghijklmnopqrstuvwxyz0123456789_"
## Longest allowed slot name, in characters.
const SLOT_NAME_MAX_LENGTH: int = 32
## Game version written when application/config/version is not set.
const DEFAULT_GAME_VERSION: String = "0.0.0"

## Folder holding the save files. Tests point this at a temporary folder.
var saves_dir: String = "user://saves"


## Writes [param state] to [param slot] atomically and emits EventBus.game_saved.
## The value on success is the file path.
func save_game(state: GameState, slot: StringName) -> Result:
	if not is_valid_slot_name(slot):
		return Result.fail(&"bad_slot_name", "invalid slot name '%s'" % slot)
	var path := slot_path(slot)
	var written := _write_temp(path, _serialize(state))
	if not written.is_ok:
		return written
	var replaced := _replace_with_temp(path)
	if not replaced.is_ok:
		return replaced
	EventBus.game_saved.emit(slot)
	return Result.ok(path)


## Reads [param slot], migrates it to the current format and returns the GameState as the
## value. The state is checked with GameState.validate_dict() before it is built, so a
## hand-edited value of the wrong type fails with &"invalid_state" instead of loading as a
## default. A header "tick" that differs from the state's clock tick also fails with
## &"invalid_state". Emits EventBus.game_loaded on success. Never crashes on a bad file.
func load_game(slot: StringName) -> Result:
	if not is_valid_slot_name(slot):
		return Result.fail(&"bad_slot_name", "invalid slot name '%s'" % slot)
	var read := _read_data(slot_path(slot))
	if not read.is_ok:
		return read
	var raw_data: Dictionary = read.value
	var migrated := SaveMigrator.migrate(raw_data)
	if not migrated.is_ok:
		return migrated
	var data: Dictionary = migrated.value
	var checked := _check_header(data)
	if not checked.is_ok:
		return checked
	var built := _build_state(data)
	if built.is_ok:
		EventBus.game_loaded.emit(slot)
	return built


## Writes [param state] to autosave_1, after shifting older autosaves down one slot.
## The oldest (autosave_3) is dropped, so at most three autosave files exist. The new file
## is fully written before anything is rotated. Known gap: a crash after the rotation and
## before the final rename leaves the newest data only in autosave_1.json.tmp, which is
## not read back.
func autosave(state: GameState) -> Result:
	var slot := StringName(AUTOSAVE_PREFIX + "1")
	var path := slot_path(slot)
	var written := _write_temp(path, _serialize(state))
	if not written.is_ok:
		return written
	for index: int in range(AUTOSAVE_SLOTS - 1, 0, -1):
		var from_path := slot_path(StringName(AUTOSAVE_PREFIX + str(index)))
		if not FileAccess.file_exists(from_path):
			continue
		var moved := _move_file(from_path, slot_path(StringName(AUTOSAVE_PREFIX + str(index + 1))))
		if not moved.is_ok:
			return moved
	var replaced := _replace_with_temp(path)
	if not replaced.is_ok:
		return replaced
	EventBus.game_saved.emit(slot)
	return Result.ok(path)


## Returns one entry per readable save file, newest first:
## {slot: StringName, tick: int, saved_at_unix: int, format_version: int}.
## Temporary files, invalid names, unreadable or corrupt files, and files whose header
## "tick" differs from the state's clock tick are skipped.
func list_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var dir := DirAccess.open(saves_dir)
	if dir == null:
		return slots
	for file_name: String in dir.get_files():
		if not file_name.ends_with(FILE_EXTENSION):
			continue
		var slot := StringName(file_name.trim_suffix(FILE_EXTENSION))
		if not is_valid_slot_name(slot):
			continue
		var entry := _slot_entry(slot)
		if not entry.is_empty():
			slots.append(entry)
	slots.sort_custom(_newer_first)
	return slots


## Deletes [param slot] and any leftover temporary file for it. A leftover temporary file
## is removed even when the slot itself is missing, which still fails with &"missing_file".
func delete_slot(slot: StringName) -> Result:
	if not is_valid_slot_name(slot):
		return Result.fail(&"bad_slot_name", "invalid slot name '%s'" % slot)
	var path := slot_path(slot)
	var temp_path := path + TEMP_SUFFIX
	if FileAccess.file_exists(temp_path):
		var temp_error := DirAccess.remove_absolute(temp_path)
		if temp_error != OK:
			return Result.fail(&"delete_failed", "%s: %s" % [temp_path, error_string(temp_error)])
	if not FileAccess.file_exists(path):
		return Result.fail(&"missing_file", path)
	var error := DirAccess.remove_absolute(path)
	if error != OK:
		return Result.fail(&"delete_failed", "%s: %s" % [path, error_string(error)])
	return Result.ok()


## Returns the file path for [param slot] inside [member saves_dir].
func slot_path(slot: StringName) -> String:
	return saves_dir.path_join(String(slot) + FILE_EXTENSION)


## Returns true when [param slot] is 1 to 32 characters, each one of [code]a-z 0-9 _[/code].
## Checked character by character, so no regex anchor can let a trailing newline through.
static func is_valid_slot_name(slot: StringName) -> bool:
	var text := String(slot)
	if text.is_empty() or text.length() > SLOT_NAME_MAX_LENGTH:
		return false
	for character: String in text:
		if not SLOT_NAME_CHARS.contains(character):
			return false
	return true


## Returns the game version from ProjectSettings application/config/version, or
## "0.0.0" when it is not set.
static func game_version() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	return version if not version.is_empty() else DEFAULT_GAME_VERSION


func _serialize(state: GameState) -> String:
	var data := {
		"format_version": FORMAT_VERSION,
		"game_version": game_version(),
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"tick": state.clock.tick,
		"state": state.to_dict(),
	}
	# full_precision writes the shortest exact text of a float, but Godot's JSON parser can
	# drop digits when reading it back, so it does not make a round trip exact by itself.
	# State floats are saved as ExactFloat strings instead.
	return JSON.stringify(data, "\t", true, true)


## Writes [param text] to [param path].tmp. The real file is untouched, so an interrupted
## write leaves the previous save intact.
func _write_temp(path: String, text: String) -> Result:
	var dir_error := DirAccess.make_dir_recursive_absolute(saves_dir)
	if dir_error != OK:
		return Result.fail(&"write_failed", "%s: %s" % [saves_dir, error_string(dir_error)])
	var temp_path := path + TEMP_SUFFIX
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		var open_error := FileAccess.get_open_error()
		return Result.fail(&"write_failed", "%s: %s" % [temp_path, error_string(open_error)])
	var stored := file.store_string(text)
	var write_error := file.get_error()
	file.close()
	if not stored or write_error != OK:
		DirAccess.remove_absolute(temp_path)
		return Result.fail(&"write_failed", "%s: %s" % [temp_path, error_string(write_error)])
	return Result.ok()


## Renames [param path].tmp over [param path].
func _replace_with_temp(path: String) -> Result:
	return _move_file(path + TEMP_SUFFIX, path)


## Renames [param from_path] onto [param to_path], replacing it. On POSIX the rename is
## atomic. On Windows a rename onto an existing file can fail; then the old target is
## removed and the rename retried. That is safe only because [param from_path] is already
## complete, and leaves a brief window where only [param from_path] exists.
func _move_file(from_path: String, to_path: String) -> Result:
	var error := DirAccess.rename_absolute(from_path, to_path)
	if error != OK and FileAccess.file_exists(to_path):
		DirAccess.remove_absolute(to_path)
		error = DirAccess.rename_absolute(from_path, to_path)
	if error != OK:
		return Result.fail(&"write_failed", "%s: %s" % [to_path, error_string(error)])
	return Result.ok()


## Reads and parses [param path] as a JSON object, without migrating it.
func _read_data(path: String) -> Result:
	if not FileAccess.file_exists(path):
		return Result.fail(&"missing_file", path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error := FileAccess.get_open_error()
		return Result.fail(&"read_failed", "%s: %s" % [path, error_string(open_error)])
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		var message := "%s line %d: %s" % [path, json.get_error_line(), json.get_error_message()]
		return Result.fail(&"corrupt_json", message)
	if not json.data is Dictionary:
		return Result.fail(&"corrupt_json", "%s: top level is not an object" % path)
	return Result.ok(json.data)


## Checks the header fields and the state object of migrated [param data].
static func _check_header(data: Dictionary) -> Result:
	for key: String in ["tick", "saved_at_unix"]:
		if not _is_whole_number(data.get(key)):
			return Result.fail(&"corrupt_save", "'%s' is not a whole number from 0 to 2^53" % key)
	if not data.get("game_version") is String:
		return Result.fail(&"corrupt_save", "'game_version' is not a string")
	if not data.get("state") is Dictionary:
		return Result.fail(&"corrupt_save", "'state' is not an object")
	return Result.ok()


## Validates the "state" of migrated, header-checked [param data] and returns the built
## GameState as the value. Fails with &"invalid_state" when GameState.validate_dict()
## reports errors or when the header "tick" differs from the state's clock tick.
static func _build_state(data: Dictionary) -> Result:
	var state_data: Dictionary = data["state"]
	var errors := GameState.validate_dict(state_data)
	if not errors.is_empty():
		return Result.fail(&"invalid_state", "; ".join(errors))
	var state := GameState.from_dict(state_data)
	var header_tick: int = data["tick"]
	if header_tick != state.clock.tick:
		var detail := "header tick %d differs from clock tick %d" % [header_tick, state.clock.tick]
		return Result.fail(&"invalid_state", detail)
	return Result.ok(state)


static func _is_whole_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var number: float = value
	var limit: float = float(JsonLimits.MAX_EXACT_INT)
	return number == floorf(number) and number >= 0.0 and number <= limit


## True when the header "tick" of [param data] (already checked by _check_header) equals
## the whole-number "tick" of its state's clock. A missing or non-numeric clock tick does
## not match. Used by list_slots(), which does not validate the whole state.
static func _header_tick_matches_clock(data: Dictionary) -> bool:
	var state_data: Dictionary = data["state"]
	var clock: Variant = state_data.get("clock")
	if not clock is Dictionary:
		return false
	var clock_data: Dictionary = clock
	var clock_tick: Variant = clock_data.get("tick")
	if not (clock_tick is int or clock_tick is float):
		return false
	var header_tick: float = data["tick"]
	var state_tick: float = clock_tick
	return header_tick == state_tick


## Returns the list_slots() entry for [param slot], or {} when it cannot be read.
func _slot_entry(slot: StringName) -> Dictionary:
	var read := _read_data(slot_path(slot))
	if not read.is_ok:
		return {}
	var data: Dictionary = read.value
	var version := SaveMigrator.read_version(data)
	if not version.is_ok or not _check_header(data).is_ok:
		return {}
	if not _header_tick_matches_clock(data):
		return {}
	var tick: int = data["tick"]
	var saved_at_unix: int = data["saved_at_unix"]
	return {
		"slot": slot,
		"tick": tick,
		"saved_at_unix": saved_at_unix,
		"format_version": version.value,
	}


static func _newer_first(a: Dictionary, b: Dictionary) -> bool:
	var a_time: int = a["saved_at_unix"]
	var b_time: int = b["saved_at_unix"]
	if a_time != b_time:
		return a_time > b_time
	return str(a["slot"]) < str(b["slot"])
