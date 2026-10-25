extends Area3D

@export var speed : float = 15.0
@export var damage : int = 15
var direction : Vector3 = Vector3.ZERO
@onready var audio = $AudioStreamPlayer3D

func _ready() -> void:
	audio.play()
	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position -= direction * speed * delta
	# la fleche s'oriente en permanence dans sa direction de deplacement
	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)


func _on_body_entered(body: Node) -> void:
	if body.has_method("hit"):
		body.hit(damage)
	elif body.has_method("hit_player"):
		body.hit_player()
	queue_free()
