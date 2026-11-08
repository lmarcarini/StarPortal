class_name MothFrameRules
extends RefCounted
## Pure rules of the MOTH's camcorder stills: each frame is generated from the world scene as it
## stands now (SceneNow, ScenePhotoRules) and framed for what the drone is doing. Hovering (or
## recalling) shows the scene from the drone's height; Look around pans it; a Close look fills
## the frame with its target (nothing, when the target is gone); Sky tilts up to the sky and
## sun; Ring turns back to the far Ring. Cheap: a few dozen shapes, no texture.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (MOTH: a 2D scan screen) and section 7

## The frame while no scan runs.
const HOVER: int = -1
## How far Look around pans the scenery, as a fraction of the frame.
const PAN: float = 0.35


## Returns the frame of [param scene] for [param scan] (a MothRules.Scan, or HOVER), of
## [param target_id] for a Close look.
static func params_for(
	scene: WorldScene, scan: int, target_id: StringName = &""
) -> HorizonPhotoRules.Params:
	var params: HorizonPhotoRules.Params = ScenePhotoRules.params_for(scene)
	params.horizon = minf(params.horizon + 0.06, 0.8)
	match scan:
		MothRules.Scan.LOOK_AROUND:
			for index: int in params.silhouette_x.size():
				params.silhouette_x[index] = fposmod(params.silhouette_x[index] + PAN, 1.0)
		MothRules.Scan.CLOSE_LOOK:
			_frame_target(params, target_id)
		MothRules.Scan.SKY:
			params.horizon = 0.94
			_keep_only(params, -1)
			for index: int in params.suns.size():
				var sun: Vector3 = params.suns[index]
				params.suns[index] = Vector3(sun.x, 0.45, sun.z * 2.0)
		MothRules.Scan.RING:
			_keep_only(params, -1)
			_add_one(params, HorizonPhotoRules.Silhouette.RING, &"", 0.55)
	return params


static func _frame_target(params: HorizonPhotoRules.Params, target_id: StringName) -> void:
	var index: int = ScenePhotoRules.silhouette_of(params, target_id)
	var kind: HorizonPhotoRules.Silhouette = HorizonPhotoRules.Silhouette.ROCK
	if index >= 0:
		kind = params.silhouette_kinds[index]
	_keep_only(params, -1)
	params.horizon = 0.62
	params.life_marks *= 2
	if index >= 0:
		_add_one(params, kind, target_id, 0.42)


## Keeps the silhouette at [param index] only (none when -1).
static func _keep_only(params: HorizonPhotoRules.Params, index: int) -> void:
	var kept := HorizonPhotoRules.Params.new()
	if index >= 0:
		kept.silhouette_kinds.append(params.silhouette_kinds[index])
		kept.silhouette_x.append(params.silhouette_x[index])
		kept.silhouette_height.append(params.silhouette_height[index])
		kept.silhouette_targets.append(params.silhouette_targets[index])
	params.silhouette_kinds = kept.silhouette_kinds
	params.silhouette_x = kept.silhouette_x
	params.silhouette_height = kept.silhouette_height
	params.silhouette_targets = kept.silhouette_targets


static func _add_one(
	params: HorizonPhotoRules.Params,
	kind: HorizonPhotoRules.Silhouette,
	target_id: StringName,
	height: float
) -> void:
	params.silhouette_kinds.append(kind)
	params.silhouette_x.append(0.5)
	params.silhouette_height.append(height)
	params.silhouette_targets.append(target_id)
