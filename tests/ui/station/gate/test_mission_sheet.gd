## Tests for the mission sheet: TEAM opens it prefilled, GO plans and sends (two actions with
## a wormhole open), the last plan per world is remembered, refusals show beside the team,
## and an injured member is replaced by the best fit person.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Teams)
extends GdUnitTestSuite

const Fixture := preload("res://tests/expedition/expedition_fixture.gd")
const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")
const VIEW: PackedScene = preload("res://src/ui/station/gate/gate_station_view.tscn")

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateStationView = null


func before_test() -> void:
	_simulation = Fixture.simulation(Fixture.state())
	SimClock.start(_simulation)
	_holder = Control.new()
	_holder.size = Vector2(1920, 1080)
	_holder.theme = UiThemeBuilder.build(1.0)
	add_child(_holder)
	_view = VIEW.instantiate() as GateStationView
	_holder.add_child(_view)
	_view.setup(_simulation)
	ProbeFixture.open(_simulation)
	_view.get_rail().refresh()


func after_test() -> void:
	SimClock.stop()
	_holder.free()


func test_team_then_go_sends() -> void:
	_view.get_rail().press(&"team")
	var sheet: MissionSheet = _view.get_mission_sheet()
	assert_bool(sheet.visible).is_true()
	assert_int(sheet.get_draft().team.size()).is_equal(ExpeditionState.SLOTS.size())
	assert_str(String(sheet.reason())).is_empty()
	sheet.go()
	assert_int(_simulation.state.expedition.mode).is_equal(ExpeditionState.Mode.AWAY)
	assert_bool(sheet.visible).is_false()
	var world: String = String(_simulation.state.expedition.world_id)
	assert_bool(_simulation.state.expedition.last_plans.has(world)).is_true()


func test_defaults_replace_an_injured_member() -> void:
	var state: GameState = _simulation.state
	var draft: ExpeditionPlanDraft = MissionDefaults.draft_for(state, state.gate.connected_world_id)
	var slot: String = ExpeditionState.SLOTS[2]
	var hurt_id: StringName = draft.team[slot]
	var hurt: PersonState = state.staff.find_person(hurt_id)
	InjuryRules.injure(hurt, PersonState.Injury.SERIOUS)
	var again: ExpeditionPlanDraft = MissionDefaults.draft_for(state, state.gate.connected_world_id)
	var now_id: StringName = again.team.get(slot, &"")
	assert_str(String(now_id)).is_not_equal(String(hurt.id))


func test_refusal_without_wormhole() -> void:
	_view.get_rail().press(&"team")
	_simulation.submit(CloseWormholeCommand.new())
	assert_str(String(_view.get_mission_sheet().reason())).is_not_empty()
