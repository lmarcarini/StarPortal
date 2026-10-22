extends SceneTree
## Clue Solver: counts the candidate addresses a dossier leaves, clue by clue. Used for tuning;
## never shipped, and `tools/` is not exported. Plain text on standard output.
##
## godot --headless --path . --script tools/clue_solver.gd -- --seed 7 --world R-0042 [--list 10]
##   Generates the galaxy of the seed, prints the world's designation and address from the home
##   Ring, then each clue of a fresh dossier (rng seeded with the same seed) and the candidates
##   left after each.
## godot --headless --path . --script tools/clue_solver.gd -- --constraints file.json
##   Counts a JSON list of AddressConstraint dictionaries instead (add --origin <glyph> to
##   dial from another origin than the home Ring's).
## --list <n> also prints up to n of the candidates that remain.
## Exit code: 0 on success, 1 on bad input.
## Bible: technical-architecture.md#testing-and-tooling


func _init() -> void:
	quit(_run(OS.get_cmdline_user_args()))


func _run(args: PackedStringArray) -> int:
	var parsed: Result = ClueSolverCore.parse_args(args)
	if not parsed.is_ok:
		return _fail(parsed.detail + "\n" + ClueSolverCore.USAGE)
	var options: Dictionary = parsed.value
	var registry: ContentSource.RegistryScript = ContentSource.new_registry()
	var load_errors: Array[String] = registry.load_all().value
	var code: int = 1
	if not load_errors.is_empty():
		_fail("content has errors; run scripts/validate.sh\n" + "\n".join(load_errors))
	elif options.has("--constraints"):
		code = _solve_file(registry, options)
	else:
		code = _solve_world(registry, options)
	registry.free()
	return code


func _solve_file(registry: ContentSource.RegistryScript, options: Dictionary) -> int:
	var path: String = options["--constraints"]
	if not FileAccess.file_exists(path):
		return _fail("constraints file not found: " + path)
	var parsed: Result = ClueSolverCore.parse_constraints(FileAccess.get_file_as_string(path))
	if not parsed.is_ok:
		return _fail("%s: %s" % [path, parsed.detail])
	var constraints: Array[AddressConstraint] = []
	var parsed_list: Array = parsed.value
	constraints.assign(parsed_list)
	var origin: int = _origin_of(registry, options)
	var limit: int = options.get("--list", 0)
	var groups: Array[Array] = []
	for constraint: AddressConstraint in constraints:
		groups.append([constraint])
	print("origin glyph %d, %d constraints" % [origin, constraints.size()])
	var counts: Array[int] = ClueSolverCore.counts_after(groups, origin)
	print("no constraints: %d candidates" % counts[0])
	for index: int in constraints.size():
		print("%d. %s" % [index + 1, ClueSolverCore.describe_constraint(constraints[index])])
		print("    candidates after: %d" % counts[index + 1])
	_print_candidates(constraints, origin, limit)
	return 0


## The --origin given, else the origin glyph of the home Ring.
func _origin_of(registry: ContentSource.RegistryScript, options: Dictionary) -> int:
	if options.has("--origin"):
		return options["--origin"]
	var home: WorldDef = null
	for world: WorldDef in ContentSource.authored_worlds(registry):
		if world.is_home:
			home = world
	if home == null:
		return 0
	return home.origin_glyph


func _solve_world(registry: ContentSource.RegistryScript, options: Dictionary) -> int:
	var seed_number: int = options["--seed"]
	var name: String = options["--world"]
	var limit: int = options.get("--list", 0)
	var galaxy: GalaxyCatalogue = ContentSource.galaxy(registry, seed_number)
	var world: WorldRecord = _find_world(galaxy, name)
	if world == null:
		return _fail("no world '%s' in the galaxy of seed %d" % [name, seed_number])
	var origin: int = galaxy.home().origin_glyph
	var address: GateAddress = galaxy.address_of(world.id, origin)
	print("seed %d, world %s (%s)" % [seed_number, world.designation, world.id])
	print("address from the home Ring: %s" % address.key())
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_number
	var clues: Array[ClueRecord] = ClueGenerator.generate_dossier(
		world.id, galaxy, rng, ClueSetParams.new()
	)
	var counts: Array[int] = ClueSolverCore.counts_after(ClueSolverCore.groups_of(clues), origin)
	print("no clues: %d candidates" % counts[0])
	for index: int in clues.size():
		print("%d. %s" % [index + 1, ClueSolverCore.describe_clue(clues[index])])
		print("    candidates after: %d" % counts[index + 1])
	var constraints: Array[AddressConstraint] = []
	for clue: ClueRecord in clues:
		constraints.append_array(clue.constraints)
	_print_candidates(constraints, origin, limit)
	return 0


## The world with id or designation [param name], or null.
func _find_world(galaxy: GalaxyCatalogue, name: String) -> WorldRecord:
	for world: WorldRecord in galaxy.all_worlds():
		if str(world.id) == name or world.designation == name:
			return world
	return null


func _print_candidates(constraints: Array[AddressConstraint], origin: int, limit: int) -> void:
	if limit <= 0:
		return
	var found: Array[GateAddress] = CandidateCounter.list(constraints, origin, limit)
	print("candidates (up to %d):" % limit)
	for address: GateAddress in found:
		print("    " + address.key())


func _fail(message: String) -> int:
	print("clue_solver: " + message)
	return 1
