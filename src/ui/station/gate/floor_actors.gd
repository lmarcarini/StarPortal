class_name FloorActors
extends Control
## The Gate floor's live layer: plays a short cue for each event from [ActorCues]. Teams walk
## from the left door up the ramp into the horizon and come back down it; a MOTH flies in or
## out; a canister rolls; the pole camera arm pushes; a crate lands at the ramp foot;
## intruders come out. Two technicians stand at the console banks when the hall is quiet.
## Presentation only: a cue that arrives while the station is not shown is skipped.
## Reduced motion (ambient movement off) turns cues into short fades.
## Bible: docs/content/interface-rethink.md section 2 (Show it happening)

const _STAGGER: float = 0.7

var _station: StationScene = null
var _actors: Array[Actor] = []
var _idle: Array[Actor] = []
var _signals: Array[Signal] = []
var _calls: Array[Callable] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for spot: StringName in [&"console_left", &"console_right"]:
		var tech: Actor = Actor.new()
		tech.route = Actor.Route.STAND
		tech.figure = FigureSprite.Kind.SCIENTIST
		tech.spot = spot
		_idle.append(tech)


func _enter_tree() -> void:
	_signals = [
		EventBus.team_sent,
		EventBus.team_returned,
		EventBus.moth_launched,
		EventBus.moth_recalled,
		EventBus.canister_launched,
		EventBus.artefact_arrived,
		EventBus.incursion_breached,
	]
	_calls = [
		_on_team_sent,
		_on_team_returned,
		_on_simple.bind(&"moth_launched").unbind(1),
		_on_simple.bind(&"moth_recalled").unbind(1),
		_on_simple.bind(&"canister_launched").unbind(1),
		_on_simple.bind(&"artefact_arrived").unbind(1),
		_on_simple.bind(&"incursion_breached"),
	]
	for i: int in _signals.size():
		_signals[i].connect(_calls[i])


func _exit_tree() -> void:
	for i: int in _signals.size():
		_signals[i].disconnect(_calls[i])
	_signals.clear()
	_calls.clear()


## Plays over [param station].
func bind(station: StationScene) -> void:
	_station = station


## True while a cue is playing (CLOSE then asks to be held).
func is_busy() -> bool:
	return not _actors.is_empty()


## The actors of the cues playing.
func get_actors() -> Array[Actor]:
	return _actors


## Starts [param cue] with [param count] figures (teams, intruders). Skipped while the
## station is not shown.
func play(cue: ActorCues.Cue, count: int = 1) -> void:
	if cue == ActorCues.Cue.NONE or not is_visible_in_tree():
		return
	var reduced: bool = not Settings.get_bool(&"display", &"ambient_movement")
	var figures: int = ActorCues.figures(cue, count)
	for i: int in maxi(1, figures):
		var actor: Actor = _actor_for(cue)
		actor.duration = ActorCues.duration(cue, reduced)
		actor.fade_only = reduced
		actor.delay = 0.0 if reduced else _STAGGER * i
		_actors.append(actor)


## Ends every cue at once.
func snap_all() -> void:
	for actor: Actor in _actors:
		actor.snap_to_end()
	_actors.clear()
	queue_redraw()


## Moves the cues on by [param delta] seconds.
func advance(delta: float) -> void:
	for actor: Actor in _actors:
		actor.advance(delta)
	for actor: Actor in _idle:
		actor.advance(delta)
	_actors = _actors.filter(func(a: Actor) -> bool: return not a.is_done())
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


func _actor_for(cue: ActorCues.Cue) -> Actor:
	var actor: Actor = Actor.new()
	match cue:
		ActorCues.Cue.TEAM_OUT:
			actor.route = Actor.Route.OUT
		ActorCues.Cue.TEAM_IN:
			actor.route = Actor.Route.IN
		ActorCues.Cue.INTRUDERS:
			actor.route = Actor.Route.RAMP_DOWN
			actor.figure = FigureSprite.Kind.INTRUDER
		_:
			actor.figure = -1
			actor.route = (
				Actor.Route.RAMP_DOWN
				if cue in [ActorCues.Cue.MOTH_IN, ActorCues.Cue.CRATE]
				else Actor.Route.RAMP_UP
			)
			actor.prop = _prop_for(cue)
	return actor


