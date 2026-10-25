@tool
extends MultiMeshInstance3D

@export var cliff_mesh: Mesh
@export var area_size := 256.0
@export var auto_generate := true

@export var default_density := 10
@export var default_scale_min := 1.0
@export var default_scale_max := 2.5

var generated_positions: Array[Vector3] = []
var generated_scales: Array[float] = []


func _ready():
	if cliff_mesh == null:
		push_warning("⚠ Cliff mesh non assigné")
		return

	if auto_generate:
		generate_auto()


# =========================
# MODE AUTO (DEBUG / EDITEUR)
# =========================
func generate_auto():
	var positions: Array[Vector3] = []

	for i in range(default_density):
		var x = randf_range(-area_size * 0.5, area_size * 0.5)
		var z = randf_range(-area_size * 0.5, area_size * 0.5)
		positions.append(Vector3(x, 0, z))

	generate_from_positions(positions)


# =========================
# MODE IA / API PUBLIQUE
# =========================
func generate_from_positions(positions: Array, params := {}):
	if positions.is_empty():
		push_warning("⚠ Aucun emplacement de falaise fourni")
		return

	var scale_min: float = params.get("scale_min", default_scale_min)
	var scale_max: float = params.get("scale_max", default_scale_max)


	generated_positions.clear()
	generated_scales.clear()

	multimesh = MultiMesh.new()
	multimesh.mesh = cliff_mesh
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = positions.size()

	for i in range(positions.size()):
		var instance_scale := randf_range(scale_min, scale_max)

		generated_positions.append(positions[i])
		generated_scales.append(instance_scale)

		var t := Transform3D()
		t.origin = positions[i]
		t.basis = Basis().scaled(Vector3.ONE * instance_scale)

		multimesh.set_instance_transform(i, t)
