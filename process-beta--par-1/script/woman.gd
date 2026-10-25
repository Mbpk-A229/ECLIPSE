extends Enemy


@export var can_attack : bool= false


#randomisate la func attack
const simple_attacks = {
	'slice':"mixamo_com_005",
	'spin':"mixamo_com_001",
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
	#if can_attack:
		#attack()
	#fuir le joeur
	if can_flee:
		flee(delta)
	#suvre une cible en marchannt ou en courant 
	if can_move_to_target:
		move_to_target(delta)
	if can_chase_target:
		chase_target(delta)
		
	
