class_name XenoPerks
extends RefCounted
## Xenotech (X01-X06) and Xenobiology (B01-B07) research read by the rules it changes
## (docs/content/research-and-progression.md section 10): the Lattice recharging the banks,
## earlier incursion warnings, the Loom's translations, specimen analysis, field treatment,
## faster healing and toxin resistance. Alien physiology (B07) only sets its flag for the
## recruitment work. Pure, except recharge(), called from ArtefactSystem.on_day().
## Bible: docs/content/research-and-progression.md section 10

const LATTICE_HARMONICS: StringName = &"lattice_harmonics"
const LOOM_TRANSLATOR: StringName = &"loom_translator"
const EFFIGY_WARDS: StringName = &"effigy_wards"
const SPECIMEN_ANALYSIS: StringName = &"specimen_analysis"
const FIELD_MEDICINE: StringName = &"field_medicine"
const REGENERATION: StringName = &"regenerative_compounds"
const TOXIN_RESISTANCE: StringName = &"toxin_resistance"
const ALIEN_PHYSIOLOGY: StringName = &"alien_physiology"
## The Resonant Lattice's daily recharge, in MWh.
const LATTICE_MWH: float = 50.0
const LATTICE: StringName = &"resonant_lattice"


## With Lattice harmonics and the Lattice held, adds LATTICE_MWH to the banks (up to their
## capacity). Returns the MWh added.
static func recharge(state: GameState) -> float:
	if (
		not ResearchPerks.has(state, LATTICE_HARMONICS)
		or StoryRules.count_held(state, LATTICE) <= 0
	):
		return 0.0
	var before: float = state.power.stored_mwh
	state.power.stored_mwh = minf(PowerRules.capacity_mwh(state), before + LATTICE_MWH)
	return state.power.stored_mwh - before


## The warning of an incursion of [param warning_ticks], twice as long with Effigy wards.
static func warning_ticks(state: GameState, warning_ticks: int) -> int:
	return warning_ticks * 2 if ResearchPerks.has(state, EFFIGY_WARDS) else warning_ticks


## The injury a field setback gives: with Field medicine a serious one is treated to light.
static func field_injury(state: GameState, injury: FieldEventDef.Setback) -> FieldEventDef.Setback:
	if injury == FieldEventDef.Setback.SERIOUS and ResearchPerks.has(state, FIELD_MEDICINE):
		return FieldEventDef.Setback.LIGHT
	return injury


## A recovery speed with Regenerative compounds (serious injuries heal twice as fast).
static func recovery_speed(state: GameState, person: PersonState, speed: int) -> int:
	if person.injury == PersonState.Injury.SERIOUS and ResearchPerks.has(state, REGENERATION):
		return speed * 2
	return speed
