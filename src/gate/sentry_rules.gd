class_name SentryRules
extends RefCounted
## Sentry guns (M4c-21), pure: a sentry fires on the intruder groups in its own room while the
## room is on and undamaged (sentry_attack × the seeded roll), and takes their fire like a
## unit; at 0 health it is destroyed (the installation goes, installation_changed). Door
## plating doubles a door's breach time.
## Bible: docs/content/m4c-incursions.md section 6

## The installations.
const SENTRY: StringName = &"installation_sentry_gun"
const PLATING: StringName = &"installation_door_plating"


## One tick of every active sentry of [param state] with [param rng]; returns the groups
## that fought.
static func fight(state: GameState, rng: RandomNumberGenerator) -> Array[IntruderGroup]:
	var engaged: Array[IntruderGroup] = []
	var cells: Dictionary[Vector3i, RoomState] = BasePaths.occupancy(state.base, state.room_defs)
	for room: RoomState in state.base.rooms:
		if not InstallationRules.active(state, room.id, SENTRY):
			continue
		for group: IntruderGroup in state.incursion.groups:
			if cells.get(group.pos()) != room or group.standing().is_empty():
				continue
			_exchange(state, room, group, rng)
			engaged.append(group)
	return engaged


## True when [param door] carries built plating.
static func plated(door: DoorState) -> bool:
	var item: InstallationState = InstallationRules.find(door.installations, PLATING)
	return item != null and item.is_built()


static func _exchange(
	state: GameState, room: RoomState, group: IntruderGroup, rng: RandomNumberGenerator
) -> void:
	var balance: BalanceConfig = state.balance
	var roll := Vector2(balance.combat_roll_min, balance.combat_roll_max)
	var sentry: InstallationState = InstallationRules.find(room.installations, SENTRY)
	var attack: float = 0.0
	for unit: UnitState in group.standing():
		var def: UnitDef = state.unit_defs.get(unit.unit)
		attack += def.attack if def != null else 0.0
	var to_sentry: int = CombatRules.damage(attack, rng, roll, balance.defender_reduction)
	var to_group: int = CombatRules.damage(balance.sentry_attack, rng, roll, 0.0)
	var up: Array[UnitState] = group.standing()
	var healths: Array[int] = []
	for unit: UnitState in up:
		healths.append(unit.health)
	var after: Array[int] = CombatRules.spread(healths, to_group)
	for index: int in up.size():
		up[index].health = after[index]
	sentry.health = maxi(0, sentry.health - to_sentry)
	if sentry.health == 0:
		room.installations.erase(sentry)
		InstallationState.revision += 1
		state.events.post(&"installation_changed", [room.id])
