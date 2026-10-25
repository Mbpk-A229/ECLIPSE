extends Enemy

@export var can_attack : bool = false

# Cadence de la recherche de proie. Chercher a chaque frame coute cher pour
# rien : un zombie n'a pas besoin de reevaluer sa cible 60 fois par seconde.
const DELAI_DETECTION := 0.4
var _temps_detection : float = 0.0

#randomisate la func attack
const simple_attacks = {
	'slice':"mixamo_com_027",
	'spin':"mixamo_com_026",
	'range':"mixamo_com_027",
}


func configure(params: Dictionary) -> void:
	super.configure(params)  # appelle d'abord configure() de Enemy
	if params.has("can_attack"):
		can_attack = params["can_attack"]


func _ready() -> void:
	super._ready()
	add_to_group("zombie_a")


func _physics_process(delta: float) -> void:
	# On cherche une proie AVANT de decider du deplacement, pour que la cible
	# soit a jour dans la meme frame.
	_chercher_une_proie(delta)

	# Deplacement vers la CIBLE et non vers le joueur.
	# move_to_target et chase_target retombent automatiquement sur le joueur
	# quand target est nul : le comportement d'origine est donc preserve
	# lorsqu'aucun PNJ n'est a portee, et les parametres du manager
	# (can_move, can_chase) gardent exactement le meme sens.
	if can_move:
		move_to_target(delta)
	if can_chase:
		chase_target(delta)

	#attaquer la cible
	if can_attack:
		attack()

	#fuir le joeur
	if can_flee:
		flee(delta)

	#ordres explicites venus du backend IA
	if can_move_to_target:
		move_to_target(delta)
	if can_chase_target:
		chase_target(delta)

	_separate(delta)


# ============================================================
# DETECTION AUTONOME
# ============================================================
# C'est ce qui manquait : sans cet appel, `target` restait nul et le zombie
# se rabattait toujours sur le joueur.
#
# Contrairement a `target_group`, qui est resolu UNE SEULE FOIS au spawn et
# impose donc d'invoquer la cible en premier, `enemy_groups` est relu a chaque
# appel. L'ordre d'invocation dans le manager n'a plus aucune importance.
func _chercher_une_proie(delta: float) -> void:
	if enemy_groups.is_empty():
		return

	_temps_detection -= delta
	if _temps_detection > 0.0:
		return
	_temps_detection = DELAI_DETECTION

	# On lache une cible morte, detruite, ou sortie du rayon de detection.
	# Sans ca, `_auto_detect_enemies()` sort immediatement des qu'une cible est
	# valide, et le zombie reste accroche a un PNJ qu'il ne rattrapera jamais
	# pendant qu'un autre lui passe sous le nez.
	if target != null:
		var perdue: bool = not is_instance_valid(target)
		if not perdue and target is Enemy and target.is_dead:
			perdue = true
		if not perdue and position.distance_to(target.position) > notice_raduis * 1.5:
			perdue = true
		if perdue:
			target = null

	_auto_detect_enemies()


# ============================================================
# COMBAT
# ============================================================

func attack() -> void:
	var attack_target = target if (target != null and is_instance_valid(target)) else player
	if attack_target == null:
		return

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
	var attack_target = target if (target != null and is_instance_valid(target)) else player
	if attack_target == null:
		return

	var d: float = position.distance_to(attack_target.position)

	# Hors de portee : on ne joue aucune animation. Sans ce garde-fou, le zombie
	# lancait son attaque a distance sur le joueur meme a cinquante metres.
	if d > notice_raduis:
		return

	if d < 1.5:
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
	$skin/Armature/Skeleton3D/BoneAttachment3D/m_hand.can_damage = value

func can_damage_t(value: bool):
	$skin/Armature/Skeleton3D/BoneAttachment3D2/m_leg.can_damage_t = value
