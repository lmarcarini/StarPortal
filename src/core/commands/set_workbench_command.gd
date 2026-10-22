class_name SetWorkbenchCommand
extends Command
## Replaces the Address Workbench draft: its origin glyph and all its constraints. Posts
## workbench_changed once when applied.
## Bible: gate-and-address-spec.md#player-tools,
## technical-architecture.md#simulation-clock-and-commands

## The command's stable type id.
const TYPE: StringName = &"set_workbench"

## The new origin glyph, 0..35, or WorkbenchState.HOME_ORIGIN (-1).
var origin_glyph: int = WorkbenchState.HOME_ORIGIN
## The new constraints, replacing every old one.
var constraints: Array[AddressConstraint] = []

## Returns a command that sets the draft to [param origin_glyph] and [param constraints].
@warning_ignore("shadowed_variable")
static func create(origin_glyph: int, constraints: Array[AddressConstraint]) -> SetWorkbenchCommand:
	var command := SetWorkbenchCommand.new()
	command.origin_glyph = origin_glyph
	command.constraints = constraints.duplicate()
	return command


## Rebuilds a command from its to_dict() [param data], e.g. after a JSON round trip. Fails
## with &"malformed_command" when "origin_glyph" is not a whole number, "constraints" is not
## an array, or a constraint is not an object passing AddressConstraint.validate_dict(). The
## origin's range and the number of constraints are left for validate().
static func from_dict(data: Dictionary) -> Result:
	var origin_data: Variant = data.get("origin_glyph")
	if not JsonLimits.is_exact_int(origin_data):
		return Result.fail(&"malformed_command", "set_workbench needs a whole origin_glyph")
	var list: Variant = data.get("constraints")
	if not list is Array:
		return Result.fail(&"malformed_command", "set_workbench needs a constraints array")
	var constraint_list: Array = list
	var built: Array[AddressConstraint] = []
	for index: int in constraint_list.size():
		var item: Variant = constraint_list[index]
		if not item is Dictionary:
			return Result.fail(&"malformed_command", "constraint %d is not an object" % index)
		var constraint_data: Dictionary = item
		var errors := AddressConstraint.validate_dict(constraint_data)
		if not errors.is_empty():
			return Result.fail(&"malformed_command", "constraint %d: %s" % [index, errors[0]])
		built.append(AddressConstraint.from_dict(constraint_data))
	var origin: int = type_convert(origin_data, TYPE_INT)
	return Result.ok(create(origin, built))


## Returns &"set_workbench".
func get_type() -> StringName:
	return TYPE


## Rejects an origin outside -1..35 (&"invalid_origin"), more than
## WorkbenchState.MAX_CONSTRAINTS constraints (&"too_many_constraints") and a null or
## malformed constraint (&"malformed_constraint"). The draft has no other preconditions, so
## [param state] is unused.
@warning_ignore("unused_parameter")
func validate(state: GameState) -> CommandResult:  # gdlint: ignore=unused-argument
	if not WorkbenchState.is_valid_origin(origin_glyph):
		return CommandResult.fail(&"invalid_origin", "origin glyph %d" % origin_glyph)
	if constraints.size() > WorkbenchState.MAX_CONSTRAINTS:
		return CommandResult.fail(
			&"too_many_constraints",
			"%d, more than %d" % [constraints.size(), WorkbenchState.MAX_CONSTRAINTS]
		)
	for index: int in constraints.size():
		var constraint: AddressConstraint = constraints[index]
		if constraint == null or not constraint.is_well_formed():
			return CommandResult.fail(&"malformed_constraint", "constraint %d" % index)
	return CommandResult.ok()


## Replaces the draft in [param state] with copies of the command's constraints and posts
## workbench_changed.
func apply(state: GameState) -> void:
	state.workbench.origin_glyph = origin_glyph
	var copies: Array[AddressConstraint] = []
	for constraint: AddressConstraint in constraints:
		copies.append(AddressConstraint.from_dict(constraint.to_dict()))
	state.workbench.constraints = copies
	state.events.post(&"workbench_changed")


## Returns JSON-safe data: type, origin glyph and constraints.
func to_dict() -> Dictionary:
	var constraint_data: Array[Dictionary] = []
	for constraint: AddressConstraint in constraints:
		constraint_data.append(constraint.to_dict() if constraint != null else {})
	return {"type": String(TYPE), "origin_glyph": origin_glyph, "constraints": constraint_data}
