class_name EffectDef
extends Resource
## Abstract base of a story effect: one change to the game state ("make this happen"). Content
## only: applying one is StoryRules' job (simulation layer). Subclasses add typed exports.
## Bible: docs/content/m4-core-systems.md section 1

## A hidden effect still happens, but previews show "?" instead of it.
@export var hidden: bool = false


## Returns the ids of the definitions this effect points at (faction, project, artefact,
## world, document, request); empty by default. Flags are not definitions.
func get_references() -> Array[StringName]:
	return []
