class_name RoomDef
extends DefBase
## Definition of a room type the base can hold: its footprint in cells, whether it may be turned
## a quarter turn, its build cost and time, its power draw and
## its monthly upkeep. Read only at runtime.
## Bible: game-design.md#base-building-and-power, technical-architecture.md#data-model

## Footprint in cells (width × height) before rotation; each side at least 1.
@export var size_cells: Vector2i = Vector2i.ONE
## True when the room may be placed turned a quarter turn (width and height swapped).
@export var rotatable: bool = true
## Build cost in thousands of dollars; at least 0.
@export var build_cost_k: int = 0
## Ticks of building before the room works; at least 0.
@export var build_ticks: int = 0
## Power drawn while built and switched on, in MW; at least 0.
@export var power_draw_mw: float = 0.0
## True for a room the player can neither build nor demolish, e.g. the Gate Room.
@export var fixed: bool = false
## Upkeep charged at each month-end, in thousands of dollars; at least 0.
@export var upkeep_k: int = 0
