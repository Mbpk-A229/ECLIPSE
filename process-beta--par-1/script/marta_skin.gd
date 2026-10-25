extends Node3D
@onready var move_state_machine = $AnimationTree.get("parameters/StateMachine/playback")
@onready var ranged_weapon_state_machine = $AnimationTree.get("parameters/StateMachine 2/playback")
@onready var melee_weapon_state_machine = $AnimationTree.get("parameters/StateMachine 3/playback")

														  
var weapons : Array[String] = ["AttackStateMachine", "SwordStateMachine", "BowStateMachine", "AkStateMachine"]
var current_weapon_index : int = 0
var attack_state_machine

var is_attack_mode : bool = false
var is_in_attack_idle : bool = false

@onready var skeleton : Skeleton3D = $Armature/Skeleton3D
@export var bow_left_shoulder_correction : Vector3 = Vector3.ZERO
@export var bow_right_shoulder_correction : Vector3 = Vector3.ZERO
@export var bow_left_forearm_correction : Vector3 = Vector3.ZERO
@export var bow_right_forearm_correction : Vector3 = Vector3.ZERO
@export var ak_left_shoulder_correction : Vector3 = Vector3.ZERO
@export var ak_right_shoulder_correction : Vector3 = Vector3.ZERO
@export var ak_left_forearm_correction : Vector3 = Vector3.ZERO
@export var ak_right_forearm_correction : Vector3 = Vector3.ZERO

var left_shoulder_idx : int = -1
var right_shoulder_idx : int = -1
var left_forearm_idx : int = -1
var right_forearm_idx : int = -1

var is_aiming : bool = false

var aim_pitch : float = 0.0
var spine_aim_idx : int = -1
@export var spine_aim_bone_name : String = "mixamorig11_Spine1"
@export var aim_pitch_multiplier : float = -0.1

func set_aim_pitch(value: float) -> void:
	aim_pitch = value

func should_aim() -> bool:
	if not is_attack_mode:
		return false
	var current_weapon = weapons[current_weapon_index]
	return not (current_weapon in melee_weapons)

func set_aiming(value: bool) -> void:
	is_aiming = value


func _ready() -> void:
	$AnimationTree.animation_started.connect(_on_animation_started)
	_update_attack_state_machine()
	left_shoulder_idx = skeleton.find_bone("mixamorig11_LeftShoulder")
	right_shoulder_idx = skeleton.find_bone("mixamorig11_RightShoulder")
	left_forearm_idx = skeleton.find_bone("mixamorig11_LeftForeArm")
	right_forearm_idx = skeleton.find_bone("mixamorig11_RightForeArm")
	
	process_priority = 1
	_update_weapon_visibility()
	spine_aim_idx = skeleton.find_bone(spine_aim_bone_name)

