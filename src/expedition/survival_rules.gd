class_name SurvivalRules
extends RefCounted
## Pure rules of a rescue's survival rolls (docs/content/m3-beyond-the-ring.md section 4, "A
## rescue is not a sure thing", owner 2026-11-07). When the team reaches the Ring after a
## Signal, each member rolls to have survived:
## [br][br]
## Survival = 95% (LOW true threat), 85% (MED) or 70% (HIGH); -10% if airless or below -20 °C;
## -15% for a member seriously injured; -5% per full day since the missed check-in; +5% for
## each soldier on the team who survived, rolled first (at most +10%). Between 10% and 99%.
## [br][br]
## Soldiers roll first, in slot order, then the others; each roll counts the soldiers who
## survived before it. A roll is one draw of randi_range(0, 99) below the chance. No side
## effects beyond the generator given.
## Bible: docs/content/m3-beyond-the-ring.md section 4

## Base chance in percent by true threat, indexed by WorldDef.Threat (UNKNOWN counts as LOW).
const BASE_PERCENT: Array[int] = [95, 95, 85, 70]
## Penalties and bonuses in percent.
const HARSH_PENALTY: int = 10
const SERIOUS_PENALTY: int = 15
const DAY_PENALTY: int = 5
const SOLDIER_BONUS: int = 5
const SOLDIER_BONUS_MAX: int = 10
## Bounds of the chance in percent.
const MIN_PERCENT: int = 10
const MAX_PERCENT: int = 99
## Below this temperature (°C) a world counts as harsh, as an airless one does.
const COLD_BELOW_C: int = -20


## True when [param facts] is airless or below -20 °C.
static func is_harsh(facts: WorldFacts) -> bool:
	return facts.atmosphere == WorldDef.Atmosphere.NONE or facts.temperature_c < COLD_BELOW_C


## The chance in percent a member survives: on a world of [param facts], [param serious] when
## seriously injured, [param days] full days since the missed check-in, with
## [param soldiers_alive] soldiers of the team who survived their rolls before.
static func chance(facts: WorldFacts, serious: bool, days: int, soldiers_alive: int) -> int:
	var percent: int = BASE_PERCENT[clampi(facts.threat, 0, BASE_PERCENT.size() - 1)]
	if is_harsh(facts):
		percent -= HARSH_PENALTY
	if serious:
		percent -= SERIOUS_PENALTY
	percent -= DAY_PENALTY * maxi(days, 0)
	percent += mini(SOLDIER_BONUS * soldiers_alive, SOLDIER_BONUS_MAX)
	return clampi(percent, MIN_PERCENT, MAX_PERCENT)


## [param members] in rolling order: soldiers first, then the others, each in the given order.
static func roll_order(members: Array[PersonState]) -> Array[PersonState]:
	var soldiers: Array[PersonState] = []
	var others: Array[PersonState] = []
	for person: PersonState in members:
		if _is_soldier(person):
			soldiers.append(person)
		else:
			others.append(person)
	soldiers.append_array(others)
	return soldiers


## The ids of [param members] who did not survive on a world of [param facts], [param days]
## full days after the missed check-in, rolled with [param rng] in roll_order().
static func roll(
	members: Array[PersonState], facts: WorldFacts, days: int, rng: RandomNumberGenerator
) -> Array[StringName]:
	var deceased: Array[StringName] = []
	var soldiers_alive: int = 0
	for person: PersonState in roll_order(members):
		var serious: bool = person.injury == PersonState.Injury.SERIOUS
		var survived: bool = rng.randi_range(0, 99) < chance(facts, serious, days, soldiers_alive)
		if not survived:
			deceased.append(person.id)
		elif _is_soldier(person):
			soldiers_alive += 1
	return deceased


static func _is_soldier(person: PersonState) -> bool:
	return person.role == StartingStaff.SOLDIER
