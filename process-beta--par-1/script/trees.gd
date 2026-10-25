@tool
extends MultiMeshInstance3D

@export var tree_mesh: Mesh
@export var area_size: float = 256.0
@export var auto_generate: bool = true

@export var default_density: int = 60
@export var default_scale_min: float = 0.9
@export var default_scale_max: float = 1.4
@export var min_distance: float = 8.0


func _ready():
	if auto_generate:
		generate_trees()


func generate_trees(params := {}):
	var density: int = params.get("density", default_density)
	var scale_min: float = params.get("scale_min", default_scale_min)
	var scale_max: float = params.get("scale_max", default_scale_max)
	var min_dist: float = params.get("min_distance", min_distance)

	if tree_mesh == null:
		push_error("Tree mesh non assigné")
		return

	multimesh = MultiMesh.new()
	multimesh.mesh = tree_mesh
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = density

	var placed_positions: Array[Vector3] = []
	var i := 0
	var safety := 0

	while i < density and safety < density * 20:
		safety += 1

		var x = randf_range(-area_size * 0.5, area_size * 0.5)
		var z = randf_range(-area_size * 0.5, area_size * 0.5)
		var y = 0.0

		var pos := Vector3(x, y, z)

		var valid := true
		for p in placed_positions:
			if p.distance_to(pos) < min_dist:
				valid = false
				break

		if not valid:
			continue

		placed_positions.append(pos)

		var tree_scale = randf_range(scale_min, scale_max)

		var tree_transform := Transform3D()
		tree_transform.origin = pos
		tree_transform.basis = Basis().scaled(Vector3.ONE * tree_scale)

		multimesh.set_instance_transform(i, tree_transform)
		i += 1


func clear_trees():
	if multimesh:
		multimesh.instance_count = 0
