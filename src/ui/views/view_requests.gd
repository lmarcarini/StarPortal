class_name ViewRequests
extends RefCounted
## What the views ask the switcher for: the Gate's first Capacitor Bank (open the Base with its
## ghost), a plan from the World Report (the Gate's mission sheet), a team report from the Log
## and Personnel's show on plan. Split out of ViewSwitcher.
## Bible: docs/content/interface-pass.md section 4


## Opens the Base with the Capacitor Bank's ghost on the nearest valid spot to
## the Gate Room.
static func capacitor_bank(switcher: ViewSwitcher) -> void:
	if switcher.get_view(ViewSwitcher.BASE) == null:
		return
	var base: BaseView = switcher.get_view(ViewSwitcher.BASE) as BaseView
	if base == null:
		return
	switcher.show_view(ViewSwitcher.BASE)
	base.place_capacitor_bank()


## Opens the Gate station's mission sheet on [param world_id].
static func plan(world_id: StringName, switcher: ViewSwitcher) -> void:
	if switcher.get_view(ViewSwitcher.GATE_ROOM) == null:
		return
	var gate: GateStationView = switcher.get_view(ViewSwitcher.GATE_ROOM) as GateStationView
	if gate == null:
		return
	switcher.show_view(ViewSwitcher.GATE_ROOM)
	gate.plan_world(world_id)


## Opens the Gate with the team report of the Log's return [param entry].
static func team_report(entry: LogEntry, switcher: ViewSwitcher) -> void:
	if switcher.get_view(ViewSwitcher.GATE_ROOM) == null:
		return
	var gate: GateStationView = switcher.get_view(ViewSwitcher.GATE_ROOM) as GateStationView
	if gate != null:
		gate.show_log_report(entry)


## Opens the Base on [param person_id]'s level with their token selected.
static func show_on_plan(person_id: StringName, switcher: ViewSwitcher) -> void:
	if switcher.get_view(ViewSwitcher.BASE) == null:
		return
	var base: BaseView = switcher.get_view(ViewSwitcher.BASE) as BaseView
	if base == null:
		return
	switcher.show_view(ViewSwitcher.BASE)
	base.get_plan().staff_layer.focus_person(person_id)
