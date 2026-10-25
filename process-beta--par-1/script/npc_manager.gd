#extends Node

#@onready var spawner = $"../NPCSpawner"

#var worker_a : Enemy
#var worker_b : Enemy
#var worker_c : Enemy
#var soldier_a: Enemy
#var soldier_b: Enemy
#var tachikoma: Enemy
#var woman_a:Enemy
#var marie :Enemy
#var aure: Enemy
#var rosales: Enemy
#var arissa: Enemy
#var bryce_a: Enemy
#var david_a: Enemy
#var lewis_a: Enemy
#var zombie_group_1 : Array = []
#var zombie_group_2 : Array = []
#var mutan_group_1 : Array = []


#func _ready() -> void:
#     await get_tree().process_frame
#     woman_a = spawner.spawn_npc("woman", Vector3(19, 0, 8), {
#         "walk_speed": 0.5,
#         "notice_raduis": 15.0,
#         "can_flee" : false ,
#         "can_chase": false,
#         "can_attack":false,
#         "can_move":false,
#         'can_move_to_target':true,
#         "target_position": Vector3(10, 0, 3)
#     })
#     
#     worker_b = spawner.spawn_npc("worker", Vector3(6, 0, 6), {
#         "walk_speed": 0.75,
#         "notice_raduis": 13.0,
#         "can_move": false,
#         "can_attack":false,
#         "can_flee":true,
#     })
#     
#      
#     zombie_group_1 = await spawner.spawn_group("zombie_a", "zombie_group_1", Vector3(10, 0, 5), {
#     "number": 5,
#     "can_move": false,
#     "can_chase": false,
#     "notice_raduis": 12.0
#     })
#     
#     mutan_group_1 = await spawner.spawn_group("mutan", "mutan_group_1", Vector3(10, 0, 5), {
#     "number": 1,
#     "can_move": false,
#     "can_chase": false,
#     "notice_raduis": 12.0
#     })
#     
#     zombie_group_2 = await spawner.spawn_group("zombie_b", "zombie_group_2", Vector3(20, 0, 10), {
#     "number": 3,
#     "can_move": false,
#     "can_chase": false,
#     "notice_raduis": 12.0
#     })
#     
#     arissa = spawner.spawn_npc("arissa", Vector3(15, 0, 8), {
#         "walk_speed": 0.5,
#         "notice_raduis": 15.0,
#         "can_chase": false,
#         "can_attack": true,
#         "can_flee":false,
#         "can_move": false,
#         #"target": worker_b,
#         'can_move_to_target':true,
#         #"target_position": Vector310, 0, 3)
#         
#         
#     }) 
#     
#     aure = spawner.spawn_npc("aure", Vector3(13, 0, 7), {
#         "walk_speed": 0.75,
#         "notice_raduis": 13.0,
#         "can_move": false,
#         "can_chase":false ,
#         "can_attack":false,
#         #"target": worker_c,
#         #"can_move_to_target":true,
#     })
#     
#     marie = spawner.spawn_npc("marie", Vector3(19, 0, -3), {
#         "walk_speed": 0.75,
#         "notice_raduis": 13.0,
#         "can_move": false,
#         "can_chase":false ,
#         "can_attack":true,
#         "target": woman_a,
#         "can_move_to_target":true,
#     })
#     
#     rosales = spawner.spawn_npc("rosales", Vector3(22, 0, 6), {
#         "walk_speed": 0.75,
#         "notice_raduis": 13.0,
#         "can_move": true,
#         "can_chase":false ,
#         "can_attack":true,
#         #"target": woman_a,
#         #"can_move_to_target":true,
#     })
#     
#     
#     soldier_a = spawner.spawn_npc("soldier", Vector3(20, 0, 4), {
#         "walk_speed": 0.5,
#         "notice_raduis": 15.0,
#         "can_chase": false,
#         "can_attack":true,
#         "can_flee":false,
#         #"can_move": true,
#         #"target_group": "zombie_group_1",
#         #"target": worker_b,
#         #'can_move_to_target':true,
#         #"target_position": Vector310, 0, 3)
#         
#         
#     })
#     
#     tachikoma = spawner.spawn_npc("tachikoma", Vector3(20, 0, 4), {
#         "walk_speed": 0.5,
#         "notice_raduis": 15.0,
#         "can_chase": false,
#         "can_attack":true,
#         "can_flee":false,
#         "can_move": false,
#         #"target_group": "zombie_group_1",
#         #"target": worker_b,
#         'can_move_to_target':true,
#         #"target_position": Vector310, 0, 3)
#         
#         
#     })
#     
#     worker_a = spawner.spawn_npc("worker", Vector3(15, 0, 3), {
#         "walk_speed": 3.5,
#         "notice_raduis": 15.0,
#         "can_flee" : false,
#         "can_chase": false,
#         "can_attack":true,
#         "target": worker_b,
#         "can_move_to_target":true,
#         
#         
#     })
#     
#     
#     bryce_a = spawner.spawn_npc("bryce", Vector3(17, 0, 9), {
#         "walk_speed": 3.5,
#         "notice_raduis": 15.0,
#         "can_flee" : false,
#         "can_chase": false,
#         "can_attack":true,
#         "weapon": "knife",
#         #"target": worker_b,
#         #"can_move_to_target":true,
#         
#         
#     })
#     
#     david_a = spawner.spawn_npc("david", Vector3(19, 0, 9), {
#         "walk_speed": 3.5,
#         "notice_raduis": 15.0,
#         "can_flee" : false,
#         "can_chase": false,
#         "can_attack":true,
#         "weapon": "knife",
#         #"target": worker_b,
#         #"can_move_to_target":true,
#         
#         
#     })
#     
#     lewis_a = spawner.spawn_npc("lewis", Vector3(26, 0, 9), {
#         "walk_speed": 3.5,
#         "notice_raduis": 15.0,
#         "can_flee" : false,
#         "can_chase": false,
#         "can_attack":true,
#         "weapon": "knife",
#         #"target": worker_b,
#         #"can_move_to_target":true,
#         
#         
#     })
#     
#     
#     
#     worker_c = spawner.spawn_npc("worker", Vector3(7, 0, 7), {
#         "walk_speed": 0.75,
#         "notice_raduis": 13.0,
#         "can_flee": false,
#         "can_attack":false,
#     })
extends Node

