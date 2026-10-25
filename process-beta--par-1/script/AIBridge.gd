extends Node

# ECLIPSE — AIBridge.gd
# Boucle automatique + exécution de décisions multiples par cycle (garnison
# initiale et vagues de zombies via spawn_group).

var waves_sent: int = 0
const ADVENTURER_TYPES = ["marie", "aure", "arissa", "rosales", "bryce"]

@onready var http_request: HTTPRequest = HTTPRequest.new()
@onready var decision_timer: Timer = Timer.new()

const BACKEND_URL = "http://localhost:3000/ai/decision"
const DECISION_INTERVAL_SECONDS: float = 10.0

var is_requesting: bool = false
var npc_spawner: Node = null
var npc_registry: Dictionary = {}  # npc_id (String) -> Node réel

func _ready() -> void:
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

	add_child(decision_timer)
	decision_timer.wait_time = DECISION_INTERVAL_SECONDS
	decision_timer.timeout.connect(request_decision)
	decision_timer.start()

func register_spawner(spawner_node: Node) -> void:
	npc_spawner = spawner_node
	print("AIBridge: NPCSpawner enregistré")

# --- Comptage du statut du siège ---

func _count_siege_status() -> Dictionary:
	var soldiers_alive := 0
	var adventurers_alive := 0
	var civilians_alive := 0
	var zombies_alive := 0

	for npc in _all_known_npcs():
		var type = npc.npc_type if "npc_type" in npc else "unknown"
		if type == "zombie_a" or type == "zombie_b" or type == "mutan":
			zombies_alive += 1
		elif type == "worker" or type == "woman":
			civilians_alive += 1
		elif type in ADVENTURER_TYPES:
			adventurers_alive += 1
		else:
			soldiers_alive += 1

	return {
		"soldiers_alive": soldiers_alive,
		"adventurers_alive": adventurers_alive,
		"civilians_alive": civilians_alive,
		"zombies_alive": zombies_alive,
		"waves_sent": waves_sent,
	}
# Fusionne le groupe Godot "enemies" (PNJ placés à la main, ex: Worker) avec
# notre registre interne (tout ce que l'IA a spawné) — sans doublon.
func _all_known_npcs() -> Array:
	var seen := {}
	for npc in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(npc):
			continue
		if "is_dead" in npc and npc.is_dead:
			continue
		seen[npc.get_instance_id()] = npc
	for npc in npc_registry.values():
		if not is_instance_valid(npc):
			continue
		if "is_dead" in npc and npc.is_dead:
			continue
		seen[npc.get_instance_id()] = npc
	return seen.values()
# --- Construction et envoi du GameState ---

const HOSTILE_TYPES = ["zombie_a", "zombie_b", "mutan"]

func _enroll_faction(npc_node: Node, npc_type: String) -> void:
	if npc_type in HOSTILE_TYPES:
		npc_node.add_to_group("F_HORDE")
	else:
		npc_node.add_to_group("F_BASE")

