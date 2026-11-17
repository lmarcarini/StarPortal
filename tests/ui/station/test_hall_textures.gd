## HallTextures: a missing texture set leaves the flat material as it was.
## Bible: docs/content/interface-reference.md section 7
extends GdUnitTestSuite


func test_missing_maps_keep_the_flat_material() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.2, 0.2)
	HallTextures.apply(material, "res://art/3d/textures/nothing_here")
	assert_object(material.albedo_texture).is_null()
	assert_bool(material.normal_enabled).is_false()
	assert_float(material.albedo_color.r).is_equal_approx(0.2, 0.001)
