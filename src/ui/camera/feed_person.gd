class_name FeedPerson
extends RefCounted
## A person as a camera feed shows them: a role (by shape, as on the plan's tokens) and a
## position across the room's floor, each axis 0..1.
## Bible: docs/content/interface-pass.md section 5 (Camera inset)

## Role id: scientist, engineer, analyst, soldier, medic...
var role: StringName = &""
## Position on the floor, x across and y in depth, each 0..1.
var position: Vector2 = Vector2(0.5, 0.5)


## A new person of [param role_id] at [param at].
static func create(role_id: StringName, at: Vector2) -> FeedPerson:
	var person := FeedPerson.new()
	person.role = role_id
	person.position = at
	return person
