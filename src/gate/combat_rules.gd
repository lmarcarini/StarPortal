class_name CombatRules
extends RefCounted
## Fighting between squads and intruders, pure (M4c-08). Sides in reach (the same room, or
## within combat_reach_cells walking cells in corridors) each deal their summed attack times a
## seeded roll, at the same time, spread over the other side front first. The side that holds
## the room takes defender_reduction less. A soldier at 0 health is down with a serious
## injury; nobody dies. Intruders with no open path breach the sealed door in their way.
## Bible: docs/content/m4c-incursions.md sections 2 and 4

## Days a downed soldier is out (a serious injury).
const DOWN_INJURY: PersonState.Injury = PersonState.Injury.SERIOUS


## True when cells [param a] and [param b] are in reach: the same room, or both in corridor,
## lift or stairs cells within [param reach] walking cells.
static func in_reach(
	a: Vector3i, b: Vector3i, base: BaseState, defs: Dictionary, reach: int = 3
) -> bool:
	var cells: Dictionary[Vector3i, RoomState] = BasePaths.occupancy(base, defs)
	var room_a: RoomState = cells.get(a)
	var room_b: RoomState = cells.get(b)
	if room_a == null or room_b == null:
		return false
	if room_a == room_b and not BasePaths.HALLS.has(room_a.def_id):
		return true
	if not (BasePaths.HALLS.has(room_a.def_id) and BasePaths.HALLS.has(room_b.def_id)):
		return false
	var distance: int = BasePaths.walking_distance(base, a, b, defs)
	return distance >= 0 and distance <= reach


## The damage one side deals: [param attack] times a roll from [param rng] in
## [roll_min, roll_max], less [param reduction] when the other side defends; rounded.
static func damage(
	attack: float, rng: RandomNumberGenerator, roll: Vector2, reduction: float
) -> int:
	var rolled: float = attack * rng.randf_range(roll.x, roll.y)
	return roundi(rolled * (1.0 - reduction))


## Takes [param amount] from [param healths] front first; returns the new healths.
static func spread(healths: Array[int], amount: int) -> Array[int]:
	var left: int = amount
	var out: Array[int] = []
	for health: int in healths:
		var taken: int = mini(health, left)
		left -= taken
		out.append(health - taken)
	return out


## A soldier's attack per tick: 1 + skill ÷ 2.
static func soldier_attack(person: PersonState) -> float:
	return 1.0 + float(person.skill) / 2.0
