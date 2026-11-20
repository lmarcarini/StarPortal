class_name ResearchMaterials
extends RefCounted
## What a project spends besides money (docs/content/research-and-progression.md sections 4
## and 10): alien pieces (artefacts of a kind, consumed on start) and specimens of alien life.
## Pure checks; StartResearchCommand spends them.
## Bible: docs/content/research-and-progression.md sections 4 and 10


## &"needs_pieces" or &"needs_specimens" when [param state] lacks what [param def] spends,
## else &"".
static func missing(state: GameState, def: ResearchDef) -> StringName:
	if def.piece_count > 0 and pieces_held(state, def.piece_artefact) < def.piece_count:
		return &"needs_pieces"
	if def.specimen_count > 0 and specimens_held(state) < def.specimen_count:
		return &"needs_specimens"
	return &""


## How many artefacts of [param artefact_id] [param state] holds, in any place.
static func pieces_held(state: GameState, artefact_id: StringName) -> int:
	var count: int = 0
	for item: ArtefactRecord in state.artefacts.items:
		if item.artefact == artefact_id:
			count += 1
	return count


## Specimens [param state] holds (none until specimens exist, M7-03).
static func specimens_held(_state: GameState) -> int:
	return 0
