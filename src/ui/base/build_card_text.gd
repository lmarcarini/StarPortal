class_name BuildCardText
extends RefCounted
## The BUILD tray cards' words (pure): a short upper-case title and, for a locked room, the
## research it needs ("Unlock: Excavation survey").
## Bible: docs/content/interface-reference.md section 8

## Short titles where the full name does not fit a 106 px card.
const SHORT: Dictionary[StringName, StringName] = {
	&"room_capacitor_bank": &"BASE_CARD_BANK",
	&"room_power_plant": &"BASE_CARD_PLANT",
	&"room_artefact_vault": &"BASE_CARD_VAULT",
}


## The card title of [param def].
static func title(def: RoomDef) -> String:
	var key: StringName = SHORT.get(def.id, def.name_key)
	return TranslationServer.translate(key).to_upper()
