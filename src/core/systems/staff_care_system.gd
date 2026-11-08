class_name StaffCareSystem
extends SimSystem
## People between expeditions (docs/content/m3-beyond-the-ring.md section 4): unlocks
## Expeditions once the first world is Probed (ExpeditionUnlock.is_due()), lends lent-soldier
## replacements when due, and runs a tick of injury recovery (InjuryRules.recover()). A healed
## person goes back to the room they kept. Posts staff_healed(person id) for each.
## Bible: docs/content/m3-beyond-the-ring.md sections 4 and 9

## Id of the system.
const ID: StringName = &"staff_care"
## Event posted when an injured person heals (args: person id); not logged.
const HEALED_EVENT: StringName = &"staff_healed"


## Returns &"staff_care".
func get_id() -> StringName:
	return ID


## Unlocks when due, lends replacements due by now, then recovers the injured by one tick.
func tick(state: GameState) -> void:
	if ExpeditionUnlock.is_due(state):
		ExpeditionUnlock.unlock(state)
	ExpeditionUnlock.lend_due(state)
	for person: PersonState in InjuryRules.recover(state):
		state.events.post(HEALED_EVENT, [person.id])
