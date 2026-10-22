extends SceneTree
## Content validator: loads the real content and runs every check of tools/content_checks/.
## Prints one line per problem and exits non-zero when there is any. Run from the project root
## (scripts/validate.sh does this): `godot --headless --path . --script tools/validate_content.gd`
## Tool code only: it is not part of the game and `tools/` is not exported.
## Bible: technical-architecture.md#testing-and-tooling


func _init() -> void:
	var started: int = Time.get_ticks_msec()
	var registry: ContentSource.RegistryScript = ContentSource.new_registry()
	var load_errors: Array[String] = registry.load_all().value
	var errors: Array[String] = ContentValidator.run(
		registry, load_errors, ContentValidator.DEFAULT_SEEDS, true
	)
	registry.free()
	for line: String in errors:
		print("PROBLEM: " + line)
	var elapsed: int = Time.get_ticks_msec() - started
	if errors.is_empty():
		print("validate: content is valid (%d ms)" % elapsed)
		quit(0)
		return
	print("validate: %d problem(s) (%d ms)" % [errors.size(), elapsed])
	quit(1)
