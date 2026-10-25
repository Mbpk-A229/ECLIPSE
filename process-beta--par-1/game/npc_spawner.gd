extends Node

# table de correspondance type -> scene

var npc_scenes : Dictionary = {
	#invocation de 'ouvrier
	"worker": preload("res://game/enemies/worker.tscn"),
	# invocation du soldat 
	"soldier": preload("res://game/enemies/soldier.tscn"),
	#invoquer la woman
	"woman": preload("res://game/enemies/woman.tscn"),
	#invoquer marie(avanturiere)
	"marie": preload("res://game/enemies/marie.tscn"),
	#invoquer monsieur Aure(avanturier=)
	"aure": preload("res://game/enemies/aure.tscn"),
	#invoquer rosales (avanturiere)
	"rosales": preload("res://game/enemies/rosales.tscn"),
	#invoquer arissa(l'archere)
	"arissa": preload("res://game/enemies/arissa.tscn"),
	#invoquer bryce avec ses tatouages il a tout pour etre un délinquant
	"bryce":preload("res://game/enemies/bryce.tscn"),#invoquer david
	#invoquer david
	"david":preload("res://game/enemies/david.tscn"),
	#invoquer lewis
	"lewis":preload("res://game/enemies/lewis.tscn"),
	#invoquer une femme zombie
	"zombie_a":preload("res://game/enemies/zombie_a.tscn"),
	"zombie_b":preload("res://game/enemies/zombie_b.tscn"),
	#invoquer un mutan
	"mutan":preload("res://game/enemies/mutan.tscn"),
	#invoquer le robot arreingné de combat 
	"tachikoma":preload("res://game/enemies/tachikoma.tscn"),
	
	
	
}



func spawn_npc(type: String, spawn_position: Vector3, params: Dictionary = {}) -> Node:
	if not npc_scenes.has(type):
		push_error("Type de PNJ inconnu : " + type)
		return null
	var instance = npc_scenes[type].instantiate()
	if instance.has_method("configure"):
		instance.configure(params)
	get_tree().current_scene.add_child.call_deferred(instance)
	instance.set_deferred("global_position", spawn_position)
	return instance

var groups : Dictionary = {}

func spawn_group(type: String, group_id: String, spawn_center: Vector3, params: Dictionary = {}) -> Array:
	var number = params.get("number", 3)
	number = min(number, 10)
	var members = []
	var params_without_number = params.duplicate()
	params_without_number.erase("number")
	
	for i in range(number):
		var angle = (2 * PI * i) / number
		var radius = 1.5 + (number * 0.2)
		var offset = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var spawn_pos = spawn_center + offset
		var member = spawn_npc(type, spawn_pos, params_without_number)
		if member:
			member.set_meta("group_id", group_id)
			member.set_meta("member_index", i)
			members.append(member)
	
	# on attend deux frames que tous les membres soient dans la scene
	await get_tree().process_frame
	await get_tree().process_frame
	for member in members:
		if is_instance_valid(member):
			member.add_to_group(group_id)
			print("zombie ajouté au groupe: ", group_id, " groupes: ", member.get_groups())
	
	groups[group_id] = members
	return members

func configure_group(group_id: String, params: Dictionary) -> void:
	if not groups.has(group_id):
		push_error("Groupe inconnu : " + group_id)
		return
	for member in groups[group_id]:
		if is_instance_valid(member):
			member.configure(params)

func configure_group_member(group_id: String, member_index: int, params: Dictionary) -> void:
	if not groups.has(group_id):
		push_error("Groupe inconnu : " + group_id)
		return
	var members = groups[group_id]
	if member_index < members.size() and is_instance_valid(members[member_index]):
		members[member_index].configure(params)

func remove_group(group_id: String) -> void:
	if not groups.has(group_id):
		return
	for member in groups[group_id]:
		if is_instance_valid(member):
			member.queue_free()
	groups.erase(group_id)
func _ready() -> void:
	AIBridge.register_spawner(self)
	# ... le reste du _ready() existant du spawner, s'il y en a
