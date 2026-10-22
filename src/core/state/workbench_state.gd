class_name WorkbenchState
extends RefCounted
## The Address Workbench draft: the origin glyph the player assumes and the constraints they
## have built from clues by hand. The candidate counter reads it; only SetWorkbenchCommand
## changes it.
## Saved shape: {"origin_glyph": -1 or a glyph, "constraints": [AddressConstraint]}.
## Bible: gate-and-address-spec.md#player-tools, technical-architecture.md#data-model

## Most constraints one draft can hold.
const MAX_CONSTRAINTS: int = 64
## Value of origin_glyph that means "use the home Ring's origin".
const HOME_ORIGIN: int = -1

## The origin glyph, 0..35, or HOME_ORIGIN (-1) for the home Ring's origin.
var origin_glyph: int = HOME_ORIGIN
## The draft's constraints, in the order the player added them.
var constraints: Array[AddressConstraint] = []


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var constraint_data: Array[Dictionary] = []
	for constraint: AddressConstraint in constraints:
		constraint_data.append(constraint.to_dict())
	return {"origin_glyph": origin_glyph, "constraints": constraint_data}


## Builds a WorkbenchState from saved [param data]; JSON floats become ints. Unreadable
## values keep their defaults and unreadable constraints are skipped. Call validate_dict()
## first for untrusted data.
static func from_dict(data: Dictionary) -> WorkbenchState:
	var workbench := WorkbenchState.new()
	workbench.origin_glyph = type_convert(data.get("origin_glyph", HOME_ORIGIN), TYPE_INT)
	var list: Variant = data.get("constraints")
	if not list is Array:
		return workbench
	var constraint_list: Array = list
	for item: Variant in constraint_list:
		if item is Dictionary:
			var constraint_data: Dictionary = item
			workbench.constraints.append(AddressConstraint.from_dict(constraint_data))
	return workbench


## Returns human-readable errors for saved [param data], empty when it is valid:
## "origin_glyph" a whole number from -1 to 35; "constraints" an array of at most
## MAX_CONSTRAINTS objects passing AddressConstraint.validate_dict().
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not is_valid_origin(data.get("origin_glyph")):
		errors.append(
			"'origin_glyph' is not a whole number from -1 to %d" % (GateAddress.GLYPH_COUNT - 1)
		)
	var list: Variant = data.get("constraints")
	if not list is Array:
		errors.append("'constraints' is not an array")
		return errors
	var constraint_list: Array = list
	if constraint_list.size() > MAX_CONSTRAINTS:
		errors.append("%d constraints, more than %d" % [constraint_list.size(), MAX_CONSTRAINTS])
	for index: int in constraint_list.size():
		if not constraint_list[index] is Dictionary:
			errors.append("constraint %d is not an object" % index)
			continue
		var constraint_data: Dictionary = constraint_list[index]
		for error: String in AddressConstraint.validate_dict(constraint_data):
			errors.append("constraint %d: %s" % [index, error])
	return errors


## True for an int, or a whole float, from HOME_ORIGIN (-1) to 35.
static func is_valid_origin(value: Variant) -> bool:
	if not JsonLimits.is_exact_int(value):
		return false
	var number: float = value
	return number >= float(HOME_ORIGIN) and number <= float(GateAddress.GLYPH_COUNT - 1)
