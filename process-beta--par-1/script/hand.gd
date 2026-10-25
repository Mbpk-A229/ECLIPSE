extends Node3D

var can_damage_bh := false

func _process(_delta: float) -> void:
	if can_damage_bh:
		var collider = $RayCast3D.get_collider()
		if collider and 'hit' in collider:
			collider.hit()
		
