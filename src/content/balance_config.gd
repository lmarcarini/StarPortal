class_name BalanceConfig
extends DefBase
## Every tunable number of the game in one definition, always with the id &"balance".
## Fields are added by the cards that need them.
## Bible: technical-architecture.md#data-model

## The id every BalanceConfig has.
const BALANCE_ID: StringName = &"balance"


func _init() -> void:
	id = BALANCE_ID
