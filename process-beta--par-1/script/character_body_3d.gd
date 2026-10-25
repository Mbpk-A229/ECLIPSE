extends CharacterBody3D
#jump
@export var jump_height : float = 2.25
@export var jump_time_to_peak : float = 0.4
@export var jump_time_to_descent : float = 0.3
@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0
@onready var audio_damage = $AudioDamage


# source: https://youtu.be/IOe1aGY6hXA?feature=shared
@onready var skin = $MartaSkin
@export var base_speed := 4.0
@export var run_speed := 10.0
@onready var camera= $CameraController/CameraPivot/Camera3D
@onready var camera_controller = $CameraController
@onready var crosshair = $HUD/Crosshair
@onready var ui = $UI
@onready var dialog_box = $HUD/DialogBox
@onready var npc_name_label = $HUD/DialogBox/VBoxContainer/NPCNameLabel
@onready var message_list = $HUD/DialogBox/VBoxContainer/ChatHistory/MessageList
@onready var player_input = $HUD/DialogBox/VBoxContainer/InputRow/PlayerInput
@onready var send_button = $HUD/DialogBox/VBoxContainer/InputRow/SendButton


var movement_input := Vector2.ZERO
var is_aiming : bool = false
var health = 5:
	set(value):
		var old_health = health
		health = value
		if ui:
			ui.update_health(value, value - old_health)
		
var current_npc : Enemy = null
var is_dialog_open : bool = false
var dialog_histories : Dictionary = {}


@onready var weapon_slots = {
	"AttackStateMachine": $HUD/WeaponBar/PunchSlot,
	"SwordStateMachine": $HUD/WeaponBar/SwordSlot,
	"BowStateMachine": $HUD/WeaponBar/BowSlot,
	"AkStateMachine": $HUD/WeaponBar/AkSlot
}


func _ready() -> void:
	add_to_group("F_BASE")
	ui.setup(health)
	$HUD/WeaponBar.visible = true
	for slot in $HUD/WeaponBar.get_children():
		slot.visible = true
		for icon in slot.get_children():
			icon.visible = true
	_update_weapon_ui()
	# deconnecte d'abord pour eviter les doublons
	if send_button.pressed.is_connected(_on_send_pressed):
		send_button.pressed.disconnect(_on_send_pressed)
	if player_input.text_submitted.is_connected(_on_text_submitted):
		player_input.text_submitted.disconnect(_on_text_submitted)
	# reconnecte proprement
	send_button.pressed.connect(_on_send_pressed)
	player_input.text_submitted.connect(_on_text_submitted)


func _update_weapon_ui() -> void:
	print("current weapon: ", skin.weapons[skin.current_weapon_index])
	print("weapon_slots size: ", weapon_slots.size())
	print("weapon_slots: ", weapon_slots)
	for weapon_name in weapon_slots:
		var slot = weapon_slots[weapon_name]
		if weapon_name == skin.weapons[skin.current_weapon_index]:
			# arme active : cadre lumineux
			slot.modulate = Color(0.511, 0.013, 0.0, 1.0)  # jaune
		else:
			# arme inactive : cadre normal
			slot.modulate = Color(1, 1, 1)  # blanc normal

func _physics_process(delta: float) -> void:
	
	update_aim_state()
	move_logic(delta)
	jump_logic(delta)
	ability_logic()
	move_and_slide()
	if is_dialog_open:
		skin.set_move_state('Idle')
		velocity = Vector3.ZERO
		move_and_slide()
		return
	

func move_logic(delta)-> void:
	movement_input = Input.get_vector("left","right","forward","backward").rotated(-camera.global_rotation.y)
	var vel_2d = Vector2(velocity.x,velocity.z)
	var is_running : bool= Input.is_action_pressed("run")
	
	if movement_input != Vector2.ZERO:
		var speed = run_speed if is_running else base_speed
		vel_2d += movement_input * base_speed * delta
		vel_2d= vel_2d.limit_length(speed)
		velocity.x= vel_2d.x
		velocity.z = vel_2d.y
		skin.set_move_state('Running')
	else:
		vel_2d= vel_2d.move_toward(Vector2.ZERO,base_speed* 4.0 * delta)
		velocity.x = vel_2d.x
		velocity.z = vel_2d.y
		skin.set_move_state('Idle')
	
	if is_aiming:
		skin.rotation.y = camera.global_rotation.y + PI
		skin.set_aim_pitch(camera_controller.rotation.x)
	elif movement_input != Vector2.ZERO:
		var target_angle = -movement_input.angle() + PI/2
		skin.rotation.y = rotate_toward(skin.rotation.y,target_angle, 6.0*delta)


