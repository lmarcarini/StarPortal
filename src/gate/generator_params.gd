class_name GeneratorParams
extends RefCounted
## Tunables of WorldGenerator. Defaults are the launch galaxy: about 300 procedural worlds in the
## home domain, a box centred on (0, 0, 0).
## Bible: overview.md#locked-decisions,
## gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## gate-and-address-spec.md#dialing-outcomes-and-energy

## Number of procedural worlds, excluding authored ones.
var world_count: int = 300
## Procedural worlds lie within +/- these light years of (0, 0, 0) on each axis.
var half_extents_ly: Vector3i = Vector3i(15000, 15000, 1500)
## Least distance between any two worlds, and between a procedural world and an anchor.
var min_spacing_ly: int = 50
## Procedural worlds guaranteed OPEN, unguarded and dialable from home within reach_energy_mwh.
var min_reach_worlds: int = 12
## Lock energy budget of the early-reach guarantee, in MWh (the starting capacitor bank).
var reach_energy_mwh: float = 400.0
## Share of procedural worlds whose Ring is BURIED.
var buried_fraction: float = 0.08
## Share of procedural worlds whose Ring is SHIELDED.
var shielded_fraction: float = 0.04
## Share of procedural worlds whose far side is guarded.
var guarded_fraction: float = 0.10
