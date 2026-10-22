## Checks every translation table (localization/*.csv) and that scenes show only keys.
## Bible: technical-architecture.md#input-accessibility-and-localisation;
## overview.md#locked-decisions (Languages: English and Brazilian Portuguese)
extends GdUnitTestSuite

const TABLES_DIR: String = "res://localization"
const SCENES_ROOT: String = "res://src"
const LOCALES: Array[String] = ["en", "pt_BR"]
const TRANSLATIONS_SETTING: String = "internationalization/locale/translations"
const EXPANSION_SETTING: String = "internationalization/pseudolocalization/expansion_ratio"
const PSEUDO_SETTING: String = "internationalization/pseudolocalization/use_pseudolocalization"
const KEY_PATTERN: String = "^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$"
const PLACEHOLDER_PATTERN: String = "\\{([A-Za-z_][A-Za-z0-9_]*)\\}"
const TEXT_PROPERTY_PATTERN: String = '^(text|tooltip_text|placeholder_text) = "([^"]*)'

var _key_regex: RegEx = RegEx.create_from_string(KEY_PATTERN)
var _placeholder_regex: RegEx = RegEx.create_from_string(PLACEHOLDER_PATTERN)
var _text_property_regex: RegEx = RegEx.create_from_string(TEXT_PROPERTY_PATTERN)


## The CSV header is the key column followed by one column per launch locale.
func test_header_lists_keys_then_locales() -> void:
	var tables: Array[String] = _table_paths()
	assert_bool(tables.is_empty()).is_false()
	for path: String in tables:
		var rows: Array[PackedStringArray] = _read_rows(path)
		assert_bool(rows.is_empty()).override_failure_message("%s: empty file" % path).is_false()
		if rows.is_empty():
			continue
		assert_array(Array(rows[0])).override_failure_message(path).is_equal(
			["keys", "en", "pt_BR"]
		)


## Every key follows the AREA_SCREEN_NAME UPPER_SNAKE_CASE convention and appears once
## across all tables.
func test_keys_are_upper_snake_and_unique() -> void:
	var problems: Array[String] = _key_problems(_all_tables())
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


## The uniqueness check reports a key that appears in two tables (a temporary duplicate).
func test_duplicate_key_across_tables_is_reported() -> void:
	var tables: Dictionary[String, Array] = {
		"a.csv": [PackedStringArray(["UI_ONE", "One", "Um"])],
		"b.csv": [PackedStringArray(["UI_ONE", "Uno", "Um"])],
	}
	assert_int(_key_problems(tables).size()).is_equal(1)


## Every key has a non-empty value in every locale.
func test_every_key_has_every_locale() -> void:
	for row: PackedStringArray in _data_rows():
		assert_int(row.size()).override_failure_message("%s: missing column" % row[0]).is_equal(
			LOCALES.size() + 1
		)
		for column: int in range(1, row.size()):
			var message: String = "%s: empty %s value" % [row[0], LOCALES[column - 1]]
			assert_str(row[column].strip_edges()).override_failure_message(message).is_not_empty()


## Named {placeholders} are the same set in English and Brazilian Portuguese.
func test_placeholders_match_between_locales() -> void:
	for row: PackedStringArray in _data_rows():
		var english: Array[String] = _placeholders(row[1])
		var portuguese: Array[String] = _placeholders(row[2])
		var message: String = "%s: placeholders %s vs %s" % [row[0], english, portuguese]
		assert_array(portuguese).override_failure_message(message).is_equal(english)


## Placeholders are filled by name with String.format, in both locales.
func test_multiplier_fills_named_placeholder() -> void:
	for locale: String in LOCALES:
		var translation: Translation = _translation_for(locale)
		assert_object(translation).override_failure_message(locale).is_not_null()
		if translation == null:
			continue
		var template: String = translation.get_message("UI_SPEED_MULTIPLIER")
		assert_str(template.format({"speed": 2})).is_equal("2×")


## Every localization/*.csv is registered in project.godot for both locales, every registered
## table has a CSV, and both locales are loaded.
func test_every_table_is_registered() -> void:
	var translations: PackedStringArray = ProjectSettings.get_setting(TRANSLATIONS_SETTING)
	var expected: Dictionary[String, bool] = {}
	for table: String in _table_names():
		for locale: String in LOCALES:
			expected[_translation_path(table, locale)] = true
	for path: String in expected:
		(
			assert_bool(translations.has(path))
			. override_failure_message("CSV not registered: %s" % path)
			. is_true()
		)
	for path: String in translations:
		if path.begins_with(TABLES_DIR):
			(
				assert_bool(expected.has(path))
				. override_failure_message("registered without a CSV: %s" % path)
				. is_true()
			)
	var loaded: PackedStringArray = TranslationServer.get_loaded_locales()
	for locale: String in LOCALES:
		assert_bool(loaded.has(locale)).override_failure_message(locale).is_true()


## Importing a table produced both .translation outputs, so an empty (header-only) table,
## which Godot imports to nothing, cannot come back. Run after the project import.
func test_every_table_imports_both_outputs() -> void:
	for table: String in _table_names():
		var rows: Array[PackedStringArray] = _read_rows(_table_path(table))
		assert_int(rows.size()).override_failure_message("%s has no strings" % table).is_greater(1)
		for locale: String in LOCALES:
			var path: String = _translation_path(table, locale)
			var message: String = "%s was not produced by the import" % path
			assert_bool(ResourceLoader.exists(path)).override_failure_message(message).is_true()