static func _prop_for(cue: ActorCues.Cue) -> Props.Kind:
	match cue:
		ActorCues.Cue.CANISTER_OUT:
			return Props.Kind.CANISTER
		ActorCues.Cue.CAMERA_PUSH:
			return Props.Kind.CAMERA_ARM
		ActorCues.Cue.CRATE:
			return Props.Kind.CRATE
	return Props.Kind.MOTH


func _on_team_sent(_world: StringName, _objective: int, team: Array, _blind: bool) -> void:
	play(ActorCues.Cue.TEAM_OUT, team.size())


func _on_team_returned(_world: StringName, _objective: int, _success: bool, team: Array) -> void:
	play(ActorCues.Cue.TEAM_IN, team.size())


func _on_simple(event_name: StringName) -> void:
	play(ActorCues.cue_of(event_name))


func _draw() -> void:
	if _station == null:
		return
	if _actors.is_empty() and Settings.get_bool(&"display", &"ambient_movement"):
		for tech: Actor in _idle:
			_draw_actor(tech)
	for actor: Actor in _actors:
		if actor.has_started():
			_draw_actor(actor)


## Screen path of [param route] from the station's anchors.
func path_of(route: Actor.Route, spot: StringName = &"") -> PackedVector2Array:
	var ramp: PackedVector2Array = _station.shape(&"ramp")
	var door: Vector2 = _station.anchor(&"door_left")
	if ramp.size() < 2:
		return PackedVector2Array([door])
	match route:
		Actor.Route.OUT:
			return PackedVector2Array([door, ramp[1], ramp[0]])
		Actor.Route.IN:
			return PackedVector2Array([ramp[0], ramp[1], door])
		Actor.Route.RAMP_UP:
			return PackedVector2Array([ramp[1], ramp[0]])
		Actor.Route.RAMP_DOWN:
			return PackedVector2Array([ramp[0], ramp[1]])
	var bank: Rect2 = _station.rect_of(spot)
	return PackedVector2Array([Vector2(bank.get_center().x, bank.end.y + 6.0)])


## Where [param actor] is now on screen.
func position_of(actor: Actor) -> Vector2:
	var path: PackedVector2Array = path_of(actor.route, actor.spot)
	if actor.fade_only:
		return path[path.size() - 1]
	return ActorCues.along(path, actor.progress())


func _draw_actor(actor: Actor) -> void:
	var at: Vector2 = position_of(actor)
	var ramp: PackedVector2Array = _station.shape(&"ramp")
	var u: float = 1.0
	if ramp.size() >= 2 and ramp[1].y > ramp[0].y:
		u = clampf((at.y - ramp[0].y) / (ramp[1].y - ramp[0].y), 0.0, 1.0)
	var pose: ActorPose = ActorPose.new()
	pose.at = at
	pose.scale = _station.depth_at(&"ramp", u)
	pose.alpha = _alpha_of(actor, u)
	pose.phase = actor.elapsed
	if actor.figure < 0:
		Props.draw(self, actor.prop as Props.Kind, pose)
		return
	pose.rim = clampf(1.0 - u * 3.0, 0.0, 1.0) if _station_open() else 0.0
	FigureSprite.draw(self, actor.figure as FigureSprite.Kind, pose)


func _alpha_of(actor: Actor, u: float) -> float:
	var p: float = actor.progress()
	if actor.fade_only:
		return 1.0 - p
	if actor.route == Actor.Route.OUT and u < 0.08:
		return clampf(u / 0.08, 0.0, 1.0)
	if actor.route == Actor.Route.IN and p < 0.05:
		return p / 0.05
	return 1.0


func _station_open() -> bool:
	var ring: RingLayer = _station.find_child("RingLayer", true, false) as RingLayer
	return ring != null and ring.open_amount > 0.0