func request_decision() -> void:
	if is_requesting:
		print("AIBridge: requête déjà en cours, on ignore ce cycle")
		return

	var player_node = get_tree().get_first_node_in_group("Player")
	if player_node == null:
		push_error("AIBridge: aucun nœud dans le groupe 'Player'")
		return

	var player_data = {
		"id": "player",
		"position": [player_node.global_position.x, player_node.global_position.y, player_node.global_position.z],
		"health": player_node.health
	}

	var npcs_data: Array = []
	for npc in _all_known_npcs():
		npcs_data.append({
			"id": npc.name,
			"type": npc.npc_type if "npc_type" in npc else "unknown",
			"position": [npc.global_position.x, npc.global_position.y, npc.global_position.z],
			"state": npc.ai_state if "ai_state" in npc else "idle"
		})

	var game_state = {
		"player": player_data,
		"npcs": npcs_data,
		"world": {"time": "night", "weather": "clear"},
		"siege": _count_siege_status(),
		"events": []
	}

	var json_body = JSON.stringify(game_state)
	var headers = ["Content-Type: application/json"]

	var error = http_request.request(BACKEND_URL, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		push_error("AIBridge: échec de l'envoi de la requête HTTP")
		return

	is_requesting = true

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	is_requesting = false

	if response_code != 200:
		push_error("AIBridge: réponse backend inattendue — code %d" % response_code)
		return

	var json_string = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("AIBridge: JSON invalide reçu du backend")
		return

	var payload: Dictionary = json.data
	var decisions: Array = payload.get("decisions", [])

	for decision in decisions:
		print("Décision reçue: ", decision)
		await execute_decision(decision)

# --- Exécution des décisions ---

func execute_decision(decision: Dictionary) -> void:
	if npc_spawner == null:
		push_error("AIBridge: npc_spawner non enregistré, impossible d'exécuter")
		return

	var action = decision.get("action", "no_action")

	match action:
		"spawn":
			_execute_spawn(decision)
		"spawn_group":
			await _execute_spawn_group(decision)
		"configure":
			_execute_configure(decision)
		"despawn":
			_execute_despawn(decision)
		"no_action":
			pass
		_:
			push_error("AIBridge: action inconnue reçue du backend: '%s'" % action)

func _execute_spawn(decision: Dictionary) -> void:
	var npc_type: String = decision.get("type", "")
	var npc_id: String = decision.get("npc_id", "")
	var pos_array: Array = decision.get("position", [0, 0, 0])
	var params: Dictionary = decision.get("params", {})
	

	if npc_id == "" or npc_type == "":
		push_error("AIBridge: spawn rejeté — type ou npc_id manquant")
		return
	if npc_registry.has(npc_id):
		push_error("AIBridge: spawn rejeté — npc_id '%s' déjà utilisé" % npc_id)
		return

	var position = Vector3(pos_array[0], pos_array[1], pos_array[2])
	var npc_node = npc_spawner.spawn_npc(npc_type, position, _sanitize_params(params))

	if npc_node == null:
		push_error("AIBridge: spawn_npc a échoué pour le type '%s'" % npc_type)
		return

	npc_node.name = npc_id
	if "npc_type" in npc_node:
		npc_node.npc_type = npc_type
	_enroll_faction(npc_node, npc_type)
	npc_registry[npc_id] = npc_node
	print("AIBridge: PNJ '%s' (%s) spawné à %s" % [npc_id, npc_type, position])

func _execute_spawn_group(decision: Dictionary) -> void:
	var npc_type: String = decision.get("type", "")
	var group_id: String = decision.get("group_id", "")
	var pos_array: Array = decision.get("position", [0, 0, 0])
	var params: Dictionary = decision.get("params", {})

	if npc_type == "" or group_id == "":
		push_error("AIBridge: spawn_group rejeté — type ou group_id manquant")
		return

	var position = Vector3(pos_array[0], pos_array[1], pos_array[2])
	var members: Array = await npc_spawner.spawn_group(npc_type, group_id, position, _sanitize_params(params))

	for i in range(members.size()):
		if not is_instance_valid(members[i]):
			continue
		var member_id = "%s_%d" % [group_id, i]
		members[i].name = member_id
		if "npc_type" in members[i]:
			members[i].npc_type = npc_type
		_enroll_faction(members[i], npc_type)
		npc_registry[member_id] = members[i]

	print("AIBridge: groupe '%s' (%s x%d) spawné à %s" % [group_id, npc_type, members.size(), position])

func _execute_configure(decision: Dictionary) -> void:
	var npc_id: String = decision.get("npc_id", "")
	var raw_params: Dictionary = decision.get("params", {})

	if not npc_registry.has(npc_id):
		push_error("AIBridge: configure rejeté — npc_id '%s' inconnu" % npc_id)
		return

	var npc_node = npc_registry[npc_id]
	if not is_instance_valid(npc_node):
		push_error("AIBridge: PNJ '%s' n'existe plus" % npc_id)
		npc_registry.erase(npc_id)
		return

	var resolved_params = raw_params.duplicate()
	if resolved_params.has("target"):
		var target_id = resolved_params["target"]
		if target_id == "player":
			resolved_params["target"] = get_tree().get_first_node_in_group("Player")
		elif npc_registry.has(target_id):
			resolved_params["target"] = npc_registry[target_id]
		else:
			push_error("AIBridge: target '%s' introuvable — ignoré" % str(target_id))
			resolved_params.erase("target")

	npc_node.configure(_sanitize_params(resolved_params))
	print("AIBridge: PNJ '%s' configuré avec %s" % [npc_id, resolved_params])

func _execute_despawn(decision: Dictionary) -> void:
	var npc_id: String = decision.get("npc_id", "")

	if not npc_registry.has(npc_id):
		push_error("AIBridge: despawn rejeté — npc_id '%s' inconnu" % npc_id)
		return

	var npc_node = npc_registry[npc_id]
	if is_instance_valid(npc_node):
		npc_node.queue_free()
	npc_registry.erase(npc_id)
	print("AIBridge: PNJ '%s' supprimé" % npc_id)

# Convertit params["enemy_groups"] (Array générique venu du JSON) en
# Array[String] strict, seul format accepté par enemy.gd.
func _sanitize_params(params: Dictionary) -> Dictionary:
	var sanitized = params.duplicate()
	if sanitized.has("enemy_groups"):
		var typed_groups: Array[String] = []
		for g in sanitized["enemy_groups"]:
			typed_groups.append(String(g))
		sanitized["enemy_groups"] = typed_groups
	return sanitized
