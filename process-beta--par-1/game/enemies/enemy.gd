class_name Enemy
extends CharacterBody3D

@onready var move_state_machine = $AnimationTree.get("parameters/MoveStateMachine/playback")
@onready var player = get_tree().get_first_node_in_group('Player')
@onready var attack_animation = $AnimationTree.tree_root.get_node("AttackAnimation")
@onready var skin = get_node('skin')
@onready var health_bar = $HealthBarContainer/Sprite3D
@onready var health_bar_timer = $Timers/HealthBarTimer
@onready var nav_agent: NavigationAgent3D = get_node_or_null("NavAgent")
@onready var audio_damage = $AudioDamage

@export var walk_speed := 1.0
@export var chase_speed := 2.0
@export var notice_raduis := 10.0
@export var attack_raduis := 1.5
@export var can_move : bool=false 
@export var can_move_to_target : bool = false
@export var can_chase_target : bool = false 
@export var can_chase : bool = false
@export var can_flee : bool = false
@export var flee_radius := 5.0  # Rayon dans lequel il détecte qu'il doit fuir
@export var flee_speed := 3.0   # Vitesse de fuite (généralement plus rapide que la marche

@export var safe_radius := 10.0  # distance a partir de laquelle elle s'arrête de fuir

@export var max_health : int = 100
@export var remove_corpse : bool = false
var current_health : int = 0
var is_dead : bool = false
var target_group : String = ""
var enemy_groups : Array[String] = []

@export var npc_type: String = "worker"
var ai_state: String = "idle"

#parameters/DeadStateMachine/playback
var dead_state_machine : AnimationNodeStateMachinePlayback

var speed_modifier := 1.0
var rng= RandomNumberGenerator.new()
var target : Node3D = null
var target_position : Vector3 = Vector3.ZERO
var use_target_position : bool = false
var base_scale_x : float = 100.0

func _ready() -> void:
	add_to_group("enemies")
	base_scale_x = health_bar.scale.y  # on memorise la taille originale
	current_health = max_health
	dead_state_machine = $AnimationTree.get("parameters/DeadStateMachine/playback")
	# setup du timer de disparition
	health_bar_timer.timeout.connect(_on_health_bar_timer_timeout)
	# cache la barre au depart
	health_bar.visible = false
	


# Récupération de la gravité configurée dans les paramètres du projet Godot
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _physics_process(delta: float) -> void:
	# N'exécute pas la physique si l'ennemi est mort
	if is_dead:
		return
		
	# Application de la gravité à chaque frame de physique
	apply_gravity(delta)
	
	# ... Le reste de ta logique d'IA / état de déplacement ...


# ====== GESTION DE LA GRAVITÉ ======
func apply_gravity(delta: float) -> void:
	# Si le PNJ n'est pas au sol, on applique l'accélération de la gravité sur l'axe Y
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Optionnel : stabiliser la vitesse Y quand il touche le sol
		velocity.y = 0.0

func _update_health_bar() -> void:
	var ratio = clampf(float(current_health) / float(max_health), 0.0, 1.0)
	health_bar.visible = true
	health_bar.scale.y = base_scale_x * ratio
	health_bar_timer.start()

func _on_health_bar_timer_timeout() -> void:
	health_bar.visible = false

func configure(params: Dictionary) -> void:
	if params.has("enemy_groups"):
		enemy_groups = params["enemy_groups"]
	if params.has("target_group"):
		target_group = params["target_group"]
		call_deferred("_find_nearest_group_member")
	
	if params.has("max_health"):
		max_health = params["max_health"]
		current_health = max_health
	if params.has("remove_corpse"):
		remove_corpse = params["remove_corpse"]
	
	if params.has("flee_radius"):
		flee_radius = params["flee_radius"]
	if params.has("safe_radius"):
		safe_radius = params["safe_radius"]
	if params.has("target"):
		target = params["target"]
		use_target_position = false  # target noeud prend la priorite
	if params.has("target_position"):
		if target == null:  # on utilise target_position seulement si pas de target noeud
			target_position = params["target_position"]
			use_target_position = true
	if params.has("chase_speed"):
		chase_speed = params["chase_speed"]
	if params.has("walk_speed"):
		walk_speed = params["walk_speed"]
	if params.has("notice_raduis"):
		notice_raduis = params["notice_raduis"]
	if params.has("attack_raduis"):
		attack_raduis = params["attack_raduis"]
	if params.has("can_move"):
		can_move = params["can_move"]
	if params.has("can_move_to_target"):
		can_move_to_target = params["can_move_to_target"]
	if params.has("can_chase_target"):
		can_chase_target = params["can_chase_target"]
	if params.has("can_chase"):
		can_chase = params["can_chase"]
	if params.has("can_flee"):
		can_flee = params["can_flee"]
	if params.has("flee_radius"):
		flee_radius = params["flee_radius"]
	if params.has("flee_speed"):
		flee_speed = params["flee_speed"]