func _process(_delta: float) -> void:
	if is_attack_mode and not is_in_attack_idle:
		var current = attack_state_machine.get_current_node()
		if current == "Attack_Idle":
			is_in_attack_idle = true
	if is_attack_mode:
		var current_weapon = weapons[current_weapon_index]
		var is_melee = current_weapon in melee_weapons
		if not is_melee:
			var l_shoulder_degrees : Vector3
			var r_shoulder_degrees : Vector3
			var l_forearm_degrees : Vector3
			var r_forearm_degrees : Vector3
			if current_weapon == "BowStateMachine":
				l_shoulder_degrees = bow_left_shoulder_correction
				r_shoulder_degrees = bow_right_shoulder_correction
				l_forearm_degrees = bow_left_forearm_correction
				r_forearm_degrees = bow_right_forearm_correction
			elif current_weapon == "AkStateMachine":
				l_shoulder_degrees = ak_left_shoulder_correction
				r_shoulder_degrees = ak_right_shoulder_correction
				l_forearm_degrees = ak_left_forearm_correction
				r_forearm_degrees = ak_right_forearm_correction
			if left_shoulder_idx != -1:
				var l_correction = Quaternion.from_euler(l_shoulder_degrees * (PI / 180.0))
				var l_current = skeleton.get_bone_pose_rotation(left_shoulder_idx)
				skeleton.set_bone_pose_rotation(left_shoulder_idx, l_current * l_correction)
			if right_shoulder_idx != -1:
				var r_correction = Quaternion.from_euler(r_shoulder_degrees * (PI / 180.0))
				var r_current = skeleton.get_bone_pose_rotation(right_shoulder_idx)
				skeleton.set_bone_pose_rotation(right_shoulder_idx, r_current * r_correction)
			if left_forearm_idx != -1:
				var lf_correction = Quaternion.from_euler(l_forearm_degrees * (PI / 180.0))
				var lf_current = skeleton.get_bone_pose_rotation(left_forearm_idx)
				skeleton.set_bone_pose_rotation(left_forearm_idx, lf_current * lf_correction)
			if right_forearm_idx != -1:
				var rf_correction = Quaternion.from_euler(r_forearm_degrees * (PI / 180.0))
				var rf_current = skeleton.get_bone_pose_rotation(right_forearm_idx)
				skeleton.set_bone_pose_rotation(right_forearm_idx, rf_current * rf_correction)
	if is_aiming and spine_aim_idx != -1:
		var pitch_correction = Quaternion.from_euler(Vector3(aim_pitch * aim_pitch_multiplier, 0, 0))
		var current_spine = skeleton.get_bone_pose_rotation(spine_aim_idx)
		skeleton.set_bone_pose_rotation(spine_aim_idx, current_spine * pitch_correction)
@onready var right_hand_attachment : BoneAttachment3D = $Armature/Skeleton3D/RightHand
@onready var left_hand_attachment : BoneAttachment3D = $Armature/Skeleton3D/LeftHand


var weapon_models : Dictionary = {
	"SwordStateMachine": "swords_a",
	"AkStateMachine": "ak_47",
	"BowStateMachine": "bow_a"  # a ajuster avec le vrai nom une fois l'arc ajoute
}

func _update_weapon_visibility() -> void:
	for child in right_hand_attachment.get_children():
		child.visible = false
	for child in left_hand_attachment.get_children():
		child.visible = false
	var model_name = weapon_models.get(weapons[current_weapon_index], "")
	if model_name != "":
		if right_hand_attachment.has_node(model_name):
			right_hand_attachment.get_node(model_name).visible = true
		elif left_hand_attachment.has_node(model_name):
			left_hand_attachment.get_node(model_name).visible = true

func _update_attack_state_machine() -> void:
	var weapon_name = weapons[current_weapon_index]
	if weapon_name in melee_weapons:
		attack_state_machine = $AnimationTree.get("parameters/StateMachine 3/%s/playback" % weapon_name)
	else:
		attack_state_machine = $AnimationTree.get("parameters/StateMachine 2/%s/playback" % weapon_name)

func switch_weapon() -> void:
	if is_attack_mode:
		cancel_attack()
	current_weapon_index = (current_weapon_index + 1) % weapons.size()
	var weapon_name = weapons[current_weapon_index]
	if weapon_name in melee_weapons:
		melee_weapon_state_machine.travel(weapon_name)
	else:
		ranged_weapon_state_machine.travel(weapon_name)
	_update_attack_state_machine()
	_update_weapon_visibility()

var melee_weapons : Array[String] = ["AttackStateMachine", "SwordStateMachine"]

func set_move_state(state_name: String) -> void:
	if is_attack_mode:
		var current_weapon = weapons[current_weapon_index]
		var is_melee = current_weapon in melee_weapons
		if state_name == 'Idle':
			if not is_in_attack_idle:
				_enter_attack_idle()
		elif is_melee:
			# seules les armes de melee coupent l'attaque quand on bouge
			if is_in_attack_idle:
				_exit_attack_idle()
		# pour l'arc/ak (is_melee == false) , on ne fait rien :
		# le filtre du Blend2 laisse deja les jambes suivre le deplacement
	move_state_machine.travel(state_name)


