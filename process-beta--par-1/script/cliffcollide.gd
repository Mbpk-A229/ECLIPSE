extends Node3D

@onready var visuals := $CliffVisuals
@onready var colliders := $CliffColliders


# ===============================
# API PUBLIQUE POUR L’IA
# ===============================
func build_cliffs_from_positions(positions: Array, scales: Array):
	clear_colliders()

	for i in range(positions.size()):
		_create_collider(positions[i], scales[i])


# ===============================
# COLLISION
# ===============================
func _create_collider(pos: Vector3, instance_scale: float):
	var body := StaticBody3D.new()
	colliders.add_child(body)
	body.global_position = pos

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10, 12, 10) * instance_scale

	collision.shape = shape
	collision.position.y = shape.size.y * 0.5
	body.add_child(collision)


func clear_colliders():
	for c in colliders.get_children():
		c.queue_free()