func _find_nearest_group_member() -> void:
	if target_group == "":
		return
	if not is_inside_tree():
		await tree_entered # Attend sagement que le nœud soit dans l'arbre au lieu de boucler
	
	#print("cherche membres du groupe: ", target_group)
	var members = get_tree().get_nodes_in_group(target_group)
	print("membres trouves: ", members.size())
	
	# Filtrer les membres morts ou invalides
	members = members.filter(func(m): return is_instance_valid(m) and not m.is_dead)
	if members.is_empty():
		target_group = ""
		target = null
		can_move = false
		can_chase = false
		set_physics_process(false)
		if move_state_machine:
			move_state_machine.travel('idle')
		return
		
	# Trouver le plus proche
	var nearest = members[0]
	var min_dist = position.distance_to(nearest.position)
	for member in members:
		var dist = position.distance_to(member.position)
		if dist < min_dist:
			min_dist = dist
			nearest = member
	target = nearest

func stop_movement(start_duration: float, end_duration: float):
	var tween = create_tween()
	tween.tween_property(self, "speed_modifier", 0.0, start_duration)
	tween.tween_property(self, "speed_modifier", 1.0, end_duration)


func _direction_vers(destination: Vector3) -> Vector3:
	var directe: Vector3 = destination - global_position
	directe.y = 0.0
 
	if nav_agent == null:
		return directe.normalized()
 
	nav_agent.target_position = destination
	var d: Vector3 = nav_agent.get_next_path_position() - global_position
	d.y = 0.0
 
	# Chemin terminé, introuvable, ou carte pas encore synchronisée :
	# on se replie sur la ligne droite plutôt que de rester planté.
	if d.length() < 0.1:
		return directe.normalized()
 
	return d.normalized()


#======SUIVRE LE JOUEUR EN MARCHANT======
func move_to_player(delta):
	if position.distance_to(player.position) < notice_raduis:
		var target_dir = _direction_vers(player.position)
		var target_vec2 = Vector2(target_dir.x , target_dir.z)
		var target_angle = -target_vec2.angle() + PI/2
		rotation.y = rotate_toward(rotation.y ,target_angle, delta *60)
		if position.distance_to(player.position) > attack_raduis:
			velocity = Vector3(target_vec2.x , 0, target_vec2.y) * walk_speed
			move_state_machine.travel('walk')
		else:
			velocity = Vector3.ZERO
			move_state_machine.travel('idle')
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		move_state_machine.travel('idle')


#*======= suvre le joeur en courant *******
func chase(delta):
	if position.distance_to(player.position) < notice_raduis:
		var target_dir = _direction_vers(player.position)
		var target_vec2 = Vector2(target_dir.x , target_dir.z)
		var target_angle = -target_vec2.angle() + PI/2
		rotation.y = rotate_toward(rotation.y ,target_angle, delta *60)
		if position.distance_to(player.position) > attack_raduis:
			velocity = Vector3(target_vec2.x , 0, target_vec2.y) * chase_speed
			move_state_machine.travel('walk2')
		else:
			velocity = Vector3.ZERO
			move_state_machine.travel('idle')
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		move_state_machine.travel('idle')

#*======= FUIR LE JOUEUR EN COURANT (NOUVEAU) *******
func flee(delta):
	# Si le joueur est à l'intérieur du rayon de fuite
	if position.distance_to(player.position) < flee_radius:
		# --- LA MAGIE EST ICI : (position - player.position) au lieu de (player.position - position) ---
		# Cela donne une direction mathématique qui pointe à l'opposé du joueur
		var refuge = global_position + (global_position - player.global_position).normalized() * safe_radius
		var target_dir = _direction_vers(refuge)

		var target_vec2 = Vector2(target_dir.x, target_dir.z)
		
		# On calcule le même angle pour que le corps pivote et regarde LA OÙ IL FUIT
		var target_angle = -target_vec2.angle() + PI/2
		rotation.y = rotate_toward(rotation.y, target_angle, delta * 60)
		
		# Déplacement à reculons/fuite à la vitesse 'flee_speed'
		velocity = Vector3(target_vec2.x, 0, target_vec2.y) * flee_speed
		
		# Tu peux utiliser 'walk2' (ta course) ou une autre animation si tu en as une
		move_state_machine.travel('walk2')
		
		move_and_slide()
	else:
		# Si le joueur est sorti du rayon de fuite, l'ennemi se calme et s'arrête
		velocity = Vector3.ZERO
		move_state_machine.travel('idle')
		

