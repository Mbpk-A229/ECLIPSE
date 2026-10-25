@tool
extends StaticBody3D
class_name EnvironmentElement

# Classe de base pour tout élément d'environnement (arbre, rocher, falaise, etc.)
# Chaque scène d'élément (ex: tree_pine.tscn) hérite de ce comportement en
# attachant ce script à son StaticBody3D racine.
# Le mesh visuel et le CollisionShape3D sont placés à la main dans l'éditeur,
# alignés précisément l'un sur l'autre une fois pour toutes.

@export var default_scale_min: float = 0.9
@export var default_scale_max: float = 1.3
@export var default_randomize_rotation: bool = true


# ===============================
# API PUBLIQUE POUR LE SPAWNER / L'IA
# ===============================
func configure(params: Dictionary = {}) -> void:
	# Échelle : soit une valeur précise, soit une plage aléatoire
	if params.has("scale"):
		var s: float = params["scale"]
		scale = Vector3.ONE * s
	else:
		var scale_min: float = params.get("scale_min", default_scale_min)
		var scale_max: float = params.get("scale_max", default_scale_max)
		scale = Vector3.ONE * randf_range(scale_min, scale_max)

	# Rotation Y : précise ou aléatoire
	if params.has("rotation_y"):
		rotation.y = params["rotation_y"]
	elif params.get("randomize_rotation", default_randomize_rotation):
		rotation.y = randf_range(0.0, TAU)
