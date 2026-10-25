extends Node
# table de correspondance type -> scène
# À compléter au fur et à mesure des assets .glb intégrés
var env_scenes: Dictionary = {
	# --- Arbres ---
	#"tree_pine": preload("res://game/environment/trees/tree_pine.tscn"),
	"tree_pine_a": preload("res://game/environnement/tree_pine_a.tscn"),
	"tree_pine_b": preload("res://game/environnement/tree_pine_b.tscn"),
	"tree_pine_c": preload("res://game/environnement/tree_pine_c.tscn"),
	#"tree_oak": preload("res://game/environment/trees/tree_oak.tscn"),
	#==herbes==
	"grass": preload("res://game/environnement/grass.tscn"),
	# --- Rochers ---
	"rock_a": preload("res://game/environnement/multirock.tscn"),
	# --- Falaises ---
	#"cliff_a": preload("res://game/environment/cliffs/cliff_a.tscn"),
}
# ===============================
# PLACEMENT PRÉCIS (un seul élément, position donnée)
# ===============================
func spawn_element(type: String, spawn_position: Vector3, params: Dictionary = {}) -> Node:
	if not env_scenes.has(type):
		push_error("Type d'élément d'environnement inconnu : " + type)
		return null
	var instance = env_scenes[type].instantiate()
	get_tree().current_scene.add_child.call_deferred(instance)
	instance.set_deferred("global_position", spawn_position)
	if instance.has_method("configure"):
		instance.call_deferred("configure", params)
	return instance
# ===============================
# DISPERSION ALÉATOIRE (fond de décor)
# ===============================
# area_center : centre de la zone
# area_size : côté de la zone carrée
# count : nombre d'éléments à placer
# min_distance : distance minimale entre deux éléments
# exclusion_zones : zones à éviter, ex: [{"center": Vector3(10,0,5), "radius": 6.0}, ...]
func spawn_scatter(type: String, area_center: Vector3, area_size: float, count: int, min_distance: float = 4.0, params: Dictionary = {}, exclusion_zones: Array = []) -> Array:
	if not env_scenes.has(type):
		push_error("Type d'élément d'environnement inconnu : " + type)
		return []
	var placed_positions: Array[Vector3] = []
	var instances := []
	var i := 0
	var safety := 0
	var max_safety := count * 20
	while i < count and safety < max_safety:
		safety += 1
		var x = randf_range(-area_size * 0.5, area_size * 0.5)
		var z = randf_range(-area_size * 0.5, area_size * 0.5)
		var pos = area_center + Vector3(x, 0, z)
		var valid := true
		for p in placed_positions:
			if p.distance_to(pos) < min_distance:
				valid = false
				break
		if valid:
			for zone in exclusion_zones:
				var zone_center: Vector3 = zone.get("center", Vector3.ZERO)
				var zone_radius: float = zone.get("radius", 0.0)
				if pos.distance_to(zone_center) < zone_radius:
					valid = false
					break
		if not valid:
			continue
		placed_positions.append(pos)
		var inst = spawn_element(type, pos, params)
		if inst:
			instances.append(inst)
		i += 1
	if safety >= max_safety:
		push_warning("spawn_scatter (%s) : densité trop élevée pour la zone, seulement %d/%d placés" % [type, instances.size(), count])
	return instances
# ===============================
# NETTOYAGE
# ===============================
func clear_all() -> void:
	# À utiliser si on veut regénérer entièrement une zone
	for child in get_tree().current_scene.get_children():
		if child is EnvironmentElement:
			child.queue_free()