#======SUIVRE LA CIBLE EN MARCHANT======
func move_to_target(delta):
	var pos = target_position if use_target_position else (target.position if target != null else player.position)
	if position.distance_to(pos) < notice_raduis:
		var target_dir = _direction_vers(pos)
		var target_vec2 = Vector2(target_dir.x , target_dir.z)
		var target_angle = -target_vec2.angle() + PI/2
		rotation.y = rotate_toward(rotation.y ,target_angle, delta *60)
		if position.distance_to(pos) > attack_raduis:
			velocity = Vector3(target_vec2.x , 0, target_vec2.y) * walk_speed
			move_state_machine.travel('walk')
		else:
			velocity = Vector3.ZERO
			move_state_machine.travel('idle')
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		move_state_machine.travel('idle')

#*======= SUIVRE LA CIBLE EN COURANT *******
func chase_target(delta):
	var pos = target_position if use_target_position else (target.position if target != null else player.position)
	if position.distance_to(pos) < notice_raduis:
		var target_dir = _direction_vers(pos)
		var target_vec2 = Vector2(target_dir.x , target_dir.z)
		var target_angle = -target_vec2.angle() + PI/2
		rotation.y = rotate_toward(rotation.y ,target_angle, delta *60)
		if position.distance_to(pos) > attack_raduis:
			velocity = Vector3(target_vec2.x , 0, target_vec2.y) * chase_speed
			move_state_machine.travel('walk2')
		else:
			velocity = Vector3.ZERO
			move_state_machine.travel('idle')
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		move_state_machine.travel('idle')
		

func flee_target(delta: float) -> void:
	var attack_target = target if target != null else player
	if position.distance_to(attack_target.position) < safe_radius:
		var refuge = global_position + (global_position - attack_target.global_position).normalized() * safe_radius
		var target_dir = _direction_vers(refuge)
		var target_vec2 = Vector2(target_dir.x, target_dir.z)
		var target_angle = -target_vec2.angle() + PI/2
		rotation.y = rotate_toward(rotation.y, target_angle, delta * 60)
		velocity = Vector3(target_vec2.x, 0, target_vec2.y) * flee_speed
		move_state_machine.travel('walk2')
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		move_state_machine.travel('idle')

func hit(damage: int = 10) -> void:
	if is_dead:
		return
	if not $Timers/InvulTimer.time_left:
		current_health -= damage
		audio_damage.play()
		_update_health_bar()
		#print(name, " santé: ", current_health, "/", max_health)
		$AnimationTree.set("parameters/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		$Timers/InvulTimer.start()
		if current_health <= 0:
			die()

func die() -> void:
	is_dead = true
	set_physics_process(false)
	$CollisionShape3D.set_deferred("disabled", true)
	
	# 1. On FIRE le OneShot D'ABORD pour activer le nœud enfant
	$AnimationTree.set("parameters/DeadOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	# 2. Maintenant que le OneShot est actif, on va chercher le playback à chaud
	var dead_sm = $AnimationTree.get("parameters/DeadStateMachine/playback") as AnimationNodeStateMachinePlayback
	if dead_sm:
		dead_sm.travel("dying")
	
	# on notifie tous ceux qui nous ciblaient
	_notify_attackers()
	if remove_corpse:
		await get_tree().create_timer(5.0).timeout
		queue_free()

func _notify_attackers() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy and node.target == self:
			node.call_deferred("_find_nearest_group_member")

func hit_enemy() -> void:
	if not $Timers/InvulTimer.time_left:
		#sprint("enemy was hit")
		$AnimationTree.set("parameters/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		$Timers/InvulTimer.start()

@export var separation_radius : float = 3.0

func _separate(delta: float) -> void:
	var push = Vector3.ZERO
	for member in get_parent().get_children():
		if member == self or not member is Enemy:
			continue
		var dist = position.distance_to(member.position)
		if dist < separation_radius and dist > 0.01:
			push += (position - member.position).normalized() * (separation_radius - dist)
	if push != Vector3.ZERO:
		# on applique directement la separation sans toucher a velocity
		var saved_velocity = velocity
		velocity = Vector3(push.x * delta * 10.0, 0, push.z * delta * 10.0)
		move_and_slide()
		velocity = saved_velocity

func force_idle() -> void:
	move_state_machine.travel("idle")
	velocity = Vector3.ZERO

func _auto_detect_enemies() -> void:
	if target != null and is_instance_valid(target) and target is Enemy and not target.is_dead:
		return
	var nearest = null
	var min_dist = notice_raduis
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
