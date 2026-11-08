## Tests for the Expeditions unlock (ExpeditionUnlock, StaffCareSystem): it comes with the first
## Probed world (or a direct call), sets its flag once, lets the Infirmary be built (never
## research), lends two soldiers on base at once with no bed and a normal salary, and replaces a
## lost lent soldier 7 days later with a Log line; soldiers and medics join the candidate draw.
## Bible: docs/content/m3-beyond-the-ring.md sections 4 and 9
extends GdUnitTestSuite

const DAY: int = TimeMath.TICKS_PER_DAY

var _defs: GameDefs
var _game: GameState
var _system: StaffCareSystem


func before_test() -> void:
	_defs = GameDefs.from_registry(Registry)
	_game = ConstructionFixture.state()
	_game.balance = _defs.balance
	_system = StaffCareSystem.new()


func _lent() -> Array[PersonState]:
	var found: Array[PersonState] = []
	for person: PersonState in _game.staff.people:
		if person.lent:
			found.append(person)
	return found


func _event_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for event: SimEvent in _game.events.drain():
		names.append(event.name)
	return names


func test_locked_before_the_unlock_and_not_research() -> void:
	assert_bool(ExpeditionUnlock.is_unlocked(_game)).is_false()
	var result: CommandResult = UnlockRules.can_build_room(_game, ExpeditionUnlock.INFIRMARY_DEF)
	assert_str(String(result.error_code)).is_equal("needs_staff")
	var project: StringName = UnlockRules.project_for(
		UnlockRules.EFFECT_UNLOCK_ROOM, ExpeditionUnlock.INFIRMARY_DEF
	)
	assert_str(String(project)).is_empty()
	for def: ResearchDef in _defs.research:
		assert_str(String(def.id)).not_contains("infirmary")


func test_first_probed_world_unlocks() -> void:
	_system.tick(_game)
	assert_bool(ExpeditionUnlock.is_unlocked(_game)).is_false()
	_game.worlds.statuses[&"world_x"] = WorldsState.WorldStatus.LOCKED
	_system.tick(_game)
	assert_bool(ExpeditionUnlock.is_unlocked(_game)).is_false()
	_game.worlds.statuses[&"world_x"] = WorldsState.WorldStatus.PROBED
	_system.tick(_game)
	assert_bool(ExpeditionUnlock.is_unlocked(_game)).is_true()
	assert_bool(_game.flags[ExpeditionUnlock.FLAG]).is_true()
	assert_bool(UnlockRules.can_build_room(_game, ExpeditionUnlock.INFIRMARY_DEF).is_ok).is_true()


func test_unlock_lends_two_soldiers_at_once_without_beds() -> void:
	_game.clock.tick = 5000
	var beds_used: int = StaffRules.beds_used(_game)
	var headcount: int = StaffRules.headcount(_game)
	var salaries: int = StaffRules.salaries_k(_game)
	assert_bool(ExpeditionUnlock.unlock(_game)).is_true()
	assert_bool(ExpeditionUnlock.unlock(_game)).is_false()
	var lent: Array[PersonState] = _lent()
	(
		assert_array(lent.map(func(p: PersonState) -> String: return p.name))
		. is_equal(["Maj. Ruth Adair", "Sgt Owen Hale"])
	)
	for person: PersonState in lent:
		assert_str(String(person.role)).is_equal("role_soldier")
		assert_int(person.skill).is_equal(3)
		assert_bool(person.is_on_base(_game.clock.tick)).is_true()
	assert_int(StaffRules.beds_used(_game)).is_equal(beds_used)
	assert_int(StaffRules.headcount(_game)).is_equal(headcount + 2)
	var pay: int = StaffRules.salary_for_skill(_defs.balance, 3)
	assert_int(StaffRules.salaries_k(_game)).is_equal(salaries + 2 * pay)
	assert_array(_event_names()).is_equal(
		[ExpeditionUnlock.LENT_EVENT, ExpeditionUnlock.LENT_EVENT]
	)


