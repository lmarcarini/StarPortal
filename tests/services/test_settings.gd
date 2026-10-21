## Tests for the Settings service and its defaults table.
## Each test uses its own instance pointed at a temporary user:// file, never settings.cfg.
## Bible: technical-architecture.md#input-accessibility-and-localisation
extends GdUnitTestSuite

const SettingsScript := preload("res://src/services/settings.gd")
const TEST_PATH: String = "user://test_settings_service.cfg"

## Every setting_changed emission of the instance under test, as [section, key, value].
var _emitted: Array[Array] = []


func before_test() -> void:
	_emitted.clear()
	_remove_test_file()


func after_test() -> void:
	_remove_test_file()


## A missing file gives every starting default.
func test_missing_file_uses_starting_defaults() -> void:
	var settings: SettingsScript = _make_settings()
	assert_float(settings.get_float(&"display", &"ui_scale")).is_equal(1.0)
	assert_float(settings.get_float(&"display", &"text_size")).is_equal(1.0)
	assert_float(settings.get_float(&"audio", &"master")).is_equal(1.0)
	assert_float(settings.get_float(&"audio", &"music")).is_equal(0.8)
	assert_float(settings.get_float(&"audio", &"effects")).is_equal(1.0)
	assert_float(settings.get_float(&"audio", &"voice")).is_equal(1.0)
	assert_float(settings.get_float(&"audio", &"ambience")).is_equal(0.8)
	assert_bool(settings.get_bool(&"accessibility", &"subtitles")).is_true()
	assert_bool(settings.get_bool(&"accessibility", &"reduced_flashing")).is_false()
	assert_bool(settings.get_bool(&"accessibility", &"screen_shake")).is_true()
	assert_str(settings.get_value(&"gameplay", &"language")).is_equal("en")


## A missing file logs a warning and does not create the file by itself.
func test_missing_file_logs_warning() -> void:
	var settings: SettingsScript = auto_free(SettingsScript.new())
	settings.file_path = TEST_PATH
	await (
		assert_error(func() -> void: settings.reload())
		. is_push_warning(
			"Settings: could not read %s (File not found); using defaults." % TEST_PATH
		)
	)
	assert_bool(FileAccess.file_exists(TEST_PATH)).is_false()


## set_value stores the value with ConfigFile at file_path, and a new instance reads it back.
func test_set_value_saves_to_config_file_and_reloads() -> void:
	var settings: SettingsScript = _make_settings()
	var result: Result = settings.set_value(&"audio", &"music", 0.25)
	assert_bool(result.is_ok).is_true()
	assert_float(result.value).is_equal(0.25)

	var config := ConfigFile.new()
	assert_int(config.load(TEST_PATH)).is_equal(OK)
	assert_float(config.get_value("audio", "music")).is_equal(0.25)

	var reloaded: SettingsScript = _make_settings()
	assert_float(reloaded.get_float(&"audio", &"music")).is_equal(0.25)
	assert_bool(reloaded.get_bool(&"accessibility", &"subtitles")).is_true()


## Setting an unknown section or key fails with unknown_setting and writes nothing.
func test_set_unknown_setting_fails() -> void:
	var settings: SettingsScript = _make_settings()
	var bad_section: Result = settings.set_value(&"nope", &"music", 0.5)
	assert_bool(bad_section.is_ok).is_false()
	assert_that(bad_section.error_code).is_equal(&"unknown_setting")
	var bad_key: Result = settings.set_value(&"audio", &"nope", 0.5)
	assert_bool(bad_key.is_ok).is_false()
	assert_that(bad_key.error_code).is_equal(&"unknown_setting")
	assert_bool(FileAccess.file_exists(TEST_PATH)).is_false()


## Reading an unknown key asserts in debug.
func test_get_unknown_key_asserts() -> void:
	var settings: SettingsScript = _make_settings()
	await (
		assert_error(func() -> void: settings.get_value(&"audio", &"nope"))
		. is_runtime_error("Assertion failed: Settings: unknown setting audio/nope")
	)


