extends Node3D
## The Gate hall (M5-02): built from the MegaKit and simple boxes; this script only tints the
## kit's clean sci-fi materials toward the industrial palette (darker, warmer, worn), once per
## material so pieces still batch.
## Bible: docs/content/interface-reference.md section 7

## Multiplier on the kit's albedo, and roughness added.
const TINT: Color = Color(0.52, 0.48, 0.4)
const ROUGHER: float = 0.25
## Nodes in this group get the tint.
const KIT_GROUP: StringName = &"kit"

var _tinted: Dictionary[Material, Material] = {}


func _ready() -> void:
	for node: Node in get_tree().get_nodes_in_group(KIT_GROUP):
		if is_ancestor_of(node):
			for mesh: Node in node.find_children("*", "MeshInstance3D", true, false):
				_tint(mesh as MeshInstance3D)


func _tint(mesh: MeshInstance3D) -> void:
	for i: int in mesh.mesh.get_surface_count():
		var source: BaseMaterial3D = mesh.mesh.surface_get_material(i) as BaseMaterial3D
		if source == null:
			continue
		if not _tinted.has(source):
			var copy: BaseMaterial3D = source.duplicate() as BaseMaterial3D
			copy.albedo_color = source.albedo_color * TINT
			copy.roughness = minf(1.0, source.roughness + ROUGHER)
			copy.emission_energy_multiplier *= 0.3
			_tinted[source] = copy
		mesh.set_surface_override_material(i, _tinted[source])
