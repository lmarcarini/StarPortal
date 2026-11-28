class_name WireActions
extends RefCounted
## The action keys of each wire card (interface-rethink.md section 6), each carrying the
## command the old screens sent: the best next research projects and TREE; REVIEW and PASS;
## ACCEPT and DECLINE; HOUSE and STUDY; SWITCH ON and ASSIGN; RESCUE; ANSWER and IGNORE; GO TO
## the place that fixes it; REPORT. Pure.
## Bible: docs/content/interface-rethink.md section 6


## The keys of alert [param entry] in [param state].
static func for_alert(state: GameState, entry: AlertEntry) -> Array[WireAction]:
	match entry.kind:
		&"lab_idle", &"research_done":
			return research(state)
		&"candidate_waiting":
			return candidate()
		&"artefact_at_gate":
			return artefact(state, int(String(entry.target)))
		&"site_finished":
			return room(state, entry.target)
		&"team_overdue", &"rescue":
			return [WireAction.step(&"rescue", &"rescue", &"rescue")]
	return [WireAction.go(&"go_to", &"go_to", entry.view_id, entry.sub_tab)]


## Up to WireRules.PROJECTS projects that may start now, cheapest first, then TREE.
static func research(state: GameState) -> Array[WireAction]:
	var ready: Array[ResearchDef] = []
	for def: ResearchDef in state.research_defs.values():
		if ResearchRules.can_start(state, def.id).is_ok:
			ready.append(def)
	ready.sort_custom(func(a: ResearchDef, b: ResearchDef) -> bool: return a.cost_k < b.cost_k)
	var keys: Array[WireAction] = []
	for def: ResearchDef in ready.slice(0, WireRules.PROJECTS):
		var hint: String = TranslationServer.translate(def.name_key)
		keys.append(WireAction.submit(def.id, &"study", hint, StartResearchCommand.create(def.id)))
	keys.append(WireAction.go(&"tree", &"tree", ViewSwitcher.RESEARCH))
	return keys


## REVIEW opens the Candidates sub-tab of Personnel, where every candidate can be compared;
## PASS dismisses the card.
static func candidate() -> Array[WireAction]:
	return [
		WireAction.go(&"review", &"candidate", ViewSwitcher.PERSONNEL, &"candidates"),
		WireAction.step(&"pass", &"pass", &"dismiss"),
	]


## ACCEPT and DECLINE request [param uid].
static func request(uid: int) -> Array[WireAction]:
	return [
		WireAction.submit(&"accept", &"accept", "WIRE_KEY_ACCEPT", AcceptRequestCommand.new(uid)),
		WireAction.submit(
			&"decline", &"decline", "WIRE_KEY_DECLINE", DeclineRequestCommand.new(uid)
		),
	]


## HOUSE artefact [param uid] in the first room that fits it; STUDY opens the artefacts.
static func artefact(state: GameState, uid: int) -> Array[WireAction]:
	var keys: Array[WireAction] = []
	for room: RoomState in state.base.rooms:
		var room_uid: int = ArtefactRules.room_uid_of(room.id)
		if ArtefactRules.house_error(state, uid, room_uid).is_empty():
			var house: HouseArtefactCommand = HouseArtefactCommand.new(uid, room_uid)
			keys.append(WireAction.submit(&"house", &"crate", "WIRE_KEY_HOUSE", house))
			break
	keys.append(WireAction.go(&"study", &"study", ViewSwitcher.ARCHIVE, &"artefacts"))
	return keys


## SWITCH ON room [param room_id]; ASSIGN the first free person of its slot's role.
static func room(state: GameState, room_id: StringName) -> Array[WireAction]:
	var keys: Array[WireAction] = []
	var target: RoomState = state.base.find_room(room_id)
	if target == null:
		return [WireAction.go(&"go_to", &"go_to", ViewSwitcher.BASE)]
	var on: SwitchRoomCommand = SwitchRoomCommand.create(room_id, true)
	keys.append(WireAction.submit(&"switch_on", &"switch_on", "WIRE_KEY_SWITCH_ON", on))
	var role: StringName = StaffRules.slot_role(state, target)
	var free: Array[PersonState] = StaffRules.unassigned_of_role(state, role)
	if not free.is_empty():
		var assign: AssignStaffCommand = AssignStaffCommand.create(free[0].id, room_id)
		keys.append(WireAction.submit(&"assign", &"assign", "WIRE_KEY_ASSIGN", assign))
	return keys


## ANSWER and IGNORE the waiting incoming wormhole.
static func incoming() -> Array[WireAction]:
	return [
		WireAction.submit(&"answer", &"answer", "WIRE_KEY_ANSWER", AnswerIncomingCommand.new()),
		WireAction.submit(&"ignore", &"ignore", "WIRE_KEY_IGNORE", IgnoreIncomingCommand.new()),
	]


## ANSWER the oldest phone call; IGNORE dismisses the card (the call stays on the clock lamp).
static func phone() -> Array[WireAction]:
	return [
		WireAction.submit(&"answer", &"answer", "WIRE_KEY_ANSWER", AnswerCallCommand.new()),
		WireAction.step(&"ignore", &"ignore", &"dismiss"),
	]
