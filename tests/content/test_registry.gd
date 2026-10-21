## Tests for the Registry: loading definitions from fixture folders and validating them.
## Each test loads a fresh Registry instance, never the autoload or the real data/ folder.
## Bible: technical-architecture.md#data-model, technical-architecture.md#testing-and-tooling
extends GdUnitTestSuite

const RegistryScript := preload("res://src/content/registry.gd")
const FixtureDef := preload("res://tests/content/fixtures/fixture_def.gd")
const FIXTURES: String = "res://tests/content/fixtures/"

var _registry: RegistryScript


func before_test() -> void:
	_registry = auto_free(RegistryScript.new())


func _load(fixture: String) -> Array[String]:
	var result: Result = _registry.load_all(FIXTURES + fixture)
	assert_bool(result.is_ok).is_true()
	var errors: Array[String] = result.value
	return errors


func _get_def(id: StringName) -> DefBase:
	return _registry.get_def(id)


func _has_def(id: StringName) -> bool:
	return _registry.has_def(id)


## A valid set loads every definition, including those in subfolders, with no errors.
func test_valid_set_loads_recursively_without_errors() -> void:
	var errors: Array[String] = _load("valid")
	assert_array(errors).is_empty()
	assert_bool(_has_def(&"alpha")).is_true()
	assert_bool(_has_def(&"beta")).is_true()
	assert_bool(_has_def(&"balance")).is_true()
	assert_that(_get_def(&"beta").resource_path).is_equal(FIXTURES + "valid/nested/beta.tres")


## get_def returns null and has_def false for an id that is not loaded.
func test_missing_id_returns_null() -> void:
	_load("valid")
	assert_that(_get_def(&"ghost")).is_null()
	assert_bool(_has_def(&"ghost")).is_false()


## balance() returns the BalanceConfig, whose id is always &"balance".
func test_balance_returns_balance_config() -> void:
	_load("valid")
	var balance: BalanceConfig = _registry.balance()
	assert_that(balance).is_not_null()
	assert_that(balance.id).is_equal(&"balance")
	assert_that(BalanceConfig.new().id).is_equal(&"balance")


## balance() returns null when no BalanceConfig is loaded.
func test_balance_is_null_when_missing() -> void:
	_load("duplicate")
	assert_that(_registry.balance()).is_null()


## get_all_of returns only the definitions of the given script, and its subclasses for DefBase.
func test_get_all_of_filters_by_script() -> void:
	_load("valid")
	var fixtures: Array[DefBase] = _registry.get_all_of(FixtureDef)
	var ids: Array[StringName] = []
	for def: DefBase in fixtures:
		ids.append(def.id)
	assert_array(ids).contains_exactly_in_any_order([&"alpha", &"beta"])
	var balances: Array[DefBase] = _registry.get_all_of(BalanceConfig)
	assert_int(balances.size()).is_equal(1)
	var all: Array[DefBase] = _registry.get_all_of(DefBase)
	assert_int(all.size()).is_equal(3)


## A duplicate id is reported once, naming both files; the first file wins.
func test_duplicate_id_names_both_files() -> void:
	var errors: Array[String] = _load("duplicate")
	assert_array(errors).has_size(1)
	assert_str(errors[0]).contains("same")
	assert_str(errors[0]).contains(FIXTURES + "duplicate/first.tres")
	assert_str(errors[0]).contains(FIXTURES + "duplicate/second.tres")
	assert_that(_get_def(&"same").resource_path).is_equal(FIXTURES + "duplicate/first.tres")


## A reference to an id no definition has is reported with the file, the id and the target.
func test_missing_reference_is_reported() -> void:
	var errors: Array[String] = _load("missing_reference")
	assert_array(errors).has_size(1)
	assert_str(errors[0]).contains(FIXTURES + "missing_reference/alpha.tres")
	assert_str(errors[0]).contains("ghost")


## A definition with an empty id is rejected and reported; the others still load.
func test_empty_id_is_rejected() -> void:
	var errors: Array[String] = _load("empty_id")
	assert_array(errors).has_size(1)
	assert_str(errors[0]).contains(FIXTURES + "empty_id/blank.tres")
	assert_str(errors[0]).contains("empty id")
	assert_bool(_has_def(&"kept")).is_true()
	assert_int(_registry.get_all_of(DefBase).size()).is_equal(1)


## A .tres file that is not a DefBase is rejected and reported.
func test_non_definition_file_is_rejected() -> void:
	var errors: Array[String] = _load("not_def")
	assert_array(errors).has_size(1)
	assert_str(errors[0]).contains(FIXTURES + "not_def/gradient.tres")
	assert_str(errors[0]).contains("not a DefBase")


## A missing root folder is reported as an error.
func test_missing_root_is_reported() -> void:
	var errors: Array[String] = _load("does_not_exist")
	assert_array(errors).has_size(1)
	assert_str(errors[0]).contains("not found")


## Loading again clears the previous content.
func test_load_all_replaces_previous_content() -> void:
	_load("valid")
	_load("duplicate")
	assert_bool(_has_def(&"alpha")).is_false()
	assert_bool(_has_def(&"same")).is_true()


## Exported-build path: a folder holding only `name.tres.remap` (as an export writes it) loads
## the remapped definition under its original name.
func test_remapped_file_loads_as_in_exported_build() -> void:
	var errors: Array[String] = _load("remap")
	assert_array(errors).is_empty()
	assert_bool(_has_def(&"remapped")).is_true()


## definition_path strips the `.remap` suffix and keeps only `.tres` files.
func test_definition_path_handles_remap_names() -> void:
	var dir: String = "res://data/rooms"
	assert_str(RegistryScript.definition_path(dir, "lab.tres")).is_equal(dir + "/lab.tres")
	assert_str(RegistryScript.definition_path(dir, "lab.tres.remap")).is_equal(dir + "/lab.tres")
	assert_str(RegistryScript.definition_path(dir, "lab.gd")).is_empty()
	assert_str(RegistryScript.definition_path(dir, "lab.gd.remap")).is_empty()
	assert_str(RegistryScript.definition_path(dir, "icon.png.import")).is_empty()


## The Registry never writes to a loaded definition: the shared resources are unchanged.
func test_loading_does_not_modify_definitions() -> void:
	var alpha: FixtureDef = load(FIXTURES + "valid/alpha.tres")
	var before: Array[StringName] = alpha.references.duplicate()
	_load("valid")
	_load("missing_reference")
	assert_that(alpha.id).is_equal(&"alpha")
	assert_array(alpha.references).is_equal(before)