func attack() -> void:
	if not is_attack_mode:
		is_attack_mode = true
		_enter_attack_idle()
	elif is_in_attack_idle:
		var current_weapon = weapons[current_weapon_index]
		var is_melee = current_weapon in melee_weapons
		if is_melee or is_aiming:
			is_in_attack_idle = false
			attack_state_machine.travel("Attack")

func cancel_attack() -> void:
	if is_attack_mode:
		is_attack_mode = false
		is_in_attack_idle = false
		$AnimationTree.set("parameters/Blend2/blend_amount", 0.0)
		$AnimationTree.set("parameters/Blend2 2/blend_amount", 0.0)
		

func _on_animation_started(anim_name: StringName) -> void:
	var current_weapon = weapons[current_weapon_index]
	if anim_name == "mixamo_com_006" and not (current_weapon in melee_weapons):
		shoot_fireball()
	elif anim_name == "mixamo_com_019":
		shoot_arrow()

func _enter_attack_idle() -> void:
	var weapon_name = weapons[current_weapon_index]
	if weapon_name in melee_weapons:
		$AnimationTree.set("parameters/Blend2 2/blend_amount", 1.0)
		$AnimationTree.set("parameters/Blend2/blend_amount", 0.0)
	else:
		$AnimationTree.set("parameters/Blend2/blend_amount", 1.0)
		$AnimationTree.set("parameters/Blend2 2/blend_amount", 0.0)
	attack_state_machine.travel("Attack_Idle")
	is_in_attack_idle = true

func _exit_attack_idle() -> void:
	$AnimationTree.set("parameters/Blend2/blend_amount", 0.0)
	$AnimationTree.set("parameters/Blend2 2/blend_amount", 0.0)
	is_in_attack_idle = false

func hit_reaction() -> void:
	$AnimationTree.set("parameters/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func can_damage(value: bool):
	$Armature/Skeleton3D/RightHand/swords_a.can_damage = value
	
func can_damage_bh(value: bool):
	$Armature/Skeleton3D/BoneAttachment3D/hand.can_damage_bh = value


@onready var firemarker = $Armature/Skeleton3D/RightHand/ak_47/firemarker
const FIREBALL = preload("res://vfx/fireball.tscn")

@onready var bow_marker = $Armature/Skeleton3D/LeftHand/bow_a/Marker3D
const BOW = preload("res://weapons/arrow.tscn")


var shoot_direction : Vector3 = Vector3.ZERO
var shoot_ray_origin : Vector3 = Vector3.ZERO

func shoot_fireball() -> void:
	var fireball = FIREBALL.instantiate()
	get_tree().current_scene.add_child(fireball)
	var ray_origin = shoot_ray_origin
	var ray_dir = shoot_direction
	# distance entre la camera et le marker projetée sur la direction de tir
	var to_marker = firemarker.global_position - ray_origin
	var t = to_marker.dot(ray_dir)
	t = max(t, 0.3)
	var spawn_point = ray_origin + ray_dir * t
	fireball.global_position = spawn_point
	fireball.direction = shoot_direction
	

func shoot_arrow() -> void:
	var arrow = BOW.instantiate()
	get_tree().current_scene.add_child(arrow)
	var ray_origin = shoot_ray_origin
	var ray_dir = shoot_direction
	# distance entre la camera et le marker projetée sur la direction de tir
	var to_marker = bow_marker.global_position - ray_origin
	var t = to_marker.dot(ray_dir)
	t = max(t, 0.3)
	var spawn_point = ray_origin + ray_dir * t
	arrow.global_position = spawn_point
	arrow.direction = -shoot_direction
	arrow.speed = 5.0
