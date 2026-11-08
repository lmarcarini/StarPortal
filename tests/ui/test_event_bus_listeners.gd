## Every listener the running shell connects to an EventBus signal can take that signal's
## arguments: a signal that gains an argument (as team_checked_in did) fails here instead of
## dropping the call at runtime with only an engine error.
## Bible: technical-architecture.md#architecture-overview (events out through the EventBus)
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

var _shell: ShellScript = null
var _real_saves_dir: String = ""


func before_test() -> void:
	_real_saves_dir = SaveService.saves_dir
	SaveService.saves_dir = "user://test_event_bus_listeners_%d" % Time.get_ticks_usec()
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 1
	var runner: GdUnitSceneRunner = scene_runner(_shell)
	await runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()
	SaveService.saves_dir = _real_saves_dir


func test_every_listener_takes_its_signals_arguments() -> void:
	var checked: int = 0
	for info: Dictionary in EventBus.get_signal_list():
		var name: StringName = info["name"]
		var args: Array = info["args"]
		var count: int = args.size()
		for connection: Dictionary in EventBus.get_signal_connection_list(name):
			var callable: Callable = connection["callable"]
			var range_of: Vector2i = _accepted(callable)
			(
				assert_bool(count >= range_of.x and count <= range_of.y)
				. override_failure_message(
					(
						"%s (%d args) -> %s accepts %d..%d"
						% [name, count, callable, range_of.x, range_of.y]
					)
				)
				. is_true()
			)
			checked += 1
	assert_int(checked).is_greater(20)


## The fewest and most signal arguments [param callable] accepts, after its bound arguments.
static func _accepted(callable: Callable) -> Vector2i:
	var bound: int = callable.get_bound_arguments_count()
	var target: Object = callable.get_object()
	var method: StringName = callable.get_method()
	if target != null and not callable.is_custom():
		for info: Dictionary in target.get_method_list():
			if info["name"] != method:
				continue
			var args: Array = info["args"]
			var defaults: Array = info["default_args"]
			var flags: int = info["flags"]
			var total: int = args.size() - bound
			var required: int = total - defaults.size()
			var most: int = 1 << 20 if (flags & METHOD_FLAG_VARARG) != 0 else total
			return Vector2i(required, most)
	var lambda_count: int = callable.get_argument_count()
	return Vector2i(lambda_count, lambda_count)
