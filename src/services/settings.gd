extends Node
## Player settings service, registered as the [code]Settings[/code] autoload.
## Every setting has a default in [SettingsDefaults]; that table is the only gate for which
## sections and keys exist and which type each one holds. Values persist with [ConfigFile] at
## [member file_path], outside save games, and are saved as soon as one changes.
## Bible: technical-architecture.md#input-accessibility-and-localisation

## Emitted after a setting's value actually changes; never for a write of the same value.
signal setting_changed(section: StringName, key: StringName, value: Variant)

## Where settings are stored. Tests point this at a temporary path before [method reload].
var file_path: String = "user://settings.cfg"

## Current values as {section: {key: value}}; always holds every key of the defaults table.
var _values: Dictionary[StringName, Dictionary] = {}


func _init() -> void:
	_values = _defaults_copy()


func _ready() -> void:
	reload()


## Returns the current value of [param section]/[param key].
## An unknown setting is a programmer error: it asserts in debug and returns null.
func get_value(section: StringName, key: StringName) -> Variant:
	if not _is_known(section, key):
		assert(false, "Settings: unknown setting %s/%s" % [section, key])
		return null
	return _values[section][key]


## Returns a bool setting. Asserts in debug and returns false if the setting is unknown or
## is not a bool.
func get_bool(section: StringName, key: StringName) -> bool:
	var value: Variant = _get_typed(section, key, TYPE_BOOL)
	return false if typeof(value) == TYPE_NIL else value


## Returns an int setting. Asserts in debug and returns 0 if the setting is unknown or is
## not an int.
func get_int(section: StringName, key: StringName) -> int:
	var value: Variant = _get_typed(section, key, TYPE_INT)
	return 0 if typeof(value) == TYPE_NIL else value


## Returns a float setting. Asserts in debug and returns 0.0 if the setting is unknown or is
## not a float.
func get_float(section: StringName, key: StringName) -> float:
	var value: Variant = _get_typed(section, key, TYPE_FLOAT)
	return 0.0 if typeof(value) == TYPE_NIL else value


## Sets [param section]/[param key] to [param value] and saves immediately.
## Fails with [code]&"unknown_setting"[/code] if the setting has no default, and with
## [code]&"wrong_type"[/code] if [param value]'s type differs from the default's type.
## One exception: an int is accepted for a float setting and stored as a float.
## Writing the current value succeeds without saving or emitting [signal setting_changed].
## Fails with [code]&"save_failed"[/code] if the file cannot be written; the new value still
## applies for this session.
func set_value(section: StringName, key: StringName, value: Variant) -> Result:
	if not _is_known(section, key):
		return Result.fail(&"unknown_setting", "%s/%s" % [section, key])
	var coerced: Variant = _coerce(SettingsDefaults.VALUES[section][key], value)
	if typeof(coerced) == TYPE_NIL:
		return Result.fail(
			&"wrong_type", "%s/%s got %s" % [section, key, type_string(typeof(value))]
		)
	if _values[section][key] == coerced:
		return Result.ok(coerced)
	_values[section][key] = coerced
	var error: Error = _save()
	setting_changed.emit(section, key, coerced)
	if error != OK:
		return Result.fail(&"save_failed", "%s: %s" % [file_path, error_string(error)])
	return Result.ok(coerced)


## Restores every setting in [param section] to its default and saves if anything changed.
## An unknown section is a programmer error: it asserts in debug and does nothing.
func reset_section(section: StringName) -> void:
	if not SettingsDefaults.VALUES.has(section):
		assert(false, "Settings: unknown section %s" % section)
		return
	var replacement: Dictionary[StringName, Dictionary] = {
		section: _section_defaults(section).duplicate()
	}
	if _apply(replacement):
		_save()


## Reloads every setting from [member file_path]. A missing or unreadable file, or a stored
## value of the wrong type, logs a warning and falls back to the default; the file is
## rewritten in full on the next save. Unknown entries in the file are ignored.
func reload() -> void:
	var loaded: Dictionary[StringName, Dictionary] = _defaults_copy()
	var config := ConfigFile.new()
	var error: Error = config.load(file_path)
	if error == OK:
		_read_config(config, loaded)
	else:
		push_warning(
			"Settings: could not read %s (%s); using defaults." % [file_path, error_string(error)]
		)
	_apply(loaded)


## Returns the value if it is known and of [param type]; otherwise asserts and returns null.
func _get_typed(section: StringName, key: StringName, type: Variant.Type) -> Variant:
	var value: Variant = get_value(section, key)
	if typeof(value) == TYPE_NIL:
		return null
	if typeof(value) != type:
		assert(false, "Settings: %s/%s is not a %s" % [section, key, type_string(type)])
		return null
	return value


## Copies each defaulted value stored in [param config] into [param loaded], skipping any of
## the wrong type.
func _read_config(config: ConfigFile, loaded: Dictionary[StringName, Dictionary]) -> void:
	for section: StringName in loaded:
		for key: StringName in loaded[section]:
			if not config.has_section_key(section, key):
				continue
			var stored: Variant = config.get_value(section, key)
			var coerced: Variant = _coerce(loaded[section][key], stored)
			if typeof(coerced) == TYPE_NIL:
				push_warning("Settings: %s/%s has the wrong type; using default." % [section, key])
				continue
			loaded[section][key] = coerced


## Writes every value in [param replacement] (a subset of sections is fine), emitting
## [signal setting_changed] for each value that differs. Returns true if any value changed.
func _apply(replacement: Dictionary[StringName, Dictionary]) -> bool:
	var changed: Array[Array] = []
	for section: StringName in replacement:
		for key: StringName in replacement[section]:
			var value: Variant = replacement[section][key]
			if _values[section][key] != value:
				_values[section][key] = value
				changed.append([section, key, value])
	for change: Array in changed:
		setting_changed.emit(change[0], change[1], change[2])
	return not changed.is_empty()


## Writes every current value to [member file_path], replacing the whole file.
func _save() -> Error:
	var config := ConfigFile.new()
	for section: StringName in _values:
		for key: StringName in _values[section]:
			config.set_value(section, key, _values[section][key])
	var error: Error = config.save(file_path)
	if error != OK:
		push_warning("Settings: could not write %s (%s)." % [file_path, error_string(error)])
	return error


## True if [param section]/[param key] has a default.
static func _is_known(section: StringName, key: StringName) -> bool:
	return _section_defaults(section).has(key)


## Returns [param value] in the type of [param default], or null if the types differ.
## The only conversion is int to float, for a float default.
static func _coerce(default: Variant, value: Variant) -> Variant:
	if typeof(default) == TYPE_FLOAT and typeof(value) == TYPE_INT:
		var whole: int = value
		return float(whole)
	if typeof(value) != typeof(default):
		return null
	return value


## Returns a deep copy of the defaults table, typed for [member _values].
static func _defaults_copy() -> Dictionary[StringName, Dictionary]:
	var copy: Dictionary[StringName, Dictionary] = {}
	for section: StringName in SettingsDefaults.VALUES:
		copy[section] = _section_defaults(section).duplicate()
	return copy


## Returns the defaults of [param section] as {key: default}, or an empty dictionary if the
## section is unknown.
static func _section_defaults(section: StringName) -> Dictionary:
	var defaults: Dictionary = SettingsDefaults.VALUES.get(section, {})
	return defaults
