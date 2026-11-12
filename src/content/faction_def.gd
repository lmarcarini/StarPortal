class_name FactionDef
extends DefBase
## Definition of a faction: an Earth power or an alien people the player can deal with. Its
## standing runs −100 to +100; the Committee's standing is Committee Confidence instead.
## Read only at runtime.
## Bible: docs/content/m4-core-systems.md section 2

## Valid kinds.
const KINDS: Array[StringName] = [&"earth", &"alien"]
## Lowest and highest standing.
const STANDING_MIN: int = -100
const STANDING_MAX: int = 100

## &"earth" (starts met, phones) or &"alien" (unknown until first spoken to, dials in).
@export var kind: StringName = &"alien"
## Translation key of the name.
@export var name_key: StringName = &""
## Accent colour of the faction in the UI.
@export var accent: Color = Color.WHITE
## Standing at a new game, −100..100; ignored for the Committee.
@export var start_standing: int = 0
## True only for the Committee, whose standing is Committee Confidence.
@export var uses_confidence: bool = false
## Ids of the conversations this faction may start itself.
@export var contacts: Array[StringName] = []


## Problems of this faction alone: an unknown kind, no name key, or a starting standing out of
## range. Conversation ids in [member contacts] are checked by the content validator.
func get_content_errors(_defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = []
	if not KINDS.has(kind):
		errors.append("has kind '%s', not earth or alien" % kind)
	if name_key.is_empty():
		errors.append("needs a name key")
	if start_standing < STANDING_MIN or start_standing > STANDING_MAX:
		errors.append("start standing %d is outside -100..100" % start_standing)
	return errors
