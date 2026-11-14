## Camera feed kit: every set builds headless, states switch, people show as figures, and a
## feed that is not live stops rendering.
## Bible: docs/content/interface-pass.md sections 1 and 5 (Camera inset)
extends GdUnitTestSuite

const SET_ROOMS: Array[StringName] = [&"room_gate", &"room_control", &"room_quarters"]


func test_catalogue_gives_own_sets_and_a_generic_one() -> void:
	assert_object(auto_free(RoomSetCatalogue.for_room(&"room_gate"))).is_instanceof(GateRoomSet)
	assert_object(auto_free(RoomSetCatalogue.for_room(&"room_control"))).is_instanceof(
		ControlRoomSet
	)
	assert_object(auto_free(RoomSetCatalogue.for_room(&"room_x"))).is_instanceof(GenericRoomSet)
	assert_bool(RoomSetCatalogue.has_own_set(&"room_quarters")).is_false()


func test_every_set_builds_with_a_fixed_camera_and_a_light() -> void:
	for def_id: StringName in SET_ROOMS:
		var feed: RoomCameraFeed = auto_free(RoomCameraFeed.new())
		add_child(feed)
		feed.show_set(RoomSetCatalogue.for_room(def_id), "CAM 01")
		await get_tree().process_frame
		var room_set: RoomSet = feed.get_set()
		assert_bool(room_set.is_node_ready()).is_true()
		assert_bool(room_set.camera.is_inside_tree()).is_true()
		assert_bool(room_set.light.shadow_enabled).is_false()
		assert_bool(feed.no_signal.visible).is_false()
		assert_str(feed.label.text).is_equal("CAM 01")


func test_states_dark_and_scaffolding() -> void:
	var feed: RoomCameraFeed = auto_free(RoomCameraFeed.new())
	add_child(feed)
	feed.show_set(GenericRoomSet.new(), "CAM 02")
	await get_tree().process_frame
	var room_set: RoomSet = feed.get_set()
	feed.set_room_state(RoomSet.STATE_OFF)
	assert_bool(room_set.light.visible).is_false()
	feed.set_room_state(RoomSet.STATE_SITE)
	assert_bool((room_set.get_node("Scaffolding") as Node3D).visible).is_true()
	assert_bool((room_set.get_node("Props") as Node3D).visible).is_false()
	feed.set_room_state(RoomSet.STATE_ON)
	assert_bool(room_set.light.visible).is_true()


func test_people_become_figures() -> void:
	var room_set: RoomSet = auto_free(GenericRoomSet.new())
	add_child(room_set)
	var people: Array[FeedPerson] = [
		FeedPerson.create(&"scientist", Vector2(0.2, 0.3)),
		FeedPerson.create(&"engineer", Vector2(0.8, 0.6)),
	]
	room_set.set_people(people)
	assert_int(room_set.people_count()).is_equal(2)


func test_not_live_stops_rendering_and_no_signal_drops_the_set() -> void:
	var feed: RoomCameraFeed = auto_free(RoomCameraFeed.new())
	add_child(feed)
	feed.show_set(GateRoomSet.new(), "CAM 00")
	feed.set_live(false)
	assert_int(feed.viewport.render_target_update_mode).is_equal(SubViewport.UPDATE_DISABLED)
	feed.set_live(true)
	assert_int(feed.viewport.render_target_update_mode).is_equal(SubViewport.UPDATE_ALWAYS)
	feed.show_no_signal()
	assert_object(feed.get_set()).is_null()
	assert_bool(feed.no_signal.visible).is_true()
	assert_int(feed.viewport.size.x).is_equal(320)
