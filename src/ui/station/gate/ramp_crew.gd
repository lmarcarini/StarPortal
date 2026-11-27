class_name RampCrew
extends RefCounted
## Pure rules for [TeamOnRamp]: who stands at the Gate hall's posts, and distances along a
## walk path. No nodes.
## Bible: docs/content/interface-reference.md section 7


## Post marker to the id who stands there in [param state]: staff on base in roster order,
## leaving out [param busy] and the expedition team;
## [param posts] maps a post to [role, pose, facing]. Empty during an incursion.
static func post_crew(
	state: GameState, busy: Array[StringName], posts: Dictionary[StringName, Array]
) -> Dictionary[StringName, StringName]:
	var crew: Dictionary[StringName, StringName] = {}
	if state == null or state.incursion.phase != IncursionState.Phase.NONE:
		return crew
	var used: Array[StringName] = busy.duplicate()
	used.append_array(state.expedition.member_ids())
	for spot: StringName in posts:
		for person: PersonState in state.staff.people:
			if person.role != posts[spot][0] or person.id in used:
				continue
			if person.is_on_base(state.clock.tick) and not person.appearance.is_empty():
				crew[spot] = person.id
				used.append(person.id)
				break
	return crew


## Length of [param path] in metres.
static func length(path: PackedVector3Array) -> float:
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


## The point [param distance] metres along [param path] (its end past the end).
static func along(path: PackedVector3Array, distance: float) -> Vector3:
	var left: float = maxf(0.0, distance)
	for i: int in range(1, path.size()):
		var seg: float = path[i - 1].distance_to(path[i])
		if left <= seg and seg > 0.0:
			return path[i - 1].lerp(path[i], left / seg)
		left -= seg
	return path[path.size() - 1]
