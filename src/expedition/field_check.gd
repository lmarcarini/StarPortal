class_name FieldCheck
extends RefCounted
## Pure rules of a field event's check (docs/content/m3-beyond-the-ring.md section 4, Risk
## model): the team's best person in the event's role rolls
## Success = 50% + 15% x (skill - difficulty), between 10% and 95%, where difficulty is the
## event's own, +1 on MED worlds, +2 on HIGH, +1 if airless or below -20 °C (true facts).
## A seriously injured person counts as skill 1; with no one of the role on the team, the
## check is rolled at skill 0.
## Bible: docs/content/m3-beyond-the-ring.md section 4

## Chance at skill equal to difficulty, and per point of difference, in percent.
const BASE_PERCENT: int = 50
const STEP_PERCENT: int = 15
## Bounds of the chance, in percent.
const MIN_PERCENT: int = 10
const MAX_PERCENT: int = 95
## Difficulty added by the world's true threat, indexed by WorldDef.Threat (UNKNOWN, LOW, MED,
## HIGH).
const THREAT_MODIFIER: Array[int] = [0, 0, 1, 2]
## Difficulty added on an airless or very cold world (SurvivalRules.is_harsh).
const HARSH_MODIFIER: int = 1


## The success chance in percent at [param skill] against [param difficulty].
static func chance(skill: int, difficulty: int) -> int:
	return clampi(BASE_PERCENT + STEP_PERCENT * (skill - difficulty), MIN_PERCENT, MAX_PERCENT)


## [param def]'s difficulty on a world of [param facts], with the section 4 modifiers.
static func difficulty(def: FieldEventDef, facts: WorldFacts) -> int:
	var result: int = def.difficulty
	result += THREAT_MODIFIER[clampi(facts.threat, 0, THREAT_MODIFIER.size() - 1)]
	if SurvivalRules.is_harsh(facts):
		result += HARSH_MODIFIER
	return result


## The member of [param members] of [param role] with the best check skill (the first on a
## tie), or null when none has that role.
static func roller(members: Array[PersonState], role: StringName) -> PersonState:
	var best: PersonState = null
	for person: PersonState in members:
		if person.role != role:
			continue
		if best == null or InjuryRules.check_skill(person) > InjuryRules.check_skill(best):
			best = person
	return best


## The check skill [param person] rolls with: 0 when null.
static func skill_of(person: PersonState) -> int:
	return 0 if person == null else InjuryRules.check_skill(person)


## True when a roll of [param roll] (0 to 99) succeeds at [param percent].
static func succeeds(roll: int, percent: int) -> bool:
	return roll < percent
