class_name PendingContact
extends RefCounted
## A contact a faction wants to make: the conversation it chose, the channel, since when it
## waits and when it expires (−1 = never).
## Saved shape: {"faction", "conversation", "channel", "since_tick", "expires_tick"}.
## Bible: docs/content/m4-core-systems.md sections 2, 3 and 9

## Channels a contact can come by.
const CHANNELS: Array[String] = ["incoming", "phone"]
## Saved keys, in to_dict() order.
const KEYS: Array[String] = ["faction", "conversation", "channel", "since_tick", "expires_tick"]

## Faction id.
var faction: StringName = &""
## Conversation id.
var conversation: StringName = &""
## &"incoming" or &"phone".
var channel: StringName = &"incoming"
## Tick it became pending.
var since_tick: int = 0
## Tick it expires, or −1.
var expires_tick: int = -1


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {
		"faction": String(faction),
		"conversation": String(conversation),
		"channel": String(channel),
		"since_tick": since_tick,
		"expires_tick": expires_tick,
	}


## Builds one from valid saved [param data].
static func from_dict(data: Dictionary) -> PendingContact:
	var contact := PendingContact.new()
	contact.faction = SaveFields.read_id(data.get("faction"))
	contact.conversation = SaveFields.read_id(data.get("conversation"))
	contact.channel = SaveFields.read_id(data.get("channel"))
	contact.since_tick = SaveFields.read_int(data.get("since_tick"))
	contact.expires_tick = SaveFields.read_int(data.get("expires_tick"), -1)
	return contact


## Errors of saved [param data]: keys, ids, a known channel, ticks.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	for key: String in ["faction", "conversation"]:
		if not SaveFields.is_id(data[key]):
			errors.append("'%s' is not a non-empty string" % key)
	if not (data["channel"] is String and CHANNELS.has(str(data["channel"]))):
		errors.append("'channel' is not incoming or phone")
	if not SaveFields.is_tick(data["since_tick"]):
		errors.append("'since_tick' is not a tick")
	if not SaveFields.is_tick_or_unset(data["expires_tick"]):
		errors.append("'expires_tick' is not a tick or -1")
	return errors
