class_name FactionSystem
extends SimSystem
## Once a day: drops expired phone calls, then lets each met faction (in id order) with nothing
## pending and past its cooldown queue the best of its own contacts.
## Bible: docs/content/m4-core-systems.md section 2 (Faction-initiated contact)

## Standing a day from an envoy exchange (Cultural exchange, S11).
const ENVOY_FAVOUR: int = 1


## Returns &"factions".
func get_id() -> StringName:
	return &"factions"


## Nothing per tick.
@warning_ignore("unused_parameter")
func tick(state: GameState) -> void:  # gdlint: ignore=unused-argument
	pass


## Daily favour of envoy exchanges, then the contact round.
func on_day(state: GameState) -> void:
	ContactRules.expire_calls(state)
	var ids: Array = state.faction_defs.keys()
	IdOrder.sort(ids)
	for id: StringName in ids:
		_envoy_favour(state, id)
		var faction: FactionDef = state.faction_defs[id]
		if not ContactRules.may_contact(state, faction):
			continue
		var conversation: StringName = ContactRules.pick_contact(state, faction)
		if not conversation.is_empty():
			ContactRules.queue(state, faction, conversation)


## Cultural exchange (S11): an envoy exchange with [param faction] gives one point of standing
## a day.
static func _envoy_favour(state: GameState, faction: StringName) -> void:
	var short: String = String(faction).trim_prefix("faction_")
	if ResearchPerks.has(state, StringName(ResearchPerks.ENVOYS_PREFIX + short)):
		FactionRules.change(state, faction, ENVOY_FAVOUR, &"STORY_CAUSE")
