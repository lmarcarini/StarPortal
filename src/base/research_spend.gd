class_name ResearchSpend
extends RefCounted
## Spends a starting project's materials (docs/content/research-and-progression.md section 4):
## its pieces (artefacts of its kind, unhoused first) and its specimens. Called only from
## StartResearchCommand.begin(), after ResearchRules.can_start() passed.
## Bible: docs/content/research-and-progression.md sections 4 and 10


## Removes [param def]'s pieces from [param state]'s artefacts (those in holding first) and
## its specimens, the oldest first.
static func spend(state: GameState, def: ResearchDef) -> void:
	var left: int = def.piece_count
	for pass_housed: bool in [false, true]:
		for item: ArtefactRecord in state.artefacts.items.duplicate():
			if left <= 0:
				break
			var housed: bool = item.room_uid != ArtefactRecord.IN_HOLDING
			if item.artefact == def.piece_artefact and housed == pass_housed:
				state.artefacts.items.erase(item)
				left -= 1
	SpecimenRules.spend(state, def.specimen_count)
