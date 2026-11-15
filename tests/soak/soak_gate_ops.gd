class_name SoakGateOps
extends RefCounted
## The soak bot's gate operations (M4.7-06): on an open wormhole it operates the gate or
## stands by at random, so slow reasons come and go through a year of play and saves.
## Bible: docs/content/event-time.md section 3

## Chance per action, on an open wormhole, to flip between operating and standing by.
const FLIP_CHANCE: float = 0.3

## Times the bot operated the gate and stood by, across every bot.
static var operated: int = 0
static var stood_by: int = 0


## Operates or stands by on the open wormhole of [param simulation], with [param rng].
static func work(simulation: Simulation, rng: RandomNumberGenerator) -> void:
	if rng.randf() >= FLIP_CHANCE:
		return
	var gate: GateState = simulation.state.gate
	if gate.operating:
		simulation.submit(StandByCommand.new())
		stood_by += 1
	elif not gate.is_incoming_lock():
		simulation.submit(OperateGateCommand.new())
		operated += 1


## Repairs one damaged room when money allows (M4c), so a sabotaged plant does not leave the
## base short of power for the rest of the year.
static func repair(simulation: Simulation) -> void:
	for room: RoomState in simulation.state.base.rooms:
		if room.damaged and room.repair_ticks_left == 0:
			var command := RepairRoomCommand.create(room.id)
			if command.validate(simulation.state).is_ok:
				simulation.submit(command)
			return


## Output MW of [param state]'s damaged rooms: sabotage may leave the base overdrawn.
static func lost_mw(state: GameState) -> float:
	var lost: float = 0.0
	for room: RoomState in state.base.rooms:
		if room.damaged:
			lost += state.room_defs[room.def_id].power_output_mw
	return lost


## True when [param state] draws and charges more than its supply plus what sabotage cut.
static func overdrawn(state: GameState, sums: PackedFloat64Array) -> bool:
	var used: float = sums[PowerRules.DRAW] + PowerRules.charge_mw_of(state, sums)
	return used > sums[0] + lost_mw(state)
