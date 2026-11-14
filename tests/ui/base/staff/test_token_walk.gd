## Reassigning a person walks their token on the plan while the simulation has already
## moved them; a level change snaps everyone home.
## Bible: docs/content/interface-pass.md section 5 (Staff walk)
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null


func before_test() -> void:
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 4
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()
	_shell.view_switcher.show_view(ViewSwitcher.BASE)
	await _runner.simulate_frames(2)


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()


func _layer() -> StaffLayer:
	var base: BaseView = _shell.view_switcher.get_view(ViewSwitcher.BASE) as BaseView
	return base.get_plan().staff_layer


func test_unassigning_walks_the_token_and_assignment_is_immediate() -> void:
	var state: GameState = SimClock.simulation.state
	var person: PersonState = null
	for candidate: PersonState in StaffLayer.on_base(state):
		if candidate.room_id != &"":
			person = candidate
	assert_object(person).is_not_null()
	var token: StaffToken = _layer().token_for(person.id)
	var start: Vector2 = token.position
	SimClock.simulation.submit(UnassignStaffCommand.create(person.id))
	SimClock.step_ticks(1)
	assert_str(String(state.staff.find_person(person.id).room_id)).is_equal("")
	assert_bool(_layer().walker.is_moving(person.id)).is_true()
	assert_object(token.position).is_equal(start)
	SimClock.resume()
	await _runner.simulate_frames(10)
	assert_object(token.position).is_not_equal(start)
	_layer().snap()
	assert_object(token.position).is_equal(token.home)