## Reading an unknown section asserts in debug.
func test_get_unknown_section_asserts() -> void:
	var settings: SettingsScript = _make_settings()
	await (
		assert_error(func() -> void: settings.get_float(&"nope", &"music"))
		. is_runtime_error("Assertion failed: Settings: unknown setting nope/music")
	)


## A typed getter used on a setting of another type asserts in debug.
func test_typed_getter_on_wrong_type_asserts() -> void:
	var settings: SettingsScript = _make_settings()
	await (
		assert_error(func() -> void: settings.get_bool(&"audio", &"music"))
		. is_runtime_error("Assertion failed: Settings: audio/music is not a bool")
	)


## A value whose type differs from the default's fails with wrong_type and changes nothing.
func test_set_value_rejects_wrong_type() -> void:
	var settings: SettingsScript = _make_settings()
	var cases: Array[Array] = [
		[&"accessibility", &"subtitles", 0.0],
		[&"accessibility", &"subtitles", 1],
		[&"audio", &"music", true],
		[&"audio", &"music", "0.5"],
		[&"gameplay", &"language", &"pt_BR"],
		[&"gameplay", &"language", 3],
	]
	for case: Array in cases:
		var section: StringName = case[0]
		var key: StringName = case[1]
		var result: Result = settings.set_value(section, key, case[2])
		assert_bool(result.is_ok).override_failure_message(str(case)).is_false()
		assert_that(result.error_code).is_equal(&"wrong_type")
	assert_bool(settings.get_bool(&"accessibility", &"subtitles")).is_true()
	assert_float(settings.get_float(&"audio", &"music")).is_equal(0.8)
	assert_str(settings.get_value(&"gameplay", &"language")).is_equal("en")
	assert_array(_emitted).is_empty()
	assert_bool(FileAccess.file_exists(TEST_PATH)).is_false()


## The one exception: an int for a float setting is accepted and stored as a float.
func test_set_value_accepts_int_for_float() -> void:
	var settings: SettingsScript = _make_settings()
	var result: Result = settings.set_value(&"audio", &"music", 0)
	assert_bool(result.is_ok).is_true()
	assert_int(typeof(settings.get_value(&"audio", &"music"))).is_equal(TYPE_FLOAT)
	assert_float(settings.get_float(&"audio", &"music")).is_equal(0.0)
	assert_array(_emitted).is_equal([[&"audio", &"music", 0.0]])


## A corrupt file falls back to defaults, logs a warning and is rewritten on the next save.
func test_corrupt_file_falls_back_and_is_rewritten() -> void:
	_write_test_file("[audio\nmusic = = 0.3\n{{{ not a config file")
	var settings: SettingsScript = auto_free(SettingsScript.new())
	settings.file_path = TEST_PATH
	await (
		assert_error(func() -> void: settings.reload())
		. is_push_warning("Settings: could not read %s (Parse error); using defaults." % TEST_PATH)
	)
	assert_float(settings.get_float(&"audio", &"music")).is_equal(0.8)

	assert_bool(settings.set_value(&"audio", &"voice", 0.5).is_ok).is_true()
	var config := ConfigFile.new()
	assert_int(config.load(TEST_PATH)).is_equal(OK)
	assert_float(config.get_value("audio", "voice")).is_equal(0.5)
	assert_float(config.get_value("audio", "music")).is_equal(0.8)


## A stored value of the wrong type falls back to its default with a warning; others load.
func test_wrong_typed_stored_value_uses_default() -> void:
	_write_test_file("[accessibility]\nsubtitles=0.5\n\n[audio]\nmusic=0.3\nmaster=0\n")
	var settings: SettingsScript = auto_free(SettingsScript.new())
	settings.file_path = TEST_PATH
	await (
		assert_error(func() -> void: settings.reload())
		. is_push_warning("Settings: accessibility/subtitles has the wrong type; using default.")
	)
	assert_bool(settings.get_bool(&"accessibility", &"subtitles")).is_true()
	assert_float(settings.get_float(&"audio", &"music")).is_equal(0.3)
	assert_int(typeof(settings.get_value(&"audio", &"master"))).is_equal(TYPE_FLOAT)


