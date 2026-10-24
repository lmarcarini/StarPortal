extends RefCounted
## Test fixture for the Archive tests: fixture content loaded into the Registry (a note and an
## image that pair, both delivered at start, and a dossier delivered later, with a home world),
## English test strings for them (the dossier is long), a paused simulation, the view mounted
## at the shell's view size, and input helpers that do not move focus first.
## Bible: game-design.md#core-loop, gate-and-address-spec.md#the-opening-puzzle

const CONTENT_ROOT: String = "res://tests/ui/fixtures/archive/"
const VIEW_SCENE: String = "res://src/ui/views/archive/archive_view.tscn"
## Size of the area the shell gives a view at the minimum window size.
const VIEW_SIZE: Vector2 = Vector2(1280, 600)
const NOTE: StringName = &"doc_note"
const RUBBING: StringName = &"doc_rubbing"
const DOSSIER: StringName = &"doc_dossier"
## The home world's name: the Archive must never show it, since no document's text names it.
const WORLD_NAME: String = "Kestrel Deep"
## English test strings, as {key: text}.
const STRINGS: Dictionary[StringName, String] = {
	&"ARCHIVE_TEST_NOTE_TITLE": "Field note, lintel",
	&"ARCHIVE_TEST_NOTE_BODY": "The bird first.\n\nThen the one that *holds fire*, then **water**.",
	&"ARCHIVE_TEST_RUBBING_TITLE": "Rubbing of the lintel",
	&"ARCHIVE_TEST_DOSSIER_TITLE": "Directorate file 61-B",
	&"ARCHIVE_TEST_SOURCE": "Survey team, 1958",
	&"ARCHIVE_TEST_DIRECTORATE": "The Directorate",
	&"ARCHIVE_TEST_WORLD_NAME": WORLD_NAME,
}


## Loads the fixture content into the Registry autoload. Call [method restore] afterwards.
static func load_content() -> Array[String]:
	var errors: Array[String] = Registry.load_all(CONTENT_ROOT).value
	return errors


## Reloads the game's own content into the Registry autoload.
static func restore() -> void:
	Registry.load_all()


## Returns an English translation of the test strings, with a long dossier body; the caller
## adds it to the TranslationServer and removes it afterwards.
static func translation() -> Translation:
	var table := Translation.new()
	table.locale = "en"
	for key: StringName in STRINGS:
		table.add_message(key, STRINGS[key])
	table.add_message(&"ARCHIVE_TEST_DOSSIER_BODY", long_body())
	return table


## Forty paragraphs of text, far more than the reader shows at once.
static func long_body() -> String:
	var paragraphs: PackedStringArray = []
	for index: int in 40:
		paragraphs.append(
			(
				(
					"Paragraph %d. The survey party logged the chamber at depth, noting salt bloom "
					+ "on the lintel and a draught from the far wall that no one could explain."
				)
				% (index + 1)
			)
		)
	return "\n\n".join(paragraphs)


## Returns a paused simulation over the fixture documents with the AT_START ones delivered at
## tick 0, as GameSetup.build_new() does: their document_received events wait in the outbox.
static func simulation() -> Simulation:
	var state := GameState.new_game(20261023, BalanceConfig.new())
	var documents: Array[DocumentDef] = []
	for def: DefBase in Registry.get_all_of(DocumentDef):
		documents.append(def as DocumentDef)
	DocumentSystem.deliver_start_documents(state, documents)
	var systems: Array[SimSystem] = [DocumentSystem.new(documents)]
	return Simulation.new(state, systems)


## Returns a Control of [constant VIEW_SIZE] that holds a new Archive view. The caller adds
## the holder to the tree and frees it.
static func mount_view() -> Control:
	var holder := Control.new()
	holder.size = VIEW_SIZE
	holder.add_child((load(VIEW_SCENE) as PackedScene).instantiate())
	return holder


## Returns the Archive view inside [param holder] from [method mount_view].
static func view_of(holder: Control) -> ArchiveView:
	return holder.get_child(0) as ArchiveView


## Presses and releases [param keycode] wherever focus is.
static func key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await _settle()


## Presses and releases gamepad [param button] wherever focus is.
static func pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await _settle()


## Turns the mouse wheel one notch ([param up] or down) over the centre of [param control].
static func wheel(control: Control, up: bool) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	var button: MouseButton = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = at
		event.global_position = at
		control.get_viewport().push_input(event, true)
	await _settle()


static func _settle() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	await tree.process_frame
	await tree.process_frame
