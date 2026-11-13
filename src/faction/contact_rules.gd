class_name ContactRules
extends RefCounted
## Pure rules of faction-initiated contact: whether a faction may contact now, which of its
## contacts it picks, queueing the pending contact, finding the next one on a channel and
## dropping expired phone calls. Deterministic: priority and conditions decide.
## Bible: docs/content/m4-core-systems.md section 2 (Faction-initiated contact), section 3

## Committee Confidence lost per missed call, and the cause key.
const MISSED_CALL_CHANGE: int = -1
const MISSED_CALL_CAUSE: StringName = &"CAUSE_CALL_MISSED"


## The channel [param faction] contacts on: &"phone" for Earth, &"incoming" for aliens.
static func channel_of(faction: FactionDef) -> StringName:
	return &"phone" if faction.kind == &"earth" else &"incoming"


## True when [param faction] has a pending contact.
static func has_pending(state: GameState, faction: StringName) -> bool:
	for contact: PendingContact in state.factions.pending:
		if contact.faction == faction:
			return true
	return false


## True when [param faction] may start a contact now: met, nothing pending, and at least
## faction_contact_days since its last one.
static func may_contact(state: GameState, faction: FactionDef) -> bool:
	if not state.factions.met.has(faction.id) or has_pending(state, faction.id):
		return false
	if not state.factions.last_contact_tick.has(faction.id):
		return true
	var since: int = state.clock.tick - state.factions.last_contact_tick[faction.id]
	return since >= state.balance.faction_contact_days * TimeMath.TICKS_PER_DAY


## The contact [param faction] picks: of its contacts on its channel, the highest priority
## (first listed on a tie) whose conditions hold and that is not used up. &"" when none.
static func pick_contact(state: GameState, faction: FactionDef) -> StringName:
	var channel: StringName = channel_of(faction)
	var best: ConversationDef = null
	for id: StringName in faction.contacts:
		var def: ConversationDef = state.conversation_defs.get(id)
		if def == null or def.faction != faction.id or not def.channels.has(channel):
			continue
		if def.once and state.conversations.count.get(id, 0) > 0:
			continue
		if not StoryRules.check_all(state, def.conditions):
			continue
		if best == null or def.priority > best.priority:
			best = def
	return &"" if best == null else best.id


## Queues [param conversation] as [param faction]'s pending contact (a phone call expires
## after phone_expiry_days), stamps its last contact and posts contact_pending.
static func queue(state: GameState, faction: FactionDef, conversation: StringName) -> void:
	var contact := PendingContact.new()
	contact.faction = faction.id
	contact.conversation = conversation
	contact.channel = channel_of(faction)
	contact.since_tick = state.clock.tick
	if contact.channel == &"phone":
		contact.expires_tick = (
			state.clock.tick + state.balance.phone_expiry_days * TimeMath.TICKS_PER_DAY
		)
	state.factions.pending.append(contact)
	state.factions.last_contact_tick[faction.id] = state.clock.tick
	state.events.post(&"contact_pending", [faction.id])


## Index of the oldest pending contact on [param channel], or −1.
static func next_pending(state: GameState, channel: StringName) -> int:
	for index: int in state.factions.pending.size():
		if state.factions.pending[index].channel == channel:
			return index
	return -1


## Drops every phone contact past its expiry: Committee Confidence −1 each and call_missed.
static func expire_calls(state: GameState) -> void:
	var index: int = 0
	while index < state.factions.pending.size():
		var contact: PendingContact = state.factions.pending[index]
		if contact.expires_tick >= 0 and state.clock.tick >= contact.expires_tick:
			state.factions.pending.remove_at(index)
			FactionRules.change(
				state, FactionRules.COMMITTEE, MISSED_CALL_CHANGE, MISSED_CALL_CAUSE
			)
			state.events.post(&"call_missed", [contact.faction])
		else:
			index += 1
