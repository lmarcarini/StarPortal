class_name LabCapture
extends RefCounted
## The Lab state of the reference capture (#560): over BaseCapture's rooms, a second Research
## Lab, a NEW project, a project running at the first lab and one queued at the workshop; the
## Lab station shows Science with a project selected. Tool only: never in src/.
## Reference: docs/content/interface-reference.md section 9

const LAB_2: StringName = &"room_ref_lab_2"


## Furnishes the captured game and shows the Lab in [param switcher].
static func show(switcher: ViewSwitcher) -> void:
	var sim: Simulation = SimClock.simulation
	var state: GameState = sim.state
	BaseCapture.furnish(state)
	if state.base.find_room(LAB_2) == null:
		var room: RoomState = RoomState.create(LAB_2, &"room_research_lab", 1, Vector2i(23, 14))
		room.powered_on = true
		state.base.rooms.append(room)
	state.budget.funds_k = maxi(state.budget.funds_k, 20000)
	var science: Array[ResearchDef] = ResearchRules.visible_projects(state, &"science")
	var engineering: Array[ResearchDef] = ResearchRules.visible_projects(state, &"engineering")
	if not science.is_empty():
		sim.submit(StartResearchCommand.create(science[0].id, BaseCapture.LAB))
	for def: ResearchDef in science.slice(1):
		if not state.research.revealed.has(def.id):
			state.research.revealed.append(def.id)
	if engineering.size() > 1:
		sim.submit(StartResearchCommand.create(engineering[0].id, &"room_ref_workshop"))
		sim.submit(QueueResearchCommand.new(engineering[1].id, &"room_ref_workshop"))
	switcher.show_station(&"lab")
	var lab: ResearchView = switcher.get_view(ViewSwitcher.RESEARCH) as ResearchView
	lab.show_discipline(&"science")
	if not science.is_empty():
		lab.select_project(science[0].id)
