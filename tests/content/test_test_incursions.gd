## The test incursions (M4c-16): all three load and validate; with a fixed seed each can be
## carried out with no defence and each can be beaten by a squad holding the Gate Room; the
## cheat actions start one, skip the warning and down every intruder.
## Bible: docs/content/m4c-incursions.md sections 5 and 6
extends GdUnitTestSuite

const IDS: Array[StringName] = [
	&"incursion_test_sabotage", &"incursion_test_theft", &"incursion_test_assault"
]

var _state: GameState
var _simulation: Simulation
var _ended: Array = []


func _setup() -> void:
	_state = GameState.new_game(21, Registry.balance())
	UnlockFixture.defence_plans(_state)
	_simulation = GameSetup.build_new(_state, GameDefs.from_registry(Registry)).value
	_simulation.event_posted.connect(_on_event)
	_ended.clear()
	var record := ArtefactRecord.new()
	record.uid = 1
	record.artefact = &"artefact_x"
	_state.artefacts.items.append(record)


func _on_event(event_name: StringName, args: Array) -> void:
	if event_name == &"incursion_ended":
		_ended.append(args[0])


func _run(id: StringName) -> void:
	DebugCheatCommand.force_enabled = 1
	DebugCheatCommand.create(&"incursion", id).apply(_state)
	DebugCheatCommand.create(&"skip_warning").apply(_state)
	DebugCheatCommand.force_enabled = -1
	for tick: int in 600:
		if not _state.incursion.is_active() or _state.outcome.has_failed():
			return
		_simulation.advance_tick()


func _squad_at_the_gate() -> void:
	var post: RoomState = null
	for x: int in range(2, _state.base.grid_size.x - 2):
		var command := PlaceRoomCommand.create(
			SquadRules.POST_DEF, 1, Vector2i(x, StartingBase.SPINE_ROW + 1)
		)
		if command.validate(_state).is_ok:
			command.apply(_state)
			post = _state.base.rooms[_state.base.rooms.size() - 1]
			post.build_ticks_left = 0
			break
	for index: int in 4:
		var person := PersonState.new()
		person.id = StringName("soldier_%d" % index)
		person.name = "S%d" % index
		person.role = SquadRules.SOLDIER
		person.skill = 10
		person.room_id = post.id
		_state.staff.people.append(person)
	SquadRules.sync(_state)
	_state.security.squads[0].pos = IncursionRules.gate_cell(_state)


func test_they_load_and_validate() -> void:
	for id: StringName in IDS:
		var def: IncursionDef = Registry.get_def(id) as IncursionDef
		assert_object(def).is_not_null()
		assert_array(def.get_content_errors(Registry._defs)).is_empty()
	(
		assert_bool((Registry.get_def(&"incursion_test_assault") as IncursionDef).breaches_shutter)
		. is_true()
	)


func test_each_can_be_carried_out() -> void:
	for id: StringName in IDS:
		_setup()
		_run(id)
		if id == &"incursion_test_assault":
			assert_str(String(_state.outcome.cause)).is_equal("overrun")
		else:
			assert_str(str(_ended[0]["outcome"])).override_failure_message(String(id)).is_equal(
				"done"
			)


func test_each_can_be_beaten() -> void:
	for id: StringName in IDS:
		_setup()
		_squad_at_the_gate()
		_run(id)
		assert_bool(_state.outcome.has_failed()).is_false()
		assert_str(str(_ended[0]["outcome"])).override_failure_message(String(id)).is_equal(
			"stopped"
		)
