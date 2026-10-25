extends Node3D
@export var min_limit_x : float
@export var max_limit_x : float
@export var horizontal_acceleration:= 2.0
@export var vertical_acceleration := 1.0
@export var mouse_acceleration := 0.005
@onready var camera_pivot : Node3D = $CameraPivot
@onready var camera : Camera3D = $CameraPivot/Camera3D
@onready var aim_anim_player : AnimationPlayer = $CameraPivot/Camera3D/AimAnimPlayer
@export var aim_offset : Vector3 = Vector3(0.6, 0.3, 0.0)
@export var aim_offset_speed : float = 8.0
var default_camera_local_position : Vector3

@export var aim_vertical_limit_degrees : float = 20.0
var aim_base_rotation_x : float = 0.0

var is_aiming : bool = false
func _ready() -> void:
	default_camera_local_position = camera.position
func set_aiming(value: bool) -> void:
	if value == is_aiming:
		return
	is_aiming = value
	if value:
		aim_base_rotation_x = rotation.x
		aim_anim_player.play("zoom")
	else:
		aim_anim_player.play_backwards("zoom")
#avec manette
func _process(delta: float) -> void:
	var joy_dir = Input.get_vector("pan_left","pan_right","pan_up","pan_down")
	rotate_from_vector(joy_dir * delta * Vector2(horizontal_acceleration,vertical_acceleration))
	
	var target_position = default_camera_local_position + aim_offset if is_aiming else default_camera_local_position
	camera.position = camera.position.lerp(target_position, clampf(aim_offset_speed * delta, 0.0, 1.0))
#avec souris
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_from_vector(event.relative * mouse_acceleration)
		
		
# fonction de controle et de limitation de rotation de camera sur manet comme avec souris
func rotate_from_vector(v: Vector2):
	if v.length() == 0 : return
	rotation.y -= v.x
	rotation.x -= v.y
	rotation.x= clamp(rotation.x, min_limit_x,max_limit_x)
	if is_aiming:
		var limit_rad = deg_to_rad(aim_vertical_limit_degrees)
		rotation.x = clamp(rotation.x, aim_base_rotation_x - limit_rad, aim_base_rotation_x + limit_rad)
