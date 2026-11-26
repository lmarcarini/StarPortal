class_name ContractWork
extends RefCounted
## Contract work (E22, docs/content/research-and-progression.md section 9): a Workshop with the
## Contract work installation earns DAILY_K a day while it speeds no build (no site, dig or
## installation is being built). Pure.
## Bible: docs/content/research-and-progression.md section 9

## The installation.
const DEF_ID: StringName = &"installation_contract_work"
## Daily earnings of each running Workshop with it, in $k.
const DAILY_K: int = 20


## What contract work earns today in [param state], in $k: DAILY_K per running Workshop with
## the installation, nothing while anything is being built or dug.
static func daily_k(state: GameState) -> int:
	if _building(state):
		return 0
	var total: int = 0
	for room: RoomState in state.base.rooms:
		if (
			room.def_id == BuildSpeed.WORKSHOP_DEF
			and InstallationRules.active(state, room.id, DEF_ID)
		):
			total += DAILY_K
	return total


static func _building(state: GameState) -> bool:
	if state.base.digging_level() != 0 or InstallationRules.any_building(state):
		return true
	for room: RoomState in state.base.rooms:
		if room.build_ticks_left > 0:
			return true
	return false
