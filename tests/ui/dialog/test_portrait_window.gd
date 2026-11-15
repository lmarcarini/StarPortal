## Tests for the portrait window and placeholder portraits (M4.8-05): every channel uses the
## video look, with a Ring-blue or CRT-green frame and its label; a still shows a fixed
## picture and reads STILL; talking follows the transcript's typing; a new speaker swaps the
## portrait and the name plate; animation stops when hidden and with reduced motion (except the
## mouth); a new kind is one renderer and one factory line.
## Bible: docs/content/dialogue-screen.md section 3
extends GdUnitTestSuite

const FakeRenderer := preload("res://tests/ui/dialog/fake_portrait_renderer.gd")

var _fixture: DialogueFixture
var _screen: DialogueScreen


func before_test() -> void:
	Settings.set_value(&"display", &"ambient_movement", true)
	_fixture = DialogueFixture.new(self)
	_screen = _fixture.screen


func after_test() -> void:
	Settings.set_value(&"display", &"ambient_movement", true)
	PortraitRenderer.register_kind(&"fake", null)
	_fixture.dispose()


func _placeholder() -> PlaceholderPortrait:
	return _screen.portrait.get_renderer() as PlaceholderPortrait


func test_ring_channel_look() -> void:
	_fixture.start(&"conv_kindred_first_hail")
	var window: PortraitWindow = _screen.portrait
	assert_object(window.get_frame_colour()).is_equal(UiPalette.RING)
	assert_array(window.get_label_texts()).is_equal(["VIDEO LINK · RING · LINTEL", "LIVE"])
	var look: ShaderMaterial = window.get_video().material as ShaderMaterial
	assert_object(look.shader).is_equal(load("res://src/ui/camera/feed_shader.gdshader"))
	assert_float(look.get_shader_parameter(&"roll")).is_equal(1.0)
	assert_str(look.shader.code).contains("scanline_strength")
	assert_bool(_placeholder() != null).is_true()
	assert_bool(_placeholder().animated).is_true()


func test_a_committee_still_on_the_secure_line() -> void:
	_fixture.start(&"conv_committee_briefing", &"phone")
	var window: PortraitWindow = _screen.portrait
	assert_object(window.get_frame_colour()).is_equal(UiPalette.GOOD)
	assert_array(window.get_label_texts()).is_equal(["VIDEO LINK · SECURE LINE", "STILL"])
	var still: PlaceholderPortrait = _placeholder()
	assert_bool(still.animated).is_false()
	assert_bool(still.talking).is_false()
	assert_bool(still.is_processing()).is_false()
	still.advance(10.0)
	assert_float(still.breath_offset()).is_equal(0.0)
	assert_float(still.mouth_open()).is_equal(0.0)
	assert_bool(still.is_blinking()).is_false()


func test_talking_follows_the_typing() -> void:
	_fixture.start(&"conv_kindred_first_hail")
	var figure: PlaceholderPortrait = _placeholder()
	assert_bool(figure.talking).is_true()
	figure.advance(0.1)
	assert_float(figure.mouth_open()).is_greater(0.0)
	_screen.transcript._process(60.0)
	assert_bool(figure.talking).is_false()
	figure.advance(0.1)
	assert_float(figure.mouth_open()).is_equal(0.0)


func test_idle_breathes_and_blinks() -> void:
	_fixture.start(&"conv_kindred_first_hail")
	var figure: PlaceholderPortrait = _placeholder()
	figure.size = Vector2(300, 300)
	figure.advance(1.0)
	assert_float(absf(figure.breath_offset())).is_greater(0.0)
	var blinked: bool = false
	for step: int in 400:
		figure.advance(0.05)
		blinked = blinked or figure.is_blinking()
	assert_bool(blinked).is_true()


func test_a_new_speaker_swaps_the_portrait_and_mood_changes() -> void:
	_fixture.start(&"conv_kindred_first_hail")
	var first: PortraitRenderer = _placeholder()
	var elder: SpeakerDef = _fixture.state.speaker_defs[&"speaker_kindred_elder"]
	_screen.speaker_shown(elder, &"angry")
	assert_object(_screen.portrait.get_renderer()).is_same(first)
	assert_str(String(first.mood)).is_equal("angry")
	var ossar: StringName = &"speaker_ossar_warden"
	var node := ConversationNodeDef.new()
	node.speaker = ossar
	node.text_key = &"CONV_OSSAR_DEMAND_1"
	node.mood = &"wary"
	_screen.show_line(node)
	assert_object(_screen.portrait.get_renderer()).is_not_same(first)
	assert_str(String(_placeholder().def.id)).is_equal("portrait_ossar_warden")
	assert_str(String(_placeholder().mood)).is_equal("wary")
	assert_str(_screen.name_plate.get_texts()[0]).is_equal("OSSAR WARDEN")


func test_animation_stops_when_hidden() -> void:
	_fixture.start(&"conv_kindred_first_hail")
	var figure: PlaceholderPortrait = _placeholder()
	assert_bool(figure.is_processing()).is_true()
	_fixture.root.visible = false
	assert_bool(figure.is_processing()).is_false()
	_fixture.root.visible = true
	assert_bool(figure.is_processing()).is_true()


func test_reduced_motion_keeps_only_the_mouth() -> void:
	Settings.set_value(&"display", &"ambient_movement", false)
	_fixture.start(&"conv_kindred_first_hail")
	var figure: PlaceholderPortrait = _placeholder()
	figure.size = Vector2(300, 300)
	assert_bool(figure.animated).is_false()
	figure.advance(1.0)
	assert_float(figure.breath_offset()).is_equal(0.0)
	assert_float(figure.mouth_open()).is_greater(0.0)
	Settings.set_value(&"display", &"ambient_movement", true)
	assert_bool(figure.animated).is_true()


func test_each_renderer_has_its_own_stream() -> void:
	var portrait: PortraitDef = _fixture.state.portrait_defs[&"portrait_kindred_elder"]
	var one: PortraitRenderer = auto_free(PortraitRenderer.create(portrait))
	var two: PortraitRenderer = auto_free(PortraitRenderer.create(portrait))
	assert_object(one.rng).is_not_same(two.rng)
	assert_int(one.rng.randi()).is_equal(two.rng.randi())


func test_a_new_kind_is_one_renderer_and_one_factory_line() -> void:
	PortraitRenderer.register_kind(&"fake", FakeRenderer)
	var portrait := PortraitDef.new()
	portrait.id = &"portrait_fake"
	portrait.kind = &"fake"
	var renderer: PortraitRenderer = auto_free(PortraitRenderer.create(portrait))
	assert_bool(renderer is FakeRenderer).is_true()
	assert_object(renderer.def).is_same(portrait)
	portrait.kind = &"unknown"
	assert_object(PortraitRenderer.create(portrait)).is_null()
	_fixture.state.portrait_defs[&"portrait_kindred_elder"] = PortraitDef.new()
	_fixture.state.portrait_defs[&"portrait_kindred_elder"].kind = &"fake"
	_fixture.start(&"conv_kindred_first_hail")
	assert_bool(_screen.portrait.get_renderer() is FakeRenderer).is_true()
