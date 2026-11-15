class_name SpeakerDef
extends DefBase
## Someone who speaks in conversations: their name and title, the faction they speak for
## (empty for the player's side) and the PortraitDef that draws them. Lines name a speaker by
## id, so a real portrait later is a content change (docs/content/dialogue-screen.md section 3).
## Read only at runtime.
## Bible: docs/content/dialogue-screen.md sections 3 and 7

## Translation key of the name.
@export var name_key: StringName = &""
## Translation key of the title ("Speaker for the Kindred, Mooring"); may be empty.
@export var title_key: StringName = &""
## Id of the FactionDef spoken for; &"" for the player's side.
@export var faction: StringName = &""
## Id of the PortraitDef.
@export var portrait: StringName = &""


## The portrait and the faction (when set).
func get_references() -> Array[StringName]:
	var found: Array[StringName] = [portrait]
	if not faction.is_empty():
		found.append(faction)
	return found


## A name, a portrait that is a PortraitDef and a faction that is a FactionDef.
func get_content_errors(defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = []
	if name_key.is_empty():
		errors.append("needs a name key")
	var drawn: DefBase = defs.get(portrait)
	if drawn != null and not drawn is PortraitDef:
		errors.append("portrait '%s' is not a portrait" % portrait)
	var owner: DefBase = defs.get(faction)
	if owner != null and not owner is FactionDef:
		errors.append("faction '%s' is not a faction" % faction)
	return errors
