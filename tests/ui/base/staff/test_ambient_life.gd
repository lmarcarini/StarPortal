## Ambient life: pure rules, no spot shared, night shifts, interruption, and no effect on the
## simulation's state.
## Bible: docs/content/interface-pass.md section 5 (Ambient life)
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"


func test_night_and_on_shift() -> void:
	assert_bool(AmbientRules.is_night(23)).is_true()
	assert_bool(AmbientRules.is_night(5)).is_true()
	assert_bool(AmbientRules.is_night(12)).is_false()
	for index: int in 20:
		assert_bool(AmbientRules.on_shift(StringName("p%d" % index), 12)).is_true()
	var night: int = 0
	for index: int in 40:
		if AmbientRules.on_shift(StringName("p%d" % index), 2):
			night += 1
	assert_int(night).is_less(30)


func test_next_move_never_picks_a_taken_spot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var state := AmbientState.new()
	state.spot_count = 4
	state.taken = [0, 2]
	for _try: int in 200:
		var move: AmbientMove = AmbientRules.next_move(rng, state)
		if move.kind == AmbientMove.SPOT:
			assert_bool(state.taken.has(move.index)).is_false()
	state.taken = [0, 1, 2, 3]
	for _try: int in 50:
		assert_str(String(AmbientRules.next_move(rng, state).kind)).is_not_equal("spot")


func _run(ambient_on: bool) -> Dictionary:
	var shell := (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	shell.new_game_seed = 21
	var runner: GdUnitSceneRunner = scene_runner(shell)
	await runner.await_input_processed()
	shell.view_switcher.show_view(ViewSwitcher.BASE)
	var base: BaseView = shell.view_switcher.get_view(ViewSwitcher.BASE) as BaseView
	var layer: StaffLayer = base.get_plan().staff_layer
	var state: GameState = SimClock.simulation.state
	for person: PersonState in StaffLayer.on_base(state):
		if person.room_id == &"":
			person.room_id = state.base.rooms[0].id
	layer.rebuild(state)
	for _round: int in 30:
		SimClock.step_ticks(20)
		if ambient_on:
			layer.ambient.step(layer, state, 3.0, 1.0)
			var tokens: Dictionary[StringName, StaffToken] = {}
			for token: StaffToken in layer.tokens():
				tokens[token.person_id] = token
			layer.walker.step(tokens, 2.0, 1, false)
	var data: Dictionary = state.to_dict()
	shell.free()
	return data


func test_ambient_life_never_changes_the_simulation() -> void:
	var with_life: Dictionary = await _run(true)
	var without: Dictionary = await _run(false)
	assert_str(JSON.stringify(with_life)).is_equal(JSON.stringify(without))


func test_moves_keep_spots_unique_and_rebuild_interrupts() -> void:
	var shell := (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	shell.new_game_seed = 22
	var runner: GdUnitSceneRunner = scene_runner(shell)
	await runner.await_input_processed()
	var base: BaseView = shell.view_switcher.get_view(ViewSwitcher.BASE) as BaseView
	var layer: StaffLayer = base.get_plan().staff_layer
	var state: GameState = SimClock.simulation.state
	for person: PersonState in StaffLayer.on_base(state):
		person.room_id = state.base.rooms[0].id
	layer.rebuild(state)
	for _round: int in 40:
		layer.ambient.step(layer, state, 5.0, 1.0)
		var homes: Array[Vector2] = []
		for token: StaffToken in layer.tokens():
			if token.room_id != &"" and token.home_level == state.base.rooms[0].level:
				assert_bool(homes.has(token.home)).is_false()
				homes.append(token.home)
		layer.walker.snap_all(layer.tokens())
	layer.rebuild(state)
	layer.walker.snap_all(layer.tokens())
	for token: StaffToken in layer.tokens():
		assert_bool(layer.walker.is_moving(token.person_id)).is_false()
	shell.free()
