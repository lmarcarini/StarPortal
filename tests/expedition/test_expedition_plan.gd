## Tests for planning and sending a team (PlanExpeditionCommand, SendTeamCommand,
## ExpeditionRules): any role leads, each slot takes its roles, Survey needs a Probed world and
## Recover a recoverable target; Send needs the wormhole open to the world with 10 minutes left
## on its time limit and on its charge, and gives a clear reason otherwise.
## Bible: docs/content/m3-beyond-the-ring.md section 4 (The team, Objectives, Departure)
extends GdUnitTestSuite

const Fixture := preload("res://tests/expedition/expedition_fixture.gd")
const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	_state = Fixture.state()
	_simulation = Fixture.simulation(_state)


func _error(command: Command) -> String:
	return String(command.validate(_state).error_code)


func test_locked_before_the_unlock() -> void:
	_state.flags.erase(ExpeditionUnlock.FLAG)
	assert_str(_error(Fixture.survey(_state))).is_equal("expeditions_locked")


func test_any_role_can_lead() -> void:
	for role: StringName in [StartingStaff.ANALYST, StartingStaff.SOLDIER, StartingStaff.ENGINEER]:
		var team: Dictionary = Fixture.team(_state)
		var taken: Array = team.values()
		var leader: PersonState = Fixture.person_of(_state, role, taken)
		if leader == null:
			continue
		team["leader"] = leader.id
		var command := PlanExpeditionCommand.create(
			ExpeditionState.Objective.SURVEY, Fixture.WORLD_ID, &"", team
		)
		assert_str(_error(command)).is_empty()


func test_slots_take_their_roles() -> void:
	var team: Dictionary = Fixture.team(_state)
	team["soldier"] = Fixture.person_of(_state, StartingStaff.ANALYST).id
	var command := PlanExpeditionCommand.create(
		ExpeditionState.Objective.SURVEY, Fixture.WORLD_ID, &"", team
	)
	assert_str(_error(command)).is_equal("wrong_role")
	team = Fixture.team(_state)
	team["specialist"] = team["scientist"]
	command.team = team
	assert_str(_error(command)).is_equal("duplicate_member")
	team.erase("leader")
	command.team = team
	assert_str(_error(command)).is_equal("team_incomplete")


func test_injured_member_refused() -> void:
	var command: PlanExpeditionCommand = Fixture.survey(_state)
	var soldier_id: StringName = command.team["soldier"]
	InjuryRules.injure(_state.staff.find_person(soldier_id), PersonState.Injury.LIGHT)
	assert_str(_error(command)).is_equal("member_injured")


func test_objectives_need_their_world_state() -> void:
	_state.worlds.statuses.erase(Fixture.WORLD_ID)
	assert_str(_error(Fixture.survey(_state))).is_equal("world_not_probed")
	_state.worlds.statuses[Fixture.WORLD_ID] = WorldsState.WorldStatus.LOCKED
	assert_str(_error(Fixture.recover(_state))).is_equal("target_not_recoverable")
	WorldProgress.raise_target(
		_state, Fixture.WORLD_ID, Fixture.ANCHOR_ID, TargetStates.State.RECOVERABLE
	)
	assert_str(_error(Fixture.recover(_state))).is_empty()


func test_plan_sets_the_plan_and_round_trips() -> void:
	var command: PlanExpeditionCommand = Fixture.survey(_state)
	assert_bool(_simulation.submit(command).is_ok).is_true()
	assert_int(_state.expedition.mode).is_equal(ExpeditionState.Mode.PLANNED)
	assert_int(_state.expedition.member_ids().size()).is_equal(4)
	var data: Dictionary = JSON.parse_string(JSON.stringify(command.to_dict()))
	var rebuilt: Result = CommandFactory.from_dict(data)
	assert_bool(rebuilt.is_ok).is_true()
	var again: PlanExpeditionCommand = rebuilt.value
	assert_dict(again.to_dict()).is_equal(command.to_dict())
	assert_bool(CommandFactory.from_dict({"type": "send_team"}).is_ok).is_true()


func test_send_needs_plan_and_open_wormhole_to_the_world() -> void:
	assert_str(_error(SendTeamCommand.new())).is_equal("no_plan")
	_simulation.submit(Fixture.survey(_state))
	assert_str(_error(SendTeamCommand.new())).is_equal("no_wormhole")
	ProbeFixture.open(_simulation)
	_state.gate.connected_world_id = &"elsewhere"
	assert_str(_error(SendTeamCommand.new())).is_equal("wrong_world")
	_state.gate.connected_world_id = Fixture.WORLD_ID
	assert_str(_error(SendTeamCommand.new())).is_empty()


func test_send_refused_near_the_time_limit() -> void:
	_simulation.submit(Fixture.survey(_state))
	ProbeFixture.open(_simulation)
	var limit: int = _state.balance.max_open_ticks
	_state.gate.lock_started_tick = _state.clock.tick - (limit - 10)
	assert_str(_error(SendTeamCommand.new())).is_empty()
	_state.gate.lock_started_tick -= 1
	var result: CommandResult = SendTeamCommand.new().validate(_state)
	assert_str(String(result.error_code)).is_equal("not_enough_open_time")
	assert_str(result.detail).is_equal("EXPEDITION_NOT_ENOUGH_TIME")


func test_send_refused_on_low_charge() -> void:
	_simulation.submit(Fixture.survey(_state))
	ProbeFixture.open(_simulation)
	for bank_id: StringName in _state.power.charge_rates:
		_state.power.charge_rates[bank_id] = 0
	var net: float = PowerRules.charge_mw(_state) - PowerMath.drain_mw(_state.gate, _state.balance)
	assert_float(net).is_less(0.0)
	_state.power.stored_mwh = -net / 60.0 * 10.0 + 0.001
	assert_int(ExpeditionRules.open_ticks_left(_state)).is_equal(10)
	assert_str(_error(SendTeamCommand.new())).is_empty()
	_state.power.stored_mwh = -net / 60.0 * 9.5
	assert_str(_error(SendTeamCommand.new())).is_equal("not_enough_open_time")
