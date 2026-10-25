extends Node

# ============================================================
# ECLIPSE — Diagnostic de navigation
# ============================================================
# Crée un Node vide dans ta scène de niveau, attache-lui ce script, lance,
# et attends trois secondes. Tout s'affiche dans la console.
# À supprimer une fois le problème réglé.
# ============================================================

func _ready() -> void:
	# on laisse le temps au bake, qui tourne sur un thread
	await get_tree().create_timer(3.0).timeout

	print("")
	print("========== DIAGNOSTIC NAVIGATION ==========")

	# --- 1. la région existe-t-elle ? ---
	var region = get_tree().current_scene.find_child("NavRegion", true, false)
	print("1. Nœud 'NavRegion' trouvé ......... ", region != null)
	if region == null:
		print("   >> Aucun nœud nommé exactement 'NavRegion'.")
		print("   >> C'est le nom que cherche geometry_factory.gd.")
		print("===========================================")
		return
	print("   type NavigationRegion3D ......... ", region is NavigationRegion3D)
	if not (region is NavigationRegion3D):
		print("   >> Le nœud existe mais n'est pas une NavigationRegion3D.")
		print("===========================================")
		return
	print("   région activée .................. ", region.enabled)

	# --- 2. la ressource et son bake ---
	var nm = region.navigation_mesh
	print("2. NavigationMesh assigné .......... ", nm != null)
	if nm == null:
		print("   >> Propriété 'Navigation Mesh' vide dans l'inspecteur.")
		print("   >> Clique sur <vide> puis 'Nouveau NavigationMesh'.")
		print("===========================================")
		return

	print("   POLYGONES BAKÉS ................. ", nm.get_polygon_count())
	print("   sommets ......................... ", nm.get_vertices().size())
	print("   source group name ............... '", nm.geometry_source_group_name, "'")
	print("   parsed geometry type ............ ", nm.geometry_parsed_geometry_type,
		"   (0=maillages, 1=collideurs, 2=les deux)")
	print("   source geometry mode ............ ", nm.geometry_source_geometry_mode,
		"   (0=enfants racine, 1=groupe seul, 2=groupe+enfants)")
	print("   agent radius / height ........... ", nm.agent_radius, " / ", nm.agent_height)
	print("   cell size ....................... ", nm.cell_size,
		"   (projet : ", ProjectSettings.get_setting("navigation/3d/default_cell_size"), ")")

	# --- 3. qui alimente le bake ---
	var sources = get_tree().get_nodes_in_group("navmesh_source")
	print("3. Nœuds dans 'navmesh_source' ..... ", sources.size())
	for n in sources:
		print("   - ", n.name, "  (", n.get_class(), ", ", n.get_child_count(), " enfants)")
	if sources.size() <= 1:
		print("   >> Seule la géométrie générée est inscrite.")
		print("   >> AJOUTE TON TERRAIN à ce groupe, sinon le sol n'existe pas")
		print("      pour la navigation et aucun chemin ne peut être calculé.")

	# --- 4. l'agent côté PNJ ---
	var e = get_tree().get_first_node_in_group("enemies")
	if e == null:
		print("4. Aucun PNJ dans le groupe 'enemies'.")
	else:
		print("4. PNJ témoin ...................... ", e.name)
		print("   nœud 'NavAgent' présent ......... ", e.get_node_or_null("NavAgent") != null)

	# --- 5. LE TEST QUI TRANCHE ---
	# Un chemin de plus de 2 points prouve que le navmesh est exploitable.
	var map = get_viewport().world_3d.navigation_map
	print("5. Régions sur la carte ............. ", NavigationServer3D.map_get_regions(map).size())

	var essais = [
		["place -> quartier résidentiel", Vector3(0, 0, 0), Vector3(-32, 0, 0)],
		["place -> centre technique", Vector3(0, 0, 0), Vector3(30, 0, 4)],
		["place -> devant le portail nord", Vector3(0, 0, 0), Vector3(0, 0, -40)],
		["intérieur -> extérieur (par le portail)", Vector3(0, 0, -30), Vector3(0, 0, -50)],
	]
	for essai in essais:
		var chemin = NavigationServer3D.map_get_path(map, essai[1], essai[2], true)
		var verdict = "OK" if chemin.size() >= 2 else "AUCUN CHEMIN"
		print("   %-42s %2d points   %s" % [essai[0], chemin.size(), verdict])

	print("===========================================")
	print("Lecture :")
	print(" - polygones bakés = 0  -> le bake n'a rien trouvé (groupe ou type)")
	print(" - 'AUCUN CHEMIN' partout -> navmesh vide ou terrain absent du groupe")
	print(" - chemins OK mais PNJ dans les murs -> le NavAgent manque dans enemy.tscn")
	print("===========================================")
	print("")
