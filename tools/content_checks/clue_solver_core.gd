class_name ClueSolverCore
extends RefCounted
## The pure part of the Clue Solver tool: counting what each clue leaves, reading a constraints
## file, reading the command line and describing clues as plain text. Tuning aid only; never
## shipped, and nothing in `src/` refers to it.
## Bible: technical-architecture.md#testing-and-tooling,
## gate-and-address-spec.md#puzzle-tuning-rules

## Options a command line may carry, with the type of their value.
const OPTION_TYPES: Dictionary = {
	"--seed": TYPE_INT,
	"--world": TYPE_STRING,
	"--constraints": TYPE_STRING,
	"--origin": TYPE_INT,
	"--list": TYPE_INT,
}
## What the tool prints when it is called wrongly.
const USAGE: String = (
	"usage: clue_solver.gd -- --seed <int> --world <id or designation> [--list <n>]\n"
	+ "       clue_solver.gd -- --constraints <file.json> [--origin <glyph 0..35>] [--list <n>]"
)


## Returns how many addresses dialed from [param origin] fit the first 0, 1, 2, ... groups of
## constraints: the entry at index i counts the groups 0..i-1, so the first entry is the count
## with no clue at all and the array has one more entry than [param groups]. Each group is an
## array of [AddressConstraint] (the constraints of one clue).
static func counts_after(groups: Array[Array], origin: int) -> Array[int]:
	var counts: Array[int] = []
	var constraints: Array[AddressConstraint] = []
	counts.append(CandidateCounter.count(constraints, origin))
	for group: Array in groups:
		for constraint: AddressConstraint in group:
			constraints.append(constraint)
		counts.append(CandidateCounter.count(constraints, origin))
	return counts


## Returns the constraints of every clue in [param clues] as one group per clue.
static func groups_of(clues: Array[ClueRecord]) -> Array[Array]:
	var groups: Array[Array] = []
	for clue: ClueRecord in clues:
		groups.append(clue.constraints)
	return groups


## Reads [param text], a JSON list of [method AddressConstraint.to_dict] dictionaries. Returns
## an ok [Result] holding an [code]Array[AddressConstraint][/code], or a failed one whose
## detail names the problem and where it is.
static func parse_constraints(text: String) -> Result:
	var json := JSON.new()
	if json.parse(text) != OK:
		return Result.fail(
			&"bad_json",
			"not valid JSON (line %d): %s" % [json.get_error_line(), json.get_error_message()]
		)
	if not json.data is Array:
		return Result.fail(&"not_a_list", "expected a JSON list of constraints")
	var entries: Array = json.data
	var constraints: Array[AddressConstraint] = []
	for index: int in entries.size():
		if not entries[index] is Dictionary:
			return Result.fail(&"bad_constraint", "constraint %d is not an object" % (index + 1))
		var entry: Dictionary = entries[index]
		var problems: Array[String] = AddressConstraint.validate_dict(entry)
		if not problems.is_empty():
			return Result.fail(&"bad_constraint", "constraint %d: %s" % [index + 1, problems[0]])
		constraints.append(AddressConstraint.from_dict(entry))
	return Result.ok(constraints)


## Reads the command line [param args] (what follows `--`). Returns an ok [Result] holding a
## Dictionary of the options given (typed per OPTION_TYPES), or a failed one that names the
## problem. Needs either --constraints, or --seed with --world.
static func parse_args(args: PackedStringArray) -> Result:
	var options: Dictionary = {}
	var index: int = 0
	while index < args.size():
		var name: String = args[index]
		if not OPTION_TYPES.has(name):
			return Result.fail(&"unknown_option", "unknown option '%s'" % name)
		if index + 1 >= args.size():
			return Result.fail(&"missing_value", "%s needs a value" % name)
		var value: String = args[index + 1]
		if OPTION_TYPES[name] == TYPE_INT:
			if not value.is_valid_int():
				return Result.fail(
					&"bad_value", "%s needs a whole number, got '%s'" % [name, value]
				)
			options[name] = value.to_int()
		else:
			options[name] = value
		index += 2
	return _check_options(options)


## One line per clue: its kind, text key, arguments and source, then its constraints.
static func describe_clue(clue: ClueRecord) -> String:
	var args: Array[String] = []
	var names: Array = clue.text_args.keys()
	names.sort()
	for arg_name: String in names:
		args.append("%s=%s" % [arg_name, clue.text_args[arg_name]])
	var constraints: Array[String] = []
	for constraint: AddressConstraint in clue.constraints:
		constraints.append(describe_constraint(constraint))
	var head: String = " ".join([str(clue.text_key)] + args)
	return (
		"[%s] %s (source %s, grade %d)\n    says: %s"
		% [
			ClueRecord.KIND_NAMES[clue.kind],
			head,
			clue.source_key,
			clue.grade,
			"; ".join(constraints),
		]
	)


## A constraint as short text, e.g. "glyph 14 at seal 2" or "glyph 3 absent".
static func describe_constraint(constraint: AddressConstraint) -> String:
	var glyphs: Array[String] = []
	for glyph: int in constraint.glyphs:
		glyphs.append(str(glyph))
	var list: String = ",".join(glyphs)
	match constraint.kind:
		AddressConstraint.Kind.GLYPH_AT:
			return "glyph %s at seal %d" % [list, constraint.seal]
		AddressConstraint.Kind.GLYPH_NOT_AT:
			return "glyph %s not at seal %d" % [list, constraint.seal]
		AddressConstraint.Kind.EXCLUDED:
			return "glyph %s absent" % list
		AddressConstraint.Kind.INCLUDED:
			return "glyph %s present" % list
		AddressConstraint.Kind.EXACT_SET:
			return "exactly the glyphs {%s}" % list
		AddressConstraint.Kind.NEARER_THAN:
			return "glyph %s nearer than %s (if the second is present)" % [glyphs[0], glyphs[1]]
	return "unknown constraint"


static func _check_options(options: Dictionary) -> Result:
	if options.has("--constraints") == (options.has("--seed") or options.has("--world")):
		return Result.fail(&"bad_mode", "give either --constraints, or --seed with --world")
	if not options.has("--constraints") and not (options.has("--seed") and options.has("--world")):
		return Result.fail(&"bad_mode", "--seed and --world go together")
	if options.get("--origin", 0) < 0 or options.get("--origin", 0) >= GateAddress.GLYPH_COUNT:
		return Result.fail(&"bad_value", "--origin must be a glyph from 0 to 35")
	if options.has("--origin") and options.has("--seed"):
		return Result.fail(&"bad_mode", "--origin only goes with --constraints")
	return Result.ok(options)