@onready var spawner = $"../NPCSpawner"

# ============================================================
# ECLIPSE — Défense de la base solaire
# ============================================================
# Repères de la géométrie produite par GeometryFactory :
#   Place centrale ..... origine, dallage de -12 à +12
#   Bloc résidentiel ... centre (-32, 0, 0) ; logements en x = -46, -39, -32,
#                        -25, -18 et z = ±5 ; couloir en z = 0 ; toit à y = 3.5
#   Centre technique ... halle de x = 17 à 43 ; grande porte en (17, 0, 0)
#   Atelier ............ x de -8 à 8, z de -31 à -21
#   Clôture ............ x = ±62, z = ±44 ; portails en (0, 0, ±44)
#   Miradors ........... (±58, ±40), plateforme à y = 7.22
#
# ------------------------------------------------------------
# RÈGLE DE PERFORMANCE
# ------------------------------------------------------------
# Un corps immobile ne coûte quasiment rien. Un corps qui appelle
# move_and_slide() doit être confronté à tous les collideurs de la forêt, à
# chaque frame. On limite donc volontairement le nombre de PNJ MOBILES :
#
#   mobiles ....... 2 tachikomas, 2 aventuriers, 2 civils      = 6
#   immobiles ..... soldats, zombies, tireurs, autres civils   = 26
#
# Les zombies restent figés comme dans ta version : ils tiennent le terrain
# devant le portail nord et frappent ce qui entre dans leur rayon.
# ------------------------------------------------------------
# FACTIONS
# ------------------------------------------------------------
# On n'utilise pas les group_id du spawner comme groupes ennemis : rien ne
# garantit qu'ils correspondent à de vrais groupes Godot. Le manager inscrit
# lui-même chaque PNJ dans l'une des deux factions, à la fin, une fois tout le
# monde entré dans l'arbre.
# ============================================================

const F_HORDE := "faction_horde"
const F_BASE := "faction_base"

# enemy.gd déclare `enemy_groups: Array[String]` : un tableau littéral non typé
# est refusé à l'exécution, d'où ces deux déclarations.
var vise_la_base : Array[String] = [F_BASE]
var vise_la_horde : Array[String] = [F_HORDE]

var worker_a : Enemy
var worker_b : Enemy
var worker_c : Enemy
var woman_a : Enemy
var woman_b : Enemy
var soldier_a : Enemy
var soldier_b : Enemy
var soldier_c : Enemy
var soldier_d : Enemy
var soldier_e : Enemy
var soldier_f : Enemy
var soldier_g : Enemy
var soldier_h : Enemy
var tachikoma_a : Enemy
var tachikoma_b : Enemy
var marie : Enemy
var aure : Enemy
var rosales : Enemy
var arissa : Enemy
var bryce_a : Enemy
var david_a : Enemy
var lewis_a : Enemy
var zombie_group_1 : Array = []
var zombie_group_2 : Array = []
var mutan_group_1 : Array = []


func _ready() -> void:
	await get_tree().process_frame

	# ========================================================
	# LA HORDE — invoquée EN PREMIER
	# ========================================================
	# Impératif : _find_nearest_group_member() s'exécute au spawn et désactive
	# définitivement le PNJ si le groupe visé est encore vide. Tout ce qui
	# utilise target_group doit donc naître APRÈS sa cible.
	#
	# Réglages inchangés par rapport à ta version. Seuls s'ajoutent can_attack
	# et enemy_groups : figés sur place, ils frappent ce qui entre dans leurs
	# 12 mètres. Ils sont massés devant le portail nord (0, 0, -44).

	

	# ========================================================
	# ENRÔLEMENT DANS LES FACTIONS
	# ========================================================
	# On attend une frame : le spawner ajoute les instances en différé, elles
	# ne sont donc pas encore dans l'arbre au retour de la fonction.

	await get_tree().process_frame

	_enroler(zombie_group_1, F_HORDE)
	_enroler(zombie_group_2, F_HORDE)
	_enroler(mutan_group_1, F_HORDE)

	_enroler([
		soldier_a, soldier_b, soldier_c, soldier_d,
		soldier_e, soldier_f, soldier_g, soldier_h,
		tachikoma_a, tachikoma_b,
		marie, aure, rosales, arissa,
		bryce_a, david_a, lewis_a,
		woman_a, woman_b, worker_a, worker_b, worker_c,
	], F_BASE)


# Inscrit une liste de PNJ dans un groupe Godot.
func _enroler(liste: Array, groupe: String) -> void:
	for n in liste:
		if n != null and is_instance_valid(n) and not n.is_in_group(groupe):
			n.add_to_group(groupe)
