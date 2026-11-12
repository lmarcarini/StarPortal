class_name ConditionDef
extends Resource
## Abstract base of a story condition: a read-only test of the game state ("is this true?"),
## shared by conversations, requests, faction contacts, research and artefacts. Content only:
## evaluating one is StoryRules' job (simulation layer). Subclasses add typed exports.
## Bible: docs/content/m4-core-systems.md section 1


## Returns the text key the UI shows when this condition is not met, e.g.
## &"COND_STANDING_AT_LEAST". Subclasses override it.
func reason_key() -> StringName:
	return &""


## Returns the ids of the definitions this condition points at (faction, project, artefact,
## world, request); empty by default. Flags are not definitions and are never returned.
func get_references() -> Array[StringName]:
	return []
