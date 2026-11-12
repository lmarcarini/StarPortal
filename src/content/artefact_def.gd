class_name ArtefactDef
extends DefBase
## Definition of an alien artefact: its storage class, the modifiers it gives while housed in a
## powered room, and an optional hazard rolled each day while it is not in Containment.
## Read only at runtime.
## Bible: docs/content/m4-core-systems.md section 5

## Valid storage classes.
const STORAGE_CLASSES: Array[StringName] = [&"vault", &"containment"]

## Translation key of the name.
@export var name_key: StringName = &""
## Translation key of the description.
@export var description_key: StringName = &""
## &"vault" (a Vault or Containment holds it) or &"containment" (only Containment).
@export var storage: StringName = &"vault"
## Modifiers that apply while housed in a built, switched-on room.
@export var modifiers: Array[ModifierEffect] = []
## Daily chance, 0..100, that the hazard strikes while not in Containment.
@export var hazard_chance_pct: int = 0
## Effects applied when the hazard strikes; present exactly when the chance is above 0.
@export var hazard: Array[EffectDef] = []


## Problems of this artefact alone: no name or description key, an unknown storage class, a
## hazard chance outside 0..100, hazard effects without a chance (or the reverse), or a
## ModifierEffect among the hazard effects (modifiers belong in [member modifiers]).
func get_content_errors(_defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = []
	if name_key.is_empty() or description_key.is_empty():
		errors.append("needs a name key and a description key")
	if not STORAGE_CLASSES.has(storage):
		errors.append("has storage '%s', not vault or containment" % storage)
	if hazard_chance_pct < 0 or hazard_chance_pct > 100:
		errors.append("hazard chance %d is outside 0..100" % hazard_chance_pct)
	if (hazard_chance_pct > 0) == hazard.is_empty():
		errors.append("hazard effects must be present exactly when the hazard chance is above 0")
	for effect: EffectDef in hazard:
		if effect is ModifierEffect:
			errors.append("a ModifierEffect belongs in modifiers, not hazard")
	return errors
