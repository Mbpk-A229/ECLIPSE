extends Enemy



@export var can_attack : bool= false

#randomisate la func attack
const simple_attacks = {
	'slice':"mixamo_com_005",
	'spin':"mixamo_com_001",
	'range':"mixamo_com_001",
}
# dans worker.gd
func configure(params: Dictionary) -> void:
	super.configure(params)  # appelle d'abord configure() de Enemy
	if params.has("can_attack"):
		can_attack = params["can_attack"]

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
	

func attack() -> void:
	var attack_target = target if target != null else player
	# orientation vers la cible avant d'attaquer
	var target_dir = (attack_target.position - position).normalized()
	var target_vec2 = Vector2(target_dir.x, target_dir.z)
	rotation.y = -target_vec2.angle() + PI/2
	# gestion du timer
	if can_attack and $Timers/AttackTimer.is_stopped():
		$Timers/AttackTimer.start()
	elif not can_attack and not $Timers/AttackTimer.is_stopped():
		$Timers/AttackTimer.stop()

func _on_attack_timer_timeout() -> void:
	var attack_target = target if target != null else player
	if position.distance_to(attack_target.position) < 1.5:
		melee_attack_animation()
	else:
		range_attack_animation()


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

func can_damage(value: bool):
	$skin/Armature/Skeleton3D/BoneAttachment3D/hand_a.can_damage = value
