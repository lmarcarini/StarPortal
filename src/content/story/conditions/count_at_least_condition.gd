class_name CountAtLeastCondition
extends ConditionDef
## True when the progress counter [member counter] (a whole-number flag kept by
## ProgressCounters: locks made, canisters sent, MOTH runs, expeditions sent, incursion
## warnings, alien conversations) is at least [member amount].
## Bible: docs/content/research-and-progression.md section 10 ("Shows when")

## Counter flag name (ProgressCounters.COUNTERS).
@export var counter: StringName = &""
## The least count.
@export var amount: int = 1


## Returns &"COND_COUNT_AT_LEAST".
func reason_key() -> StringName:
	return &"COND_COUNT_AT_LEAST"
