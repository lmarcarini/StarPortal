class_name SetFlagCommand
extends Command
## Sets one story or progress flag in GameState.flags. The simplest command; it proves
## the command pipeline (validate, apply, log, rebuild, replay) end to end.
## Bible: technical-architecture.md#simulation-clock-and-commands

## The command's stable type id.
const TYPE: StringName = &"set_flag"

## The flag to set; must not be empty.
var key: StringName
## The flag's new value: bool, int or String only.
var value: Variant

## Returns a command that sets flag [param key] to [param value].
@warning_ignore("shadowed_variable")
static func create(key: StringName, value: Variant) -> SetFlagCommand:
	var command := SetFlagCommand.new()
	command.key = key
	command.value = value
	return command


## Rebuilds a command from its to_dict() [param data], e.g. after a JSON round trip.
## Fails with &"malformed_command" when "key" is not a string or "value" is missing.
## Integral float values become ints again; other values are left for validate().
static func from_dict(data: Dictionary) -> Result:
	var key_data: Variant = data.get("key")
	if not (key_data is String or key_data is StringName):
		return Result.fail(&"malformed_command", "set_flag needs a string key")
	if not data.has("value"):
		return Result.fail(&"malformed_command", "set_flag needs a value")
	var value_data: Variant = data["value"]
	if value_data is float:
		var number: float = value_data
		value_data = _int_if_integral(number)
	return Result.ok(create(StringName(str(key_data)), value_data))


static func _int_if_integral(number: float) -> Variant:
	if number != floorf(number):
		return number
	return int(number)


## Returns &"set_flag".
func get_type() -> StringName:
	return TYPE


## Rejects an empty key (&"empty_key") and a value that is not bool, int or String
## (&"invalid_value"). Flags have no other preconditions, so [param state] is unused.
@warning_ignore("unused_parameter")
func validate(state: GameState) -> CommandResult:  # gdlint: ignore=unused-argument
	if key.is_empty():
		return CommandResult.fail(&"empty_key")
	if not (value is bool or value is int or value is String):
		return CommandResult.fail(
			&"invalid_value", "flag %s: %s" % [key, type_string(typeof(value))]
		)
	return CommandResult.ok()


## Sets the flag in [param state].
func apply(state: GameState) -> void:
	state.flags[key] = value


## Returns JSON-safe data: type, key and value.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "key": String(key), "value": value}
