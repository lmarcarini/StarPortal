class_name SecuritySystem
extends SimSystem
## Keeps the squads in step with their Security Posts and walks the ones under orders, one
## tick at a time (M4c-05). Posts squad_changed when a squad forms, breaks up or moves.
## Bible: docs/content/m4c-incursions.md sections 2 and 3


## Returns the system id, &"security".
func get_id() -> StringName:
	return &"security"


## Forms and breaks up squads, then walks every squad that has an order.
func tick(state: GameState) -> void:
	if state.security.squads.is_empty() and SquadRules.posts(state).is_empty():
		return
	SquadRules.sync(state)
	for squad: SquadState in state.security.squads:
		OfficePerks.auto_fall_back(state, squad)
		if SquadRules.walk(state, squad):
			state.events.post(&"squad_changed", [squad.post_room])
