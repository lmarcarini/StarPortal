class_name DrainPowerEffect
extends EffectDef
## Takes energy from the capacitors (never below 0), e.g. an artefact hazard.
## Bible: docs/content/m4-core-systems.md sections 5 and 8

## MWh taken from the stored energy.
@export var mwh: int = 0
