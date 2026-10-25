extends Enemy

@export var can_attack : bool = false
@onready var firemarker = $skin/Armature/Skeleton3D/BoneAttachment3D/ak_47/firemarker
const FIREBALL = preload("res://vfx/fireball.tscn")
# liste des groupes que le soldat considere comme ennemis


const simple_attacks = {
	'slice':"mixamo_com_007",
	'spin':"mixamo_com_007",
	'range':"mixamo_com_003",
}

func configure(params: Dictionary) -> void:
	super.configure(params)
	if params.has("can_attack"):
		can_attack = params["can_attack"]

func _ready() -> void:
	enemy_groups = ["zombie_a", "zombie_b" ,"mutan"]  # les groupes a cibler

func _physics_process(delta: float) -> void:
	# detection automatique des zombies dans le notice_radius
	_auto_detect_zombies()
	# le soldat ne bouge jamais vers sa cible
	# seule la fuite est permise si can_flee
	if can_flee:
		flee(delta)
	if can_move_to_target:
		move_to_target(delta)
	if can_chase_target:
		chase_target(delta)
	# attaque
	if can_attack:
		attack()



func _auto_detect_zombies() -> void:
	if target != null and is_instance_valid(target) and target is Enemy and not target.is_dead:
		return
	var nearest = null
	var min_dist = notice_raduis
	# on scanne tous les groupes ennemis
	for group in enemy_groups:
		var members = get_tree().get_nodes_in_group(group)
		for m in members:
			if not is_instance_valid(m) or not m is Enemy or m.is_dead:
				continue
			var dist = position.distance_to(m.position)
			if dist < min_dist:
				min_dist = dist
				nearest = m
	if nearest != null:
		target = nearest
		can_attack = true
		


func attack() -> void:
	# si pas de cible definie, on attend que _auto_detect_zombies en trouve une
	if target == null:
		return
	var attack_target = target
	# orientation vers la cible
	var target_dir = (attack_target.position - position).normalized()
	var target_vec2 = Vector2(target_dir.x, target_dir.z)
	rotation.y = -target_vec2.angle() + PI/2
	if can_attack and $Timers/AttackTimer.is_stopped():
		$Timers/AttackTimer.start()
	elif not can_attack and not $Timers/AttackTimer.is_stopped():
		$Timers/AttackTimer.stop()

func _on_attack_timer_timeout() -> void:
	if target == null:
		return
	var attack_target = target
	if not is_instance_valid(attack_target) or (attack_target is Enemy and attack_target.is_dead):
		target = null
		_find_nearest_group_member()
		return
	var dist = position.distance_to(attack_target.position)
	if dist < 1.5:
		melee_attack_animation()
	else:
		range_attack_animation()

func range_attack_animation() -> void:
	if attack_animation == null:
		return
	attack_animation.animation = simple_attacks['range']
	$AnimationTree.set("parameters/AttackOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func melee_attack_animation() -> void:
	if attack_animation == null:
		return
	attack_animation.animation = simple_attacks['slice' if rng.randi() %2 else 'spin']
	$AnimationTree.set("parameters/AttackOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _on_animation_started(anim_name: StringName) -> void:
	if anim_name == simple_attacks['range']:
		shoot_fireball()

func shoot_fireball() -> void:
	var fireball = FIREBALL.instantiate()
	get_tree().current_scene.add_child(fireball)
	fireball.global_position = firemarker.global_position
	fireball.direction = global_transform.basis.z

func can_damage(value: bool) -> void:
	$skin/Armature/Skeleton3D/BoneAttachment3D/rifle.can_damage = value
