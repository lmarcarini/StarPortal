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
## Every research project and locked slot, in Registry load order (sorted by path).
var research: Array[ResearchDef] = []
## Every staff role, in Registry load order (sorted by path).
var roles: Array[RoleDef] = []
## Every faction, in Registry load order (sorted by path).
var factions: Array[FactionDef] = []
## Every request, in Registry load order (sorted by path).
var requests: Array[RequestDef] = []
## Every artefact, in Registry load order (sorted by path).
var artefacts: Array[ArtefactDef] = []
## Every IncursionDef and UnitDef (M4c), in Registry load order.
var incursions: Array[IncursionDef] = []
var units: Array[UnitDef] = []
## Every conversation, in Registry load order (sorted by path).
var conversations: Array[ConversationDef] = []
## The staff name list (&"staff_names"), or null.
var staff_names: StaffNameListDef = null


## Returns the definitions loaded by [param registry], the Registry autoload passed in: the
## balance, the home anchor field (&"anchors_home"), every WorldDef, every RoomDef, every
## DocumentDef, every ResearchDef, every RoleDef, every FactionDef, RequestDef and ArtefactDef
## and the staff name list. Missing ones stay
## null or empty; GameSetup.build() reports them.
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
	var research: Array = registry.call(&"get_all_of", ResearchDef)
	for def: Variant in research:
		if def is ResearchDef:
			defs.research.append(def)
	var roles: Array = registry.call(&"get_all_of", RoleDef)
	for def: Variant in roles:
		if def is RoleDef:
			defs.roles.append(def)
	_append_story_defs(registry, defs)
	var names_def: Variant = registry.call(&"get_def", StaffNameListDef.NAMES_ID)
	if names_def is StaffNameListDef:
		defs.staff_names = names_def
	return defs


## Appends every FactionDef, RequestDef, ConversationDef, ArtefactDef, IncursionDef and
## UnitDef of [param registry] to [param defs].
static func _append_story_defs(registry: Node, defs: GameDefs) -> void:
	for def: Variant in registry.call(&"get_all_of", FactionDef):
		if def is FactionDef:
			defs.factions.append(def)
	for def: Variant in registry.call(&"get_all_of", RequestDef):
		if def is RequestDef:
			defs.requests.append(def)
	for def: Variant in registry.call(&"get_all_of", ConversationDef):
		if def is ConversationDef:
			defs.conversations.append(def)
	for def: Variant in registry.call(&"get_all_of", ArtefactDef):
		if def is ArtefactDef:
			defs.artefacts.append(def)
	for def: Variant in registry.call(&"get_all_of", IncursionDef):
		if def is IncursionDef:
			defs.incursions.append(def)
	for def: Variant in registry.call(&"get_all_of", UnitDef):
		if def is UnitDef:
			defs.units.append(def)
