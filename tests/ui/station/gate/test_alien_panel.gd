## Tests for the alien panel: fixed radial key places and stick picking, composing with
## firm and pencilled glyphs, clearing, closing without losing anything, typing a name, the
## centre key dialling (and refusing), the clue clip, and key size.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Composing)
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const VIEW: PackedScene = preload("res://src/ui/station/gate/gate_station_view.tscn")

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateStationView = null


func before_test() -> void:
	_simulation = Fixture.simulation()
	SimClock.start(_simulation)
	_holder = Control.new()
	_holder.size = Vector2(1920, 1080)
	_holder.theme = UiThemeBuilder.build(1.0)
	add_child(_holder)
	_view = VIEW.instantiate() as GateStationView
	_holder.add_child(_view)
	_view.setup(_simulation)
	_view.open_alien_panel()


func after_test() -> void:
	SimClock.stop()
	_holder.free()


func _panel() -> AlienPanel:
	return _view.get_alien_panel()


func test_layout_is_fixed_and_distinct() -> void:
	var seen: Dictionary[Vector2i, bool] = {}
	for glyph: int in GateAddress.GLYPH_COUNT:
		var at: Vector2 = RadialLayout.position_of(glyph, Vector2(500, 500), 400.0)
		seen[Vector2i(at.round())] = true
		var stick: Vector2 = (at - Vector2(500, 500)) / 400.0
		stick = stick.normalized() * [0.5, 0.75, 1.0][RadialLayout.ring_of(glyph)]
		assert_int(RadialLayout.glyph_at_stick(stick)).is_equal(glyph)
	assert_int(seen.size()).is_equal(GateAddress.GLYPH_COUNT)
	assert_int(RadialLayout.glyph_at_stick(Vector2(0.1, 0.0))).is_equal(-1)


func test_draft_firm_pencil_clear() -> void:
	var draft: AddressDraft = AddressDraft.new()
	draft.press(4, false)
	draft.press(9, true)
	assert_int(draft.firm[0]).is_equal(4)
	assert_int(draft.pencil[1]).is_equal(9)
	draft.press(4, false)
	assert_int(draft.firm[0]).is_equal(-1)
	draft.press(5, false)
	assert_int(draft.firm[0]).is_equal(5)
	draft.clear(1)
	assert_int(draft.pencil[1]).is_equal(-1)
	assert_object(draft.address(0)).is_null()


func test_close_keeps_entries() -> void:
	_panel().press_glyph(3)
	_panel().get_draft().press(7, true)
	_panel().close()
	_view.open_alien_panel()
	assert_bool(_panel().get_key(3).is_lit()).is_true()
	assert_int(_panel().get_draft().pencil.find(7)).is_greater_equal(0)


func test_typing_finds_a_glyph() -> void:
	var def: GlyphDef = Registry.get_def(&"glyph_05") as GlyphDef
	var name_text: String = tr(def.name_key)
	var found: int = _panel().type_text(name_text)
	assert_int(found).is_equal(5)
	assert_bool(_panel().get_key(5).is_pulsing()).is_true()


func test_centre_key_dials_and_becomes_a_card() -> void:
	var address: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK)
	for glyph: int in address.coordinates:
		_panel().press_glyph(glyph)
	assert_object(_panel().get_address()).is_not_null()
	(_panel().find_child("DialKey", true, false) as BigKey).pressed.emit()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.DIALING)
	assert_bool(_panel().visible).is_false()
	for i: int in _simulation.state.balance.dial_duration_ticks + 1:
		_simulation.advance_tick()
	assert_object(_simulation.state.address_book.find(address.key())).is_not_null()


func test_incomplete_dial_refused() -> void:
	_panel().press_glyph(1)
	(_panel().find_child("DialKey", true, false) as BigKey).pressed.emit()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_bool(_panel().visible).is_true()


func test_keys_are_large() -> void:
	assert_float(_panel().get_key(0).size.x).is_greater_equal(72.0)


func test_clue_clip_swaps() -> void:
	_simulation.state.archive.add(&"doc_lintel_note", 0)
	_simulation.state.archive.add(&"doc_lintel_dossier", 0)
	var clip: ClueClip = _panel().find_child("ClueClip", true, false) as ClueClip
	clip.setup(_simulation)
	var first: StringName = clip.get_document_id()
	clip.step(1)
	assert_str(String(clip.get_document_id())).is_not_equal(String(first))


## Every round key sits inside the free area and no two keys touch, at each size.
func test_keys_fit_without_overlap_at_every_size() -> void:
	for size: Vector2 in [
		Vector2(1280, 600), Vector2(1920, 960), Vector2(2560, 1300), Vector2(3440, 1300)
	]:
		_holder.size = size
		_view.size = size
		_panel().size = size
		_panel()._place_keys()
		var rects: Array[Rect2] = []
		for glyph: int in GateAddress.GLYPH_COUNT:
			var key: GlyphKey = _panel().get_key(glyph)
			rects.append(Rect2(key.position, key.size))
		var area: Rect2 = _panel().key_area()
		for index: int in rects.size():
			assert_bool(area.grow(1.0).encloses(rects[index])).is_true()
			for other: int in range(index + 1, rects.size()):
				var gap: float = rects[index].get_center().distance_to(rects[other].get_center())
				assert_float(gap).is_greater_equal(rects[index].size.x)
