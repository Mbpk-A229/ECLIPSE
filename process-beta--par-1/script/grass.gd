@tool
extends MultiMeshInstance3D

# =========================
# PARAMÈTRES GÉNÉRAUX
# =========================
@export var grass_mesh: Mesh                # Mesh d’herbe importé
@export var area_size: float = 256.0        # Taille de la zone couverte
@export var auto_generate: bool = true      # Génération automatique au lancement

# =========================
# PARAMÈTRES PAR DÉFAUT
# =========================
@export var default_density: int = 25000
@export var default_color: Color = Color(0.2, 0.7, 0.2)
@export var default_scale_min: float = 0.8
@export var default_scale_max: float = 1.2


func _ready():
	if auto_generate:
		generate_grass()


# ==================================================
# FONCTION PRINCIPALE (IA / MAP / BIOME)
# ==================================================
func generate_grass(params := {}):
	var density: int = params.get("density", default_density)
	var base_color: Color = params.get("color", default_color)
	var scale_min: float = params.get("scale_min", default_scale_min)
	var scale_max: float = params.get("scale_max", default_scale_max)

	if grass_mesh == null:
		push_error("Grass mesh non assigné")
		return

	# -------- MULTIMESH --------
	multimesh = MultiMesh.new()
	multimesh.mesh = grass_mesh
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.instance_count = density

	# -------- GÉNÉRATION --------
	for i in range(density):
		var x = randf_range(-area_size * 0.5, area_size * 0.5)
		var z = randf_range(-area_size * 0.5, area_size * 0.5)
		var y = 0.0  # terrain plat pour l’instant

		var grass_scale = randf_range(scale_min, scale_max)

		var grass_transform := Transform3D()
		grass_transform.origin = Vector3(x, y, z)
		grass_transform.basis = Basis().scaled(Vector3.ONE * grass_scale)

		multimesh.set_instance_transform(i, grass_transform)

		# Variation naturelle de couleur
		multimesh.set_instance_color(
			i,
			base_color * randf_range(0.8, 1.2)
		)


func clear_grass():
	if multimesh:
		multimesh.instance_count = 0
