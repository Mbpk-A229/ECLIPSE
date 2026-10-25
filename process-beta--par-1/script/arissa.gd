extends Enemy


@export var bow_radius := 15.0
@export var can_attack : bool= false
@onready var firemarker = $skin/Armature/Skeleton3D/BoneAttachment3D2/bow2/Marker3D
const FIREBALL = preload("res://vfx/fireball.tscn")

#randomisate la func attack
const simple_attacks = {
	'slice':"mixamo_com_005",
	'spin':"mixamo_com_005",
	'range':"mixamo_com_002",
}
# dans worker.gd
func configure(params: Dictionary) -> void:
	super.configure(params)  # appelle d'abord configure() de Enemy
	if params.has("bow_radius"):
		bow_radius = params["bow_radius"]
	if params.has("can_attack"):
		can_attack = params["can_attack"]

func _ready() -> void:
	enemy_groups = ["zombie_a", "zombie_b" ,"mutan"]  # les groupes a cibler
var _delta : float = 0.0

func _physics_process(delta: float) -> void:
	#suivre le joeur en marchant
	if can_move:
		move_to_player(delta)
	#suivre le joueur en courant 
	if can_chase:
		chase(delta)
	#attaquer le joeur
	if can_attack:
		attack()
	#fuir le joeur
	if can_flee:
		flee(delta)
	#suvre une cible en marchannt ou en courant 
	if can_move_to_target:
		move_to_target(delta)
	if can_chase_target:
		chase_target(delta)
	_auto_detect_enemies()


var is_fleeing : bool = false

func attack() -> void:
	var attack_target = target if target != null else player
	var dist = position.distance_to(attack_target.position)
	#print("dist: ", dist, " | is_fleeing: ", is_fleeing, " | flee_radius: ", flee_radius, " | bow_radius: ", bow_radius)
	var target_dir = (attack_target.position - position).normalized()
	var target_vec2 = Vector2(target_dir.x, target_dir.z)
	
	# on entre en fuite si trop proche
	if dist < flee_radius:
		is_fleeing = true
	# on sort de la fuite seulement si on est suffisamment loin (flee_radius + marge)
	elif dist > flee_radius + 3.0:
		is_fleeing = false
	
	if is_fleeing:
		flee_target(_delta)
		if not $Timers/AttackTimer.is_stopped():
			$Timers/AttackTimer.stop()
	elif dist < bow_radius:
		rotation.y = -target_vec2.angle() + PI/2
		if can_attack and $Timers/AttackTimer.is_stopped():
			$Timers/AttackTimer.start()
		elif not can_attack and not $Timers/AttackTimer.is_stopped():
			$Timers/AttackTimer.stop()
	else:
		velocity = Vector3.ZERO
		move_state_machine.travel('idle')
		if not $Timers/AttackTimer.is_stopped():
			$Timers/AttackTimer.stop()


func _on_attack_timer_timeout() -> void:
	var attack_target = target if target != null else player
	var dist = position.distance_to(attack_target.position)
	if dist < flee_radius:
		return
	elif dist < bow_radius:
		range_attack_animation()
	else:
		return



func range_attack_animation() -> void:
	if attack_animation == null:
		return
	stop_movement(1.5, 1.5)
	attack_animation.animation = simple_attacks['range']
	$AnimationTree.set("parameters/AttackOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func melee_attack_animation() -> void:
	if attack_animation == null:
		return
	attack_animation.animation = simple_attacks['slice' if rng.randi() %2 else 'spin']
	$AnimationTree.set("parameters/AttackOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _on_animation_started(anim_name: StringName) -> void:
	if anim_name == simple_attacks['range']:
		shoot_arrow()

const ARROW = preload("res://weapons/arrow.tscn")

func shoot_arrow() -> void:
	var arrow = ARROW.instantiate()
	get_tree().current_scene.add_child(arrow)
	arrow.global_position = firemarker.global_position
	arrow.direction = -global_transform.basis.z


func can_damage(value: bool):
	$skin/Armature/Skeleton3D/BoneAttachment3D/leg.can_damage = value
