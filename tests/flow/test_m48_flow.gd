## The M4.8 flow end to end on the real content, through the dialogue screen: at 10× cruise,
## dial HEARTH and hail the Kindred; the screen opens and holds the clock; read the lines, pick
## an answer, close at the end; the clock is back at 10× and running, the tick unchanged by the
## conversation. Then answer the Committee's call, save mid-conversation and load: the screen
## reopens at the same line and the call can be finished.
## Saves go to a temporary user:// folder, never user://saves.
## Bible: docs/content/dialogue-screen.md
extends GdUnitTestSuite

const DialFixture := preload("res://tests/gate/dial_fixture.gd")
const PowerFixture := preload("res://tests/power/power_fixture.gd")
const CRUISE: int = 3

var _state: GameState
var _simulation: Simulation
var _root := Control.new()
var _screen := DialogueScreen.new()
var _real_saves_dir: String = ""


func before_test() -> void:
	_real_saves_dir = SaveService.saves_dir
	SaveService.saves_dir = "user://test_m48_flow_%d" % Time.get_ticks_usec()
	TranslationServer.set_locale("en")
	var defs: GameDefs = GameDefs.from_registry(Registry)
	_state = GameState.new_game(7, defs.balance)
	_simulation = GameSetup.build_new(_state, defs).value
	_state.clock.mode = ClockState.Mode.RUNNING
	_state.clock.speed_index = CRUISE
	EventBus.bind_simulation(_simulation)
	_root.size = Vector2(1280, 720)
	_root.add_child(_screen)
	add_child(_root)
	_screen.bind(_simulation)


func after_test() -> void:
	EventBus.bind_simulation(null)
	_root.free()
	for file: String in DirAccess.get_files_at(SaveService.saves_dir):
		DirAccess.remove_absolute(SaveService.saves_dir.path_join(file))
	DirAccess.remove_absolute(SaveService.saves_dir)
	SaveService.saves_dir = _real_saves_dir


func _ticks(count: int) -> void:
	for index: int in count:
		_simulation.advance_tick()


func _submit(command: Command) -> void:
	var result: CommandResult = _simulation.submit(command)
	(
		assert_bool(result.is_ok)
		. override_failure_message("%s refused: %s" % [command.get_type(), result.error_code])
		. is_true()
	)
	_ticks(1)


func _build_and_dial(world: StringName) -> void:
	_submit(PowerFixture.build_first_bank(_state))
	for guard: int in 30 * TimeMath.TICKS_PER_DAY:
		if PowerRules.capacity_of(_state, PowerRules.totals(_state)) > 0.0:
			break
		_ticks(1)
	_state.power.stored_mwh = PowerRules.capacity_of(_state, PowerRules.totals(_state))
	_submit(DialCommand.create(DialFixture.address_of(_state.galaxy, world)))
	_ticks(_state.balance.dial_duration_ticks + 1)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)


## Continue (twice on a typing line) until a choice or the end.
func _read_on() -> void:
	for guard: int in 40:
		var active: ActiveConversation = _state.conversations.active
		if active == null or active.phase == ActiveConversation.Phase.CHOICE:
			return
		if active.phase == ActiveConversation.Phase.ENDED:
			return
		_screen.continue_pressed()


func test_hail_at_cruise_speed_then_save_and_load_a_call() -> void:
	_build_and_dial(&"world_hearth")
	assert_int(_state.clock.speed_index).is_equal(CRUISE)
	var charge: float = _state.power.stored_mwh
	var tick: int = _state.clock.tick
	_simulation.submit(HailCommand.new())
	_ticks(5)
	assert_bool(_screen.visible).is_true()
	assert_int(_state.clock.mode).is_equal(ClockState.Mode.HELD)
	assert_int(_state.clock.tick).is_equal(tick)
	_read_on()
	assert_int(_state.conversations.active.phase).is_equal(ActiveConversation.Phase.CHOICE)
	assert_bool(_screen.pick_number(1)).is_true()
	_read_on()
	assert_int(_state.conversations.active.phase).is_equal(ActiveConversation.Phase.ENDED)
	assert_str(_screen.link.get_text()).is_equal("LINK CLOSED")
	assert_int(_state.clock.tick).is_equal(tick)
	assert_float(_state.power.stored_mwh).is_equal(charge)
	_screen.continue_pressed()
	assert_bool(_screen.visible).is_false()
	assert_int(_state.clock.mode).is_equal(ClockState.Mode.RUNNING)
	assert_int(_state.clock.speed_index).is_equal(CRUISE)
	assert_bool(_state.conversations.transcripts[-1].cut_off).is_false()
	_ticks(1)
	assert_int(_state.clock.tick).is_equal(tick + 1)
	_answer_call_save_and_load()


func _answer_call_save_and_load() -> void:
	_submit(CloseWormholeCommand.new())
	var contact := PendingContact.new()
	contact.faction = &"faction_committee"
	contact.conversation = &"conv_committee_checkin"
	contact.channel = &"phone"
	contact.since_tick = _state.clock.tick
	_state.factions.pending.append(contact)
	_simulation.submit(AnswerCallCommand.new())
	_ticks(1)
	assert_bool(_screen.visible).is_true()
	assert_str(_screen.get_strip_texts()[2]).is_equal("SECURE LINE · EARTH")
	_screen.continue_pressed()
	var line_before: String = _screen.transcript.get_texts()[-1]
	var node_before: StringName = _state.conversations.active.node
	assert_bool(SaveService.save_game(_state, &"mid_call").is_ok).is_true()
	var loaded: Result = SaveService.load_game(&"mid_call", GameDefs.from_registry(Registry))
	assert_bool(loaded.is_ok).is_true()
	var state: GameState = loaded.value
	_simulation = GameSetup.build(state, GameDefs.from_registry(Registry)).value
	_state = state
	EventBus.bind_simulation(_simulation)
	_screen.bind(_simulation)
	assert_bool(_screen.visible).is_true()
	assert_str(String(state.conversations.active.node)).is_equal(String(node_before))
	assert_str(_screen.transcript.get_texts()[-1]).is_equal(line_before)
	assert_int(state.clock.mode).is_equal(ClockState.Mode.HELD)
	ConversationDriver.play(state, [0], false)
	_screen.bind(_simulation)
	_screen.continue_pressed()
	assert_object(state.conversations.active).is_null()
	assert_bool(_screen.visible).is_false()
	assert_int(state.clock.mode).is_equal(ClockState.Mode.RUNNING)
