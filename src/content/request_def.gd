class_name RequestDef
extends DefBase
## Definition of a request a faction can offer: an objective (conditions that must all hold),
## an optional deadline, how long the offer stands, and the reward, penalty and on-decline
## effects. Offered only by OfferRequestEffect. Read only at runtime.
## Bible: docs/content/m4-core-systems.md section 4

## Id of the FactionDef that offers it.
@export var faction: StringName = &""
## Translation key of the title.
@export var title_key: StringName = &""
## Translation key of the text.
@export var text_key: StringName = &""
## Conditions that must all hold to fulfil it; at least one.
@export var objective: Array[ConditionDef] = []
## In-game days from acceptance to the deadline; 0 = no deadline.
@export var deadline_days: int = 0
## True when reaching the deadline with the objective still holding fulfils the request
## (keep-the-Ring-closed requests); needs a deadline.
@export var deadline_succeeds: bool = false
## In-game days the offer stands before it lapses; at least 1.
@export var offer_days: int = 1
## Effects applied when accepted (e.g. StampFlag for a keep-the-Ring-closed request).
@export var on_accept: Array[EffectDef] = []
## Effects applied when fulfilled.
@export var reward: Array[EffectDef] = []
## Effects applied when failed.
@export var penalty: Array[EffectDef] = []
## Effects applied when declined or lapsed.
@export var on_decline: Array[EffectDef] = []


## The offering faction.
func get_references() -> Array[StringName]:
	return [faction]


## Problems against the other loaded [param defs]: a faction that is not a FactionDef, no
## title or text key, an empty objective, a negative deadline, deadline_succeeds without a
## deadline, or an offer that stands less than a day.
func get_content_errors(defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = []
	if defs.has(faction) and not defs[faction] is FactionDef:
		errors.append("faction '%s' is not a faction" % faction)
	if title_key.is_empty() or text_key.is_empty():
		errors.append("needs a title key and a text key")
	if objective.is_empty():
		errors.append("needs at least one objective condition")
	if deadline_days < 0:
		errors.append("deadline days %d is negative" % deadline_days)
	if deadline_succeeds and deadline_days <= 0:
		errors.append("deadline_succeeds needs a deadline")
	if offer_days < 1:
		errors.append("offer days must be at least 1")
	return errors
