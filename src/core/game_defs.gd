class_name GameDefs
extends RefCounted
## The content the simulation needs, gathered once by the shell from the Registry and passed
## to GameSetup, so simulation code never reads the Registry itself. Tests build one by hand
## from fixtures. Read only: the definitions are shared, loaded resources.
## Bible: technical-architecture.md#data-model,
## technical-architecture.md#architecture-overview

## Id of the home domain's anchor field.
const HOME_ANCHORS_ID: StringName = &"anchors_home"

## Every tunable number.
var balance: BalanceConfig = null
## The home domain's 36 anchors.
var anchors: AnchorFieldDef = null
## Every authored world, CAIRN included, in Registry load order (sorted by path).
var authored_worlds: Array[WorldDef] = []
## Every room type, in Registry load order (sorted by path).
var rooms: Array[RoomDef] = []
## Every document, in Registry load order (sorted by path).
var documents: Array[DocumentDef] = []


## Returns the definitions loaded by [param registry], the Registry autoload passed in: the
## balance, the home anchor field (&"anchors_home"), every WorldDef, every RoomDef and every
## DocumentDef. Missing ones stay null or empty; GameSetup.build() reports them.
static func from_registry(registry: Node) -> GameDefs:
	var defs := GameDefs.new()
	var balance_def: Variant = registry.call(&"balance")
	if balance_def is BalanceConfig:
		defs.balance = balance_def
	var anchor_def: Variant = registry.call(&"get_def", HOME_ANCHORS_ID)
	if anchor_def is AnchorFieldDef:
		defs.anchors = anchor_def
	var worlds: Array = registry.call(&"get_all_of", WorldDef)
	for def: Variant in worlds:
		if def is WorldDef:
			defs.authored_worlds.append(def)
	var rooms: Array = registry.call(&"get_all_of", RoomDef)
	for def: Variant in rooms:
		if def is RoomDef:
			defs.rooms.append(def)
	var documents: Array = registry.call(&"get_all_of", DocumentDef)
	for def: Variant in documents:
		if def is DocumentDef:
			defs.documents.append(def)
	return defs
