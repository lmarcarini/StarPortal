class_name SoakArtefacts
extends RefCounted
## The soak bot's artefact habits (M4b): brings an artefact waiting at the gate into holding,
## then houses a held artefact in the first built room it fits. One command per call at most.
## Bible: docs/content/m4-core-systems.md section 5


## The next artefact command, or null when there is nothing to do.
static func next(state: GameState) -> Command:
	for uid: int in ArtefactRules.at_gate(state):
		if ArtefactRules.retrieve_error(state, uid).is_empty():
			return RetrieveArtefactCommand.new(uid)
	for uid: int in ArtefactRules.holding(state):
		for room: RoomState in state.base.rooms:
			var room_uid: int = ArtefactRules.room_uid_of(room.id)
			if ArtefactRules.house_error(state, uid, room_uid).is_empty():
				return HouseArtefactCommand.new(uid, room_uid)
	return null
