class_name WireCardData
extends RefCounted
## One card on the wire: what happened (kind, icon, a two-word title, the detail sentence for
## the hover card), how bad it is, when, whether the player may dismiss it (event cards) or it
## goes with its cause (condition cards), and its action keys. Built by WireRules; never saved.
## Bible: docs/content/interface-rethink.md sections 3 and 6

## Kind (an old alert kind, or request_offered, incoming_call, phone_call, charge_low,
## team_returned).
var kind: StringName = &""
## HardwareIcons id.
var icon_id: StringName = &""
## Two-word title key: WIRE_<KIND>.
var title_key: StringName = &""
## The full sentence, for the hover card.
var detail: String = ""
## AlertEntry severity.
var severity: StringName = AlertEntry.INFO
## Tick of the cause.
var tick: int = 0
## Event cards may be dismissed; condition cards go when their cause does.
var dismissible: bool = false
## The alert the card came from (for the shell's select step), or null.
var entry: AlertEntry = null
## Action keys, left to right.
var actions: Array[WireAction] = []


## A key naming this card's cause (dismissal).
func key() -> String:
	return entry.key() if entry != null else "%s/%d" % [kind, tick]
