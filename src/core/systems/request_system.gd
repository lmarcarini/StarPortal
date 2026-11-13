class_name RequestSystem
extends SimSystem
## Checks the open requests every tick while any is open (there are few): objectives fulfil at
## once, deadlines and offer lifetimes are exact to the tick. The design's "every hour" is a
## cost bound this does not need yet.
## Bible: docs/content/m4-core-systems.md section 4


## Returns &"requests".
func get_id() -> StringName:
	return &"requests"


## Checks the open requests.
func tick(state: GameState) -> void:
	RequestRules.check_all(state)
