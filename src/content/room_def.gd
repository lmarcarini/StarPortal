class_name RoomDef
extends DefBase
## Definition of a room type the base can hold: its footprint in cells, whether it may be turned
## a quarter turn, its build cost and time, its power draw or output, its monthly upkeep and
## its text keys. Read only at runtime.
## Bible: game-design.md#base-building-and-power, technical-architecture.md#data-model,
## docs/content/m2-base.md (sections 1 and 3)

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
## True for a room that is always on and has no switch (the Gate Room, the Control Room).
@export var always_on: bool = false
## Power output added while built and switched on, in MW (a Power Plant); at least 0.
@export var power_output_mw: float = 0.0
## Highest charge rate a room may be given, in MW (a Capacitor Bank); 0 when it does not charge.
@export var max_charge_rate_mw: float = 0.0
## Upkeep charged at each month-end, in thousands of dollars; at least 0.
@export var upkeep_k: int = 0
## Translation key of the room's name.
@export var name_key: StringName = &""
## Translation key of the room's one-line description.
@export var description_key: StringName = &""