func jump_logic(delta) -> void:
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y= -jump_velocity
	else:
		skin.set_move_state('Jump')
	var gravity = jump_gravity if velocity.y > 0.0 else fall_gravity
	velocity.y -= gravity * delta
	
func ability_logic() ->void:
	if Input.is_action_just_pressed("dialog"):
		_try_open_dialog()
	if Input.is_action_just_pressed("ability"):
		skin.attack()
	if Input.is_action_just_pressed("anul"):
		skin.cancel_attack()
	if Input.is_action_just_pressed("switcher"):
		skin.switch_weapon()
		_update_weapon_ui()
	
	
	

func _input(event: InputEvent) -> void:
	pass
	#if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_F1:
		#AIBridge.request_decision()

func update_aim_state() -> void:
	var holding_profond = Input.is_action_pressed("profond")
	is_aiming = holding_profond and skin.should_aim()
	skin.set_aiming(is_aiming)
	camera_controller.set_aiming(is_aiming)
	crosshair.visible = is_aiming
	if is_aiming:
		skin.set_aim_pitch(camera_controller.rotation.x)
		var crosshair_center = crosshair.get_global_rect().get_center()
		var ray_origin = camera.project_ray_origin(crosshair_center)
		var ray_direction = camera.project_ray_normal(crosshair_center)
		var to_marker = skin.firemarker.global_position - ray_origin
		var t = to_marker.dot(ray_direction)
		t = max(t, 0.3)
		skin.shoot_ray_origin = ray_origin
		skin.shoot_direction = ray_direction

func hit_player() -> void:
	if not $Timers/InvulTimer.time_left:
		print("player was hit")
		skin.hit_reaction()
		audio_damage.play()
		$Timers/InvulTimer.start()
		health -= 0.5


func _try_open_dialog() -> void:
	var nearest_npc = null
	var min_dist = 3.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy and not node.is_dead:
			var dist = global_position.distance_to(node.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest_npc = node
	if nearest_npc:
		_open_dialog(nearest_npc)
	elif is_dialog_open:
		_close_dialog()

func _open_dialog(npc: Enemy) -> void:
	if is_dialog_open:
		_close_dialog()
		return
	current_npc = npc
	is_dialog_open = true
	npc.set_physics_process(false)
	npc.move_state_machine.travel("idle")
	npc_name_label.text = "Conversation avec : " + npc.name
	# on vide et recharge l'historique
	for child in message_list.get_children():
		child.queue_free()
	var history = dialog_histories.get(npc.name, [])
	for msg in history:
		var sender : String = "Vous" if msg["role"] == "player" else str(npc.name)
		_add_message(sender, msg["text"], msg["role"] == "npc")
	dialog_box.visible = true
	player_input.grab_focus()

func _close_dialog() -> void:
	if current_npc:
		current_npc.set_physics_process(true)
	current_npc = null
	is_dialog_open = false
	dialog_box.visible = false

func _add_message(sender: String, text: String, is_npc: bool) -> void:
	var label = Label.new()
	label.text = "[" + sender + "] : " + text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if is_npc:
		label.modulate = Color(0.5, 1, 0.5)
	else:
		label.modulate = Color(1, 1, 1)
	message_list.add_child(label)

func _on_send_pressed() -> void:
	_send()

func _on_text_submitted(_text: String) -> void:
	_send()

func _send() -> void:
	if current_npc == null:
		return
	var text = player_input.text.strip_edges()
	if text == "":
		return
	player_input.text = ""
	var history = dialog_histories.get(current_npc.name, [])
	history.append({"role": "player", "text": text})
	# simulation de reponse en attendant le backend
	var response = current_npc.name + " : Je n'ai rien à vous dire pour l'instant..."
	history.append({"role": "npc", "text": response})
	dialog_histories[current_npc.name] = history
	_add_message("Vous", text, false)
	_add_message(current_npc.name, response, true)