## Unknown entries in the file are ignored and dropped on the next save.
func test_unknown_stored_entries_are_ignored() -> void:
	_write_test_file("[mystery]\nfoo=1\n\n[audio]\nbar=2\nmusic=0.3\n")
	var settings: SettingsScript = _make_settings()
	assert_float(settings.get_float(&"audio", &"music")).is_equal(0.3)
	assert_bool(settings.set_value(&"audio", &"music", 0.4).is_ok).is_true()
	var config := ConfigFile.new()
	assert_int(config.load(TEST_PATH)).is_equal(OK)
	assert_bool(config.has_section("mystery")).is_false()
	assert_bool(config.has_section_key("audio", "bar")).is_false()


## setting_changed fires once on a change and not when the same value is written again.
func test_setting_changed_fires_only_on_change() -> void:
	var settings: SettingsScript = _make_settings()
	assert_bool(settings.set_value(&"accessibility", &"subtitles", true).is_ok).is_true()
	assert_array(_emitted).is_empty()
	assert_bool(FileAccess.file_exists(TEST_PATH)).is_false()

	assert_bool(settings.set_value(&"accessibility", &"subtitles", false).is_ok).is_true()
	assert_bool(settings.set_value(&"accessibility", &"subtitles", false).is_ok).is_true()
	assert_array(_emitted).is_equal([[&"accessibility", &"subtitles", false]])


## reset_section restores defaults, saves, and signals only the keys that changed.
func test_reset_section_restores_defaults() -> void:
	var settings: SettingsScript = _make_settings()
	settings.set_value(&"audio", &"music", 0.1)
	settings.set_value(&"audio", &"voice", 0.2)
	settings.set_value(&"display", &"ui_scale", 1.5)
	_emitted.clear()

	settings.reset_section(&"audio")
	assert_float(settings.get_float(&"audio", &"music")).is_equal(0.8)
	assert_float(settings.get_float(&"audio", &"voice")).is_equal(1.0)
	assert_float(settings.get_float(&"display", &"ui_scale")).is_equal(1.5)
	assert_array(_emitted).contains_exactly_in_any_order(
		[[&"audio", &"music", 0.8], [&"audio", &"voice", 1.0]]
	)
	var reloaded: SettingsScript = _make_settings()
	assert_float(reloaded.get_float(&"audio", &"music")).is_equal(0.8)
	assert_float(reloaded.get_float(&"display", &"ui_scale")).is_equal(1.5)


## reset_section on a section already at defaults signals nothing.
func test_reset_unchanged_section_is_silent() -> void:
	var settings: SettingsScript = _make_settings()
	settings.reset_section(&"accessibility")
	assert_array(_emitted).is_empty()


## reset_section with an unknown section asserts in debug.
func test_reset_unknown_section_asserts() -> void:
	var settings: SettingsScript = _make_settings()
	await (
		assert_error(func() -> void: settings.reset_section(&"nope"))
		. is_runtime_error("Assertion failed: Settings: unknown section nope")
	)


## reload picks up file changes and signals only the values that differ.
func test_reload_signals_changed_values() -> void:
	var settings: SettingsScript = _make_settings()
	_write_test_file("[audio]\nmusic=0.8\nvoice=0.4\n")
	settings.reload()
	assert_float(settings.get_float(&"audio", &"voice")).is_equal(0.4)
	assert_array(_emitted).is_equal([[&"audio", &"voice", 0.4]])


## Returns a fresh Settings instance on the test file, already loaded and observed.
func _make_settings() -> SettingsScript:
	var settings: SettingsScript = auto_free(SettingsScript.new())
	settings.file_path = TEST_PATH
	settings.setting_changed.connect(_on_setting_changed)
	if FileAccess.file_exists(TEST_PATH):
		settings.reload()
	return settings


func _on_setting_changed(section: StringName, key: StringName, value: Variant) -> void:
	_emitted.append([section, key, value])


func _write_test_file(text: String) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
