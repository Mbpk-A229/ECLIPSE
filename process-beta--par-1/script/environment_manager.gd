extends Node

@onready var spawner = $"../EnvironmentSpawner"

# ===============================
# EMPRISE DE LA BASE À PROTÉGER
# ===============================
# La base générée par GeometryFactory occupe X de -62 à +62 et Z de -44 à +44,
# clôture comprise. On protège un peu plus large.
#
# Les exclusions étant des cercles, on pave ce rectangle avec une grille de
# disques. Pour qu'une grille couvre le plan SANS TROU, le rayon doit être au
# moins égal à la demi-diagonale de la maille — sinon il reste un losange
# non couvert au centre de chaque maille, et avec des milliers de tirages
# quelques éléments finissent par y tomber.
#
#   pas X = 16.00   pas Z = 15.33   demi-diagonale = 11.08
#   rayon = 13.00                   marge = 1.92 m
#
# La marge sert aussi à compenser l'emprise des assets : l'exclusion ne teste
# que le point d'origine de l'instance, or multirock.tscn ou grass.tscn
# répartissent leurs éléments autour de cette origine. Si tu vois encore des
# rochers mordre sur la base, c'est ce rayon qu'il faut augmenter.

const BASE_HALF_X := 64.0
const BASE_HALF_Z := 46.0
const GRID_COLS   := 8
const GRID_ROWS   := 6
const CELL_RADIUS := 13.0

var base_exclusion: Array = []


func _build_base_exclusion() -> Array:
	var zones: Array = []
	var step_x: float = BASE_HALF_X * 2.0 / float(GRID_COLS)
	var step_z: float = BASE_HALF_Z * 2.0 / float(GRID_ROWS)
	for i in range(GRID_COLS + 1):
		for j in range(GRID_ROWS + 1):
			zones.append({
				"center": Vector3(
					-BASE_HALF_X + float(i) * step_x,
					0.0,
					-BASE_HALF_Z + float(j) * step_z
				),
				"radius": CELL_RADIUS
			})
	return zones


func _ready() -> void:
	await get_tree().process_frame

	base_exclusion = _build_base_exclusion()

	# ATTENTION : dans spawn_scatter, area_size est le CÔTÉ du carré, pas un rayon.
	# 300 signifie donc une zone de 300x300, soit +-150 m autour de l'origine.

	# Forêt de pins en arrière-plan
	spawner.spawn_scatter("tree_pine_a", Vector3.ZERO, 200.0, 80, 6.0, {
		"scale_min": 0.9,
		"scale_max": 1.4,
		"randomize_rotation": true
	}, base_exclusion)

	spawner.spawn_scatter("tree_pine_b", Vector3.ZERO, 200.0, 200, 6.0, {
		"scale_min": 0.9,
		"scale_max": 1.4,
		"randomize_rotation": true
	}, base_exclusion)

	spawner.spawn_scatter("tree_pine_c", Vector3.ZERO, 200.0, 200, 6.0, {
		"scale_min": 0.9,
		"scale_max": 1.4,
		"randomize_rotation": true
	}, base_exclusion)

	# Tapis d'herbe : zone élargie, sinon tout tombe dans l'exclusion
	spawner.spawn_scatter("grass", Vector3.ZERO, 300.0, 10000, 6.0, {
		"scale_min": 0.9,
		"scale_max": 1.4,
		"randomize_rotation": true
	}, base_exclusion)

	spawner.spawn_scatter("rock_a", Vector3.ZERO, 300.0, 10000, 6.0, {
		"scale_min": 0.9,
		"scale_max": 1.4,
		"randomize_rotation": true
	}, base_exclusion)


# ===============================
# EXEMPLE : élément placé précisément
# (ex: un arbre qui bloque un chemin, sert de repère, etc.)
# ===============================
#spawner.spawn_element("tree_oak", Vector3(12, 0, 4), {
#	"scale": 1.2,
#	"rotation_y": deg_to_rad(45)
#})
