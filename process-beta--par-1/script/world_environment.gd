extends WorldEnvironment

@export var day_color := Color(0.4, 0.65, 0.95) # bleu ciel
@export var night_color := Color(0.02, 0.02, 0.05) # quasi noir
@export var start_is_day := true


func _ready():
	if environment == null:
		environment = Environment.new()

	if start_is_day:
		set_day()
	else:
		set_night()
		
# =====================
# INTERFACE IA
# =====================
func set_day():
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = day_color


func set_night():
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = night_color