func test_lost_lent_soldier_is_replaced_7_days_later_with_a_log_line() -> void:
	ExpeditionUnlock.unlock(_game)
	_game.events.drain()
	var hale: PersonState = _lent()[1]
	_game.clock.tick = 2 * DAY + 30
	assert_bool(ExpeditionUnlock.lose_person(_game, hale.id)).is_true()
	assert_array(_lent()).has_size(1)
	_game.clock.tick = 9 * DAY + 29
	_system.tick(_game)
	assert_array(_lent()).has_size(1)
	_game.clock.tick += 1
	_system.tick(_game)
	var lent: Array[PersonState] = _lent()
	assert_array(lent).has_size(2)
	assert_str(lent[1].name).is_equal("Capt. Lena Okoye")
	assert_array(_game.staff.lent_due).is_empty()
	var person_id: StringName = lent[1].id
	var entries: Array[LogEntry] = LogRules.entries_for(
		ExpeditionUnlock.LENT_EVENT, [person_id], _game, _game.clock.tick
	)
	assert_array(entries).has_size(1)
	assert_str(str(entries[0].args.get("reason"))).is_equal("lent")
	assert_str(ArchiveLogRow.staff_line(entries[0].args)).contains("Capt. Lena Okoye")


func test_losing_a_hired_person_lends_nobody() -> void:
	var first: PersonState = _game.staff.people[0]
	assert_bool(ExpeditionUnlock.lose_person(_game, first.id)).is_true()
	assert_array(_game.staff.lent_due).is_empty()
	assert_bool(ExpeditionUnlock.lose_person(_game, &"person_999")).is_false()


func test_lent_soldiers_and_replacements_survive_a_save() -> void:
	ExpeditionUnlock.unlock(_game)
	ExpeditionUnlock.lose_person(_game, _lent()[0].id)
	var data: Dictionary = JSON.parse_string(JSON.stringify(_game.to_dict()))
	assert_array(GameState.validate_dict(data, _defs)).is_empty()
	var loaded: GameState = GameState.from_dict(data)
	assert_bool(ExpeditionUnlock.is_unlocked(loaded)).is_true()
	assert_array(loaded.staff.lent_due).is_equal(_game.staff.lent_due)
	assert_bool(loaded.staff.people[-1].lent).is_true()
	data["staff"]["lent_due"] = [-1]
	assert_str("; ".join(GameState.validate_dict(data))).contains("lent_due")


func test_soldiers_and_medics_only_after_the_unlock() -> void:
	var recruitment := RecruitmentSystem.new(_defs.balance, _defs.roles, _defs.staff_names)
	var before: Dictionary[StringName, int] = _draw_roles(recruitment, 1, 300)
	assert_int(before.get(StartingStaff.SOLDIER, 0) + before.get(StartingStaff.MEDIC, 0)).is_zero()
	ExpeditionUnlock.unlock(_game)
	var after: Dictionary[StringName, int] = _draw_roles(recruitment, 301, 1500)
	var total: int = 0
	for role: StringName in after:
		total += after[role]
	var field: int = after.get(StartingStaff.SOLDIER, 0) + after.get(StartingStaff.MEDIC, 0)
	assert_int(after.get(StartingStaff.SOLDIER, 0)).is_greater(0)
	assert_int(after.get(StartingStaff.MEDIC, 0)).is_greater(0)
	assert_float(float(field) / total).is_between(0.12, 0.3)


## Runs the settlements of days [param first] to [param last]; counts each arrival's role.
func _draw_roles(system: RecruitmentSystem, first: int, last: int) -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	for day: int in range(first, last + 1):
		_game.clock.tick = day * DAY
		var newest: int = _game.recruitment.next_candidate_number
		system.on_day(_game)
		if _game.recruitment.next_candidate_number == newest:
			continue
		var role: StringName = _game.recruitment.candidates[-1].role
		counts[role] = counts.get(role, 0) + 1
	return counts


func test_new_roles_have_pipelines_and_arrival_days() -> void:
	assert_str(String(RecruitmentRules.pipeline_key(StartingStaff.SOLDIER))).is_equal(
		"STAFF_PIPELINE_MILITARY"
	)
	assert_str(String(RecruitmentRules.pipeline_key(StartingStaff.MEDIC))).is_equal(
		"STAFF_PIPELINE_ACADEMIA"
	)
	assert_int(RecruitmentRules.arrival_ticks(_defs.balance, StartingStaff.SOLDIER)).is_equal(
		3 * DAY
	)
	assert_int(RecruitmentRules.arrival_ticks(_defs.balance, StartingStaff.MEDIC)).is_equal(5 * DAY)
