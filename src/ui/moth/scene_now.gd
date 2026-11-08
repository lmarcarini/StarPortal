class_name SceneNow
extends RefCounted
## The world scene as it stands now: the WorldScene of a world's true facts, less what play has
## changed on it (a target a team recovered is gone). Every picture (the horizon photo, the MOTH
## frames) reads this instead of the starting facts, so a later photo shows what has changed.
## Pure static; reads the state, never changes it.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (the pole camera's place)


## Returns the scene of [param world_id] in [param state] now; null for an unknown world.
static func of(state: GameState, world_id: StringName) -> WorldScene:
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, world_id)
	if facts == null:
		return null
	var scene: WorldScene = facts.scene()
	var kept: Array[WorldTarget] = []
	for target: WorldTarget in scene.targets:
		var target_state: TargetStates.State = state.worlds.targets.state_of(world_id, target.id)
		if target_state != TargetStates.State.RECOVERED:
			kept.append(target)
	scene.targets = kept
	return scene
