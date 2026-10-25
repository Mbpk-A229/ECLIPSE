extends Enemy



@export var can_attack : bool= false
@export var current_weapon : String = "fists"  # fists, bat, knife


#randomisate la func attack
const simple_attacks = {
	'slice':"mixamo_com_001",
	'spin':"mixamo_com_001",
	'bat':"mixamo_com_005",
	'bat_f':"mixamo_com_006",
	'cut':"mixamo_com_009",
	'range':"mixamo_com_008"
	
}

# armes disponibles et leurs animations associées
const weapon_attacks = {
	"fists": ["slice", "spin"],
	"bat": ["bat", "bat_f"],
	"knife": ["cut"]
}

# dans worker.gd
func configure(params: Dictionary) -> void:
	super.configure(params)  # appelle d'abord configure() de Enemy
	if params.has("can_attack"):
		can_attack = params["can_attack"]
	if params.has("weapon"):
		current_weapon = params["weapon"]
		_update_weapon_visibility()


func _update_weapon_visibility() -> void:
	# on cache toutes les armes
	$skin/Armature/Skeleton3D/BoneAttachment3D/bat.visible = false
	$skin/Armature/Skeleton3D/BoneAttachment3D/knife.visible = false
	# on affiche seulement l'arme active
	match current_weapon:
		"bat":
			$skin/Armature/Skeleton3D/BoneAttachment3D/bat.visible = true
		"knife":
			$skin/Armature/Skeleton3D/BoneAttachment3D/knife.visible = true
		"fists":
			pass  # pas d'arme visible
			


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
	


func range_attack_animation() -> void:
	if attack_animation == null:
		return
	stop_movement(1.5, 1.5)
	attack_animation.animation = simple_attacks['range']
	$AnimationTree.set("parameters/AttackOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func melee_attack_animation() -> void:
	if attack_animation == null:
		return
	# on choisit une animation aléatoire parmi celles de l'arme active
	var available = weapon_attacks.get(current_weapon, ["slice"])
	var random_key = available[rng.randi() % available.size()]
	attack_animation.animation = simple_attacks[random_key]
	$AnimationTree.set("parameters/AttackOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func can_damage(value: bool):
	$skin/Armature/Skeleton3D/BoneAttachment3D/hand_a.can_damage = value
