class_name IncursionSystem
extends SimSystem
## Runs incursions (M4c-06): at 00:00 each hostile faction with an IncursionDef rolls its
## daily chance (seeded, faction id order, never within the cooldown); each tick of the
## warning counts down, and at zero the intruders breach into the Gate Room; then they go
## about their objective and leave (IntruderRules). While one is
## under way no outgoing wormhole stays open. The clock's incursion slow reason follows the
## phase (SlowRules).
## Bible: docs/content/m4c-incursions.md section 1

## The randomness stream.
const STREAM: StringName = &"incursion"


## Returns the system id, &"incursion".
func get_id() -> StringName:
	return &"incursion"


## Counts the warning down and breaches at zero; keeps the Ring shut to outgoing traffic.
func tick(state: GameState) -> void:
	var incursion: IncursionState = state.incursion
	if not incursion.is_active():
		return
	IncursionRules.close_outgoing(state)
	if incursion.phase != IncursionState.Phase.WARNING:
		var engaged: Array[IntruderGroup] = BattleRules.fight(state, state.random.stream(STREAM))
		IntruderRules.tick(state, engaged)
		return
	incursion.countdown -= 1
	if incursion.countdown <= 0:
		IncursionRules.breach(state)


## The daily roll of every hostile faction.
func on_day(state: GameState) -> void:
	if state.incursion.is_active() or state.incursion_defs.is_empty():
		return
	var day: int = TimeMath.day_index(state.clock.tick)
	var rng: RandomNumberGenerator = state.random.stream(STREAM)
	var factions: Array[StringName] = state.faction_defs.keys()
	IdOrder.sort(factions)
	for faction: StringName in factions:
		var defs: Array[StringName] = IncursionRules.defs_of(state, faction)
		if defs.is_empty() or not IncursionRules.off_cooldown(state, faction, day):
			continue
		var chance: float = IncursionRules.daily_chance(FactionRules.standing(state, faction))
		if chance <= 0.0 or rng.randf() >= chance:
			continue
		IncursionRules.start(state, defs[rng.randi_range(0, defs.size() - 1)])
		return