## Both locales translate a known key.
func test_known_key_translates_in_both_locales() -> void:
	var english: Translation = _translation_for("en")
	var portuguese: Translation = _translation_for("pt_BR")
	assert_object(english).is_not_null()
	assert_object(portuguese).is_not_null()
	assert_str(String(english.get_message("UI_SPEED_PAUSED"))).is_equal("Paused")
	assert_str(String(portuguese.get_message("UI_SPEED_PAUSED"))).is_equal("Pausado")


## Pseudolocalization is configured for ~30% expansion but off by default.
func test_pseudolocalization_settings() -> void:
	var ratio: float = ProjectSettings.get_setting(EXPANSION_SETTING)
	var enabled: bool = ProjectSettings.get_setting(PSEUDO_SETTING)
	assert_float(ratio).is_equal_approx(0.3, 0.001)
	assert_bool(enabled).is_false()


## No scene under src/ sets visible text that is not a translation key.
func test_scenes_use_only_translation_keys() -> void:
	var keys: Dictionary[String, bool] = _known_keys()
	var problems: Array[String] = []
	for path: String in _scene_paths(SCENES_ROOT):
		var content: String = FileAccess.get_file_as_string(path)
		for problem: String in _text_violations(content, keys):
			problems.append("%s: %s" % [path, problem])
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


## The scene scan flags plain English text and unknown keys, and accepts table keys.
func test_scene_scan_flags_plain_text() -> void:
	var keys: Dictionary[String, bool] = {"UI_SAVE": true}
	var content: String = (
		'text = "UI_SAVE"\ntooltip_text = "Save the game"\n'
		+ 'placeholder_text = "UI_NOT_IN_TABLE"\ntext = ""\n'
	)
	var problems: Array[String] = _text_violations(content, keys)
	assert_int(problems.size()).is_equal(2)


## Table names (file name without extension) of every CSV in the localization folder.
func _table_names() -> Array[String]:
	var names: Array[String] = []
	for file_name: String in DirAccess.get_files_at(TABLES_DIR):
		if file_name.get_extension() == "csv":
			names.append(file_name.get_basename())
	names.sort()
	return names


func _table_path(table: String) -> String:
	return "%s/%s.csv" % [TABLES_DIR, table]


func _translation_path(table: String, locale: String) -> String:
	return "%s/%s.%s.translation" % [TABLES_DIR, table, locale]


func _table_paths() -> Array[String]:
	var paths: Array[String] = []
	for table: String in _table_names():
		paths.append(_table_path(table))
	return paths


## Data rows (no header) of every table, keyed by CSV path.
func _all_tables() -> Dictionary[String, Array]:
	var tables: Dictionary[String, Array] = {}
	for path: String in _table_paths():
		tables[path] = _read_rows(path).slice(1)
	return tables


## One message per key that is badly formed or appears more than once across the tables.
func _key_problems(tables: Dictionary[String, Array]) -> Array[String]:
	var problems: Array[String] = []
	var seen: Dictionary[String, String] = {}
	for path: String in tables:
		for row: PackedStringArray in tables[path]:
			var key: String = row[0]
			if not _is_key(key):
				problems.append("%s: bad key '%s'" % [path, key])
			elif seen.has(key):
				problems.append("%s: key %s is also in %s" % [path, key, seen[key]])
			else:
				seen[key] = path
	return problems


func _read_rows(path: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return rows
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		rows.append(row)
	return rows


func _data_rows() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	for path: String in _table_paths():
		rows.append_array(_read_rows(path).slice(1))
	return rows


func _known_keys() -> Dictionary[String, bool]:
	var keys: Dictionary[String, bool] = {}
	for row: PackedStringArray in _data_rows():
		keys[row[0]] = true
	return keys


func _is_key(value: String) -> bool:
	return _key_regex.search(value) != null


func _placeholders(value: String) -> Array[String]:
	var names: Array[String] = []
	for found: RegExMatch in _placeholder_regex.search_all(value):
		names.append(found.get_string(1))
	names.sort()
	return names


func _translation_for(locale: String) -> Translation:
	for translation: Translation in TranslationServer.get_translations():
		if translation.locale == locale:
			return translation
	return null


## Returns one message per text property whose value is not a known UPPER_SNAKE key.
## Empty values are allowed: they are filled from code at runtime.
func _text_violations(content: String, keys: Dictionary[String, bool]) -> Array[String]:
	var problems: Array[String] = []
	for line: String in content.split("\n"):
		var found: RegExMatch = _text_property_regex.search(line)
		if found == null:
			continue
		var value: String = found.get_string(2)
		if value.is_empty() and line.ends_with('""'):
			continue
		if not _is_key(value):
			problems.append('%s is "%s", not an UPPER_SNAKE key' % [found.get_string(1), value])
		elif not keys.has(value):
			problems.append(
				"%s key %s is not in any localization table" % [found.get_string(1), value]
			)
	return problems


func _scene_paths(root: String) -> Array[String]:
	var paths: Array[String] = []
	for file_name: String in DirAccess.get_files_at(root):
		if file_name.get_extension() == "tscn":
			paths.append(root.path_join(file_name))
	for dir_name: String in DirAccess.get_directories_at(root):
		paths.append_array(_scene_paths(root.path_join(dir_name)))
	return paths
