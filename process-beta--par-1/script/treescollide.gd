extends Node3D

@onready var colliders: Node3D = $Colliders




func _ready():
	set_tree_collisions([
		Vector3(0, 0, 0),
		Vector3(5, 0, 5),
		Vector3(-5, 0, -5)
	])



# ===============================
# API PUBLIQUE POUR L’IA
# ===============================
func set_tree_collisions(tree_positions: Array):
	clear_colliders()

	for pos in tree_positions:
		_create_tree_collider(pos)


# ===============================
# COLLISION INDIVIDUELLE
# ===============================
func _create_tree_collider(world_pos: Vector3):
	var body := StaticBody3D.new()
	colliders.add_child(body)
	body.global_position = world_pos

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 1.2
	shape.height = 6.0

	collision.shape = shape
	collision.position.y = shape.height * 0.5
	body.add_child(collision)


# ===============================
# NETTOYAGE
# ===============================
func clear_colliders():
	for c in colliders.get_children():
		c.queue_free()
