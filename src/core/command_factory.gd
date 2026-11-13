class_name CommandFactory
extends RefCounted
## Rebuilds commands from their to_dict() data, e.g. from a command log, by type id.
## Every registered script must declare [code]static func from_dict(data: Dictionary)
## -> Result[/code] whose value is the rebuilt Command.
##
## Registry: the built-in types are registered lazily by [method register_defaults], which
## every public method calls on first use. [method reset] drops all registrations,
## including test-only ones; the defaults come back on next use.
## Bible: technical-architecture.md#simulation-clock-and-commands

static var _types: Dictionary[StringName, Script] = {}
static var _defaults_registered: bool = false


## Rebuilds a command from [param data]. The Result's value is the Command. Fails with
## &"malformed_command" when "type" is missing or the type's own data is invalid, and with
## &"unknown_command" when no script is registered for the type.
static func from_dict(data: Dictionary) -> Result:
	_ensure_defaults()
	var type_data: Variant = data.get("type")
	if not (type_data is String or type_data is StringName):
		return Result.fail(&"malformed_command", "command data needs a string type")
	var type := StringName(str(type_data))
	if not _types.has(type):
		return Result.fail(&"unknown_command", String(type))
	var result: Result = _types[type].call(&"from_dict", data)
	assert(result != null, "%s.from_dict() must return a Result" % type)
	if result.is_ok:
		assert(result.value is Command, "%s.from_dict() must return a Command" % type)
	return result


## Registers [param script] as the builder for commands of [param type], replacing any
## earlier registration of that type.
static func register_type(type: StringName, script: Script) -> void:
	assert(not type.is_empty(), "CommandFactory.register_type() needs a type")
	assert(_has_static_from_dict(script), "%s script needs a static from_dict()" % type)
	_ensure_defaults()
	_types[type] = script


## Returns the registered type ids, sorted.
static func registered_types() -> Array[StringName]:
	_ensure_defaults()
	var types: Array[StringName] = []
	types.assign(_types.keys())
	types.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return types


## Registers the built-in command types. Called lazily on first use.
static func register_defaults() -> void:
	_defaults_registered = true
	_types[SetFlagCommand.TYPE] = SetFlagCommand
	_types[DialCommand.TYPE] = DialCommand
	_types[CloseWormholeCommand.TYPE] = CloseWormholeCommand
	_types[ChooseOptionCommand.TYPE] = ChooseOptionCommand
	_types[HailCommand.TYPE] = HailCommand
	_types[DebugStoryCommand.TYPE] = DebugStoryCommand
	_types[AcceptRequestCommand.TYPE] = AcceptRequestCommand
	_types[DeclineRequestCommand.TYPE] = DeclineRequestCommand
	_types[AnswerCallCommand.TYPE] = AnswerCallCommand
	_types[AnswerIncomingCommand.TYPE] = AnswerIncomingCommand
	_types[IgnoreIncomingCommand.TYPE] = IgnoreIncomingCommand
	_types[EndConversationCommand.TYPE] = EndConversationCommand
	_types[DeliverDocumentCommand.TYPE] = DeliverDocumentCommand
	_types[MarkDocumentReadCommand.TYPE] = MarkDocumentReadCommand
	_types[NoteAddressCommand.TYPE] = NoteAddressCommand
	_types[SwitchRoomCommand.TYPE] = SwitchRoomCommand
	_types[SetChargeRateCommand.TYPE] = SetChargeRateCommand
	_types[ReadConsoleCommand.TYPE] = ReadConsoleCommand
	_types[ExtendPoleCameraCommand.TYPE] = ExtendPoleCameraCommand
	_types[PlaceRoomCommand.TYPE] = PlaceRoomCommand
	_types[PaintCorridorCommand.TYPE] = PaintCorridorCommand
	_types[CancelBuildCommand.TYPE] = CancelBuildCommand
	_types[DemolishRoomCommand.TYPE] = DemolishRoomCommand
	_types[DigLevelCommand.TYPE] = DigLevelCommand
	_types[StartResearchCommand.TYPE] = StartResearchCommand
	_types[CancelResearchCommand.TYPE] = CancelResearchCommand
	_types[AssignStaffCommand.TYPE] = AssignStaffCommand
	_types[UnassignStaffCommand.TYPE] = UnassignStaffCommand
	_types[HireCommand.TYPE] = HireCommand
	_types[DismissCommand.TYPE] = DismissCommand
	_types[RaiseWorldStatusCommand.TYPE] = RaiseWorldStatusCommand
	_types[RaiseWorldFactCommand.TYPE] = RaiseWorldFactCommand
	_types[LaunchCanisterCommand.TYPE] = LaunchCanisterCommand
	_types[LaunchMothCommand.TYPE] = LaunchMothCommand
	_types[MothScanCommand.TYPE] = MothScanCommand
	_types[PlanExpeditionCommand.TYPE] = PlanExpeditionCommand
	_types[SendTeamCommand.TYPE] = SendTeamCommand
	_types[RecallTeamCommand.TYPE] = RecallTeamCommand
	_types[SignalTeamCommand.TYPE] = SignalTeamCommand
	_types[ChargeAtMaximumCommand.TYPE] = ChargeAtMaximumCommand


## Drops every registration, so tests can restore a clean registry. The built-in types are
## registered again on next use.
static func reset() -> void:
	_types.clear()
	_defaults_registered = false


static func _ensure_defaults() -> void:
	if _defaults_registered:
		return
	register_defaults()


static func _has_static_from_dict(script: Script) -> bool:
	if script == null:
		return false
	for method: Dictionary in script.get_script_method_list():
		if method["name"] == "from_dict" and method["flags"] & METHOD_FLAG_STATIC:
			return true
	return false
