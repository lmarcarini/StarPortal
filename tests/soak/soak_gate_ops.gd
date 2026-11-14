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
