class_name HallTextures
extends RefCounted
## Gives a hall material its PBR maps from a texture set folder when they exist
## (albedo.png, normal.png, roughness.png); missing files leave the flat material unchanged.
## Bible: docs/content/interface-reference.md section 7


## Applies the maps under [param folder] to [param material] (null-safe).
static func apply(material: BaseMaterial3D, folder: String) -> void:
	if material == null:
		return
	var albedo: Texture2D = _load(folder, "albedo")
	if albedo != null:
		material.albedo_texture = albedo
		material.albedo_color = Color(0.8, 0.8, 0.8)
	var normal: Texture2D = _load(folder, "normal")
	if normal != null:
		material.normal_enabled = true
		material.normal_texture = normal
	var rough: Texture2D = _load(folder, "roughness")
	if rough != null:
		material.roughness_texture = rough
		material.roughness = 1.0


## The texture [param map].png in [param folder], or null.
static func _load(folder: String, map: String) -> Texture2D:
	var path: String = folder.path_join(map + ".png")
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
