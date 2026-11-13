class_name FactionSystem
extends SimSystem
## Once a day: drops expired phone calls, then lets each met faction (in id order) with nothing
## pending and past its cooldown queue the best of its own contacts.
## Bible: docs/content/m4-core-systems.md section 2 (Faction-initiated contact)


## Returns &"factions".
func get_id() -> StringName:
	return &"factions"


## Nothing per tick.
@warning_ignore("unused_parameter")
func tick(state: GameState) -> void:  # gdlint: ignore=unused-argument
	pass


## The daily contact round.
func on_day(state: GameState) -> void:
	ContactRules.expire_calls(state)
	var ids: Array = state.faction_defs.keys()
	ids.sort()
	for id: StringName in ids:
		var faction: FactionDef = state.faction_defs[id]
		if not ContactRules.may_contact(state, faction):
			continue
		var conversation: StringName = ContactRules.pick_contact(state, faction)
		if not conversation.is_empty():
			ContactRules.queue(state, faction, conversation)
