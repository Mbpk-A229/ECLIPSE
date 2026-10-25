@tool
extends MeshInstance3D

# =====================
# PARAMÈTRES COURANTS
# =====================
var terrain_size := 256.0
var terrain_color := Color(0.2, 0.7, 0.2)

# Position par défaut du terrain
var default_position: Vector3 = Vector3.ZERO

@export_range(4, 256, 4) var resolution := 32:
	set(value):
		resolution = value
		update_terrain()


func _ready():
	# Placement par défaut
	global_position = default_position
	update_terrain()


# =====================
# INTERFACE IA
# =====================

# IA : configure le terrain (forme / couleur / résolution)
func set_terrain(size: float, color: Color, new_resolution := -1) -> void:
	terrain_size = size
	terrain_color = color

	if new_resolution > 0:
		resolution = new_resolution

	update_terrain()


# IA : déplace le terrain dans le monde
func set_terrain_position(pos: Vector3) -> void:
	global_position = pos


# IA : reset à la position par défaut
func reset_position() -> void:
	global_position = default_position


# IA : infos utiles pour le monde
func get_bounds() -> Dictionary:
	return {
		"size": terrain_size,
		"half_size": terrain_size * 0.5,
		"position": global_position
	}


# =====================
# GÉNÉRATION TERRAIN
# =====================
func update_terrain() -> void:
	update_mesh()
	update_collision()


func update_mesh() -> void:
	var plane := PlaneMesh.new()
	plane.subdivide_depth = resolution
	plane.subdivide_width = resolution
	plane.size = Vector2(terrain_size, terrain_size)

	var arrays := plane.get_mesh_arrays()
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays
	)

	mesh = array_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = terrain_color
	material_override = mat


func update_collision() -> void:
	if has_node("CollisionBody"):
		$CollisionBody.queue_free()

	var body := StaticBody3D.new()
	body.name = "CollisionBody"
	add_child(body)

	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.data = mesh.get_faces()
	collision.shape = shape

	body.add_child(collision)
