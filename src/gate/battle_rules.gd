class_name BattleRules
extends RefCounted
## One tick of fighting (M4c-08): every squad with someone standing exchanges damage with
## every intruder group in reach (CombatRules), at the same time. A squad holding its ground
## defends; otherwise intruders already working a room defend. Downed soldiers take a serious
## injury and leave the squad; downed intruders stay down. Groups that fought this tick do
## not walk.
## Bible: docs/content/m4c-incursions.md section 2


## Fights every squad of [param state] against every group in reach, then the sentry guns
## (SentryRules), with [param rng];
## returns the groups that fought.
static func fight(state: GameState, rng: RandomNumberGenerator) -> Array[IntruderGroup]:
	var engaged: Array[IntruderGroup] = []
	var balance: BalanceConfig = state.balance
	for squad: SquadState in state.security.squads:
		for group: IntruderGroup in state.incursion.groups:
			if SquadRules.members(state, squad.post_room).is_empty() or group.standing().is_empty():
				continue
			var reach: int = balance.combat_reach_cells
			if not CombatRules.in_reach(squad.pos, group.pos(), state.base, state.room_defs, reach):
				continue
			_exchange(state, squad, group, rng)
			if not engaged.has(group):
				engaged.append(group)
	for group: IntruderGroup in SentryRules.fight(state, rng):
		if not engaged.has(group):
			engaged.append(group)
	return engaged


static func _exchange(
	state: GameState, squad: SquadState, group: IntruderGroup, rng: RandomNumberGenerator
) -> void:
	var balance: BalanceConfig = state.balance
	var roll := Vector2(balance.combat_roll_min, balance.combat_roll_max)
	var squad_holds: bool = squad.order == SquadState.Order.HOLD
	var group_holds: bool = not squad_holds and group.work_ticks > 0
	var cut: float = balance.defender_reduction
	var to_squad: int = CombatRules.damage(
		_group_attack(state, group), rng, roll, cut if squad_holds else 0.0
	)
	var to_group: int = CombatRules.damage(
		_squad_attack(state, squad), rng, roll, cut if group_holds else 0.0
	)
	_hit_squad(state, squad, to_squad)
	_hit_group(group, to_group)
	state.events.post(&"squad_changed", [squad.post_room])


static func _squad_attack(state: GameState, squad: SquadState) -> float:
	var total: float = 0.0
	for person_id: StringName in SquadRules.members(state, squad.post_room):
		total += CombatRules.soldier_attack(state.staff.find_person(person_id))
	return total


static func _group_attack(state: GameState, group: IntruderGroup) -> float:
	var total: float = 0.0
	for unit: UnitState in group.standing():
		var def: UnitDef = state.unit_defs.get(unit.unit)
		total += def.attack if def != null else 0.0
	return total


static func _hit_squad(state: GameState, squad: SquadState, amount: int) -> void:
	var ids: Array[StringName] = SquadRules.members(state, squad.post_room)
	var healths: Array[int] = []
	for person_id: StringName in ids:
		healths.append(state.security.health.get(person_id, state.balance.soldier_health))
	var after: Array[int] = CombatRules.spread(healths, amount)
	for index: int in ids.size():
		var person_id: StringName = ids[index]
		if after[index] > 0:
			state.security.health[person_id] = after[index]
			continue
		state.security.health.erase(person_id)
		InjuryRules.injure(state.staff.find_person(person_id), CombatRules.DOWN_INJURY)
		var injured: Array = state.incursion.report.get("injured", [])
		injured.append(String(person_id))
		state.incursion.report["injured"] = injured


static func _hit_group(group: IntruderGroup, amount: int) -> void:
	var up: Array[UnitState] = group.standing()
	var healths: Array[int] = []
	for unit: UnitState in up:
		healths.append(unit.health)
	var after: Array[int] = CombatRules.spread(healths, amount)
	for index: int in up.size():
		up[index].health = after[index]
