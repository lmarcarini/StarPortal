class_name RoomDef
extends DefBase
## Definition of a room type the base can hold: its footprint in cells, whether it may be turned
## a quarter turn, its build cost and time, its power draw or output, its upkeep per 30 days and
## its text keys. Read only at runtime.
## Bible: game-design.md#base-building-and-power, technical-architecture.md#data-model,
## docs/content/m2-base.md (sections 1 and 3), docs/content/m26-staff-and-money.md section 3

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
## Upkeep per 30 days (charged daily), in thousands of dollars; at least 0.
@export var upkeep_k: int = 0
## Translation key of the room's name.
@export var name_key: StringName = &""
## Translation key of the room's one-line description.
@export var description_key: StringName = &""
## Role id (a RoleDef) of the people this room's staff slots take; empty when it has none.
@export var staff_role: StringName = &""
## Staff slots: people of [member staff_role] the room holds; 0 for none (plants, owner
## 2026-11-02).
@export var staff_slots: int = 0
## Beds the room adds while built and not coming down (Control Room 6, Quarters 4).
@export var beds: int = 0


## The staff role, when the room has one.
func get_references() -> Array[StringName]:
	if staff_role.is_empty():
		return []
	return [staff_role]


## Errors: slots without a role or a role without slots, and negative counts.
func get_content_errors(_defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = []
	if staff_slots < 0 or beds < 0:
		errors.append("has negative staff slots or beds")
	if (staff_slots > 0) != (not staff_role.is_empty()):
		errors.append("needs both a staff role and staff slots, or neither")
	return errors
