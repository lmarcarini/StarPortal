class_name HeldAtLeastCondition
extends ConditionDef
## True when the player holds at least [member amount] of [member what]: &"artefacts",
## &"hazardous_artefacts" (with a hazard), &"specimens" or &"addresses" (Address Book entries).
## Bible: docs/content/research-and-progression.md section 10 ("Shows when")

## What is counted.
const WHATS: Array[StringName] = [&"artefacts", &"hazardous_artefacts", &"specimens", &"addresses"]

## One of [constant WHATS].
@export var what: StringName = &"artefacts"
## The least count.
@export var amount: int = 1


## Returns &"COND_HELD_AT_LEAST".
func reason_key() -> StringName:
	return &"COND_HELD_AT_LEAST"
