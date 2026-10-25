extends Node3D
class_name GeometryFactory

# Node parent qui recevra toutes les formes générées.
# Créé automatiquement s'il n'existe pas déjà comme frère de ce nœud.
@onready var generated_root: Node3D = _get_or_create_generated_root()

func _get_or_create_generated_root() -> Node3D:
	var parent := get_parent()
	if parent.has_node("Generated"):
		return parent.get_node("Generated")
	var new_root := Node3D.new()
	new_root.name = "Generated"
	parent.add_child(new_root)
	return new_root


func _ready():
	await get_tree().process_frame
	build_base(Vector3(0, 0, 0))


# ==================================================
# API PUBLIQUE POUR L'IA
# ==================================================
# params attendus :
# {
#   "type": "box" | "cylinder" | "plane" | "sphere" | "prism" | "cone" | "capsule" | "torus"
#   "position": Vector3
#   "rotation": Vector3 (en degrés)
#   "size": Vector3
#   "collision": bool
#   "color": Color (optionnel, couleur unie)
#   "emission_color": Color (optionnel, couleur de lueur)
#   "emission_energy": float (optionnel, intensité de la lueur, defaut 1.0)
# }

func create_shape(params: Dictionary) -> Node3D:
	var shape_type: String = params.get("type", "box")
	var position: Vector3 = params.get("position", Vector3.ZERO)
	var rotation: Vector3 = params.get("rotation", Vector3.ZERO)
	var size: Vector3 = params.get("size", Vector3.ONE)
	var with_collision: bool = params.get("collision", true)

	# =====================
	# NODE VISUEL
	# =====================
	var visual := MeshInstance3D.new()
	visual.position = position
	visual.rotation_degrees = rotation

	var mesh: Mesh
	var collision_shape: Shape3D


	match shape_type:

		# =====================
		# BOX / CUBE
		# =====================
		"box":
			var m := BoxMesh.new()
			m.size = size
			mesh = m

			var s := BoxShape3D.new()
			s.size = size
			collision_shape = s


		# =====================
		# CYLINDER / TOUR
		# =====================
		"cylinder":
			var m := CylinderMesh.new()
			m.top_radius = size.x * 0.5
			m.bottom_radius = size.x * 0.5
			m.height = size.y
			mesh = m

			var s := CylinderShape3D.new()
			s.radius = size.x * 0.5
			s.height = size.y
			collision_shape = s


		# =====================
		# PLANE / SOL / TOIT
		# =====================
		"plane":
			var m := PlaneMesh.new()
			m.size = Vector2(size.x, size.z)
			mesh = m

			var s := BoxShape3D.new()
			s.size = Vector3(size.x, 0.2, size.z)
			collision_shape = s


		# =====================
		# SPHERE / DOME
		# =====================
		"sphere":
			var m := SphereMesh.new()
			m.radius = size.x * 0.5
			m.height = size.x
			mesh = m

			var s := SphereShape3D.new()
			s.radius = size.x * 0.5
			collision_shape = s


		# =====================
		# PRISM / TOIT EN PENTE
		# =====================
		"prism":
			var m := PrismMesh.new()
			m.size = size
			mesh = m

			# Pas de PrismShape3D natif -> collision en boîte englobante
			var s := BoxShape3D.new()
			s.size = size
			collision_shape = s


		# =====================
		# CONE / TOURELLE
		# =====================
		"cone":
			var m := CylinderMesh.new()
			m.top_radius = 0.0
			m.bottom_radius = size.x * 0.5
			m.height = size.y
			mesh = m

			var s := CylinderShape3D.new()
			s.radius = size.x * 0.5
			s.height = size.y
			collision_shape = s


		# =====================
		# CAPSULE
		# =====================
		"capsule":
			var m := CapsuleMesh.new()
			m.radius = size.x * 0.5
			m.height = size.y
			mesh = m

			var s := CapsuleShape3D.new()
			s.radius = size.x * 0.5
			s.height = size.y
			collision_shape = s


		# =====================
		# TORUS / ANNEAU
		# =====================
		"torus":
			var m := TorusMesh.new()
			m.inner_radius = size.x * 0.5
			m.outer_radius = size.y * 0.5
			mesh = m

			# Pas de TorusShape3D natif -> collision approximée en sphère englobante
			var s := SphereShape3D.new()
			s.radius = size.y * 0.5
			collision_shape = s


		_:
			push_error("Type de forme inconnu : " + shape_type)
			return null


	# =====================
	# ASSIGNATION VISUELLE
	# =====================
	visual.mesh = mesh
	generated_root.add_child(visual)

	# =====================
	# COULEUR / ÉMISSION (OPTIONNEL)
	# =====================
	if params.has("color") or params.has("emission_color"):
		var mat := StandardMaterial3D.new()

		if params.has("color"):
			mat.albedo_color = params["color"]

		if params.has("emission_color"):
			mat.emission_enabled = true
			mat.emission = params["emission_color"]
			mat.emission_energy_multiplier = params.get("emission_energy", 1.0)

		visual.set_surface_override_material(0, mat)


	# =====================
	# COLLISION (OPTIONNELLE)
	# =====================
	if with_collision:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		col.shape = collision_shape
		body.add_child(col)
		visual.add_child(body)

	return visual


# ==================================================
# LUMIÈRES D'INTÉRIEUR
# ==================================================
# params attendus :
# {
#   "type": "omni" | "spot"
#   "position": Vector3
#   "rotation": Vector3 (en degrés, utile pour "spot")
#   "color": Color (defaut blanc chaud)
#   "energy": float (intensité, defaut 1.0)
#   "range": float (portée, defaut 5.0)
#   "spot_angle": float (en degrés, uniquement pour "spot", defaut 35.0)
# }
func create_light(params: Dictionary) -> Light3D:
	var light_type: String = params.get("type", "omni")
	var position: Vector3 = params.get("position", Vector3.ZERO)
	var rotation: Vector3 = params.get("rotation", Vector3.ZERO)
	var color: Color = params.get("color", Color(1.0, 0.85, 0.6)) # blanc chaud par défaut
	var energy: float = params.get("energy", 1.0)
	var light_range: float = params.get("range", 5.0)

	var light: Light3D

	match light_type:
		"omni":
			var l := OmniLight3D.new()
			l.omni_range = light_range
			light = l

		"spot":
			var l := SpotLight3D.new()
			l.spot_range = light_range
			l.spot_angle = params.get("spot_angle", 35.0)
			light = l

		_:
			push_error("Type de lumière inconnu : " + light_type)
			return null

	light.position = position
	light.rotation_degrees = rotation
	light.light_color = color
	light.light_energy = energy

	generated_root.add_child(light)
	return light


# ==================================================
# PALETTE DE LA BASE — toute la DA passe par ici
# ==================================================

const C_CONCRETE      := Color(0.60, 0.59, 0.56)
const C_CONCRETE_DARK := Color(0.38, 0.38, 0.37)
const C_PANEL         := Color(0.74, 0.73, 0.69)
const C_PANEL_WORN    := Color(0.66, 0.63, 0.57)
const C_ACCENT        := Color(0.80, 0.40, 0.14)   # orange industriel
const C_METAL         := Color(0.54, 0.56, 0.59)
const C_METAL_DARK    := Color(0.26, 0.27, 0.30)
const C_GLASS         := Color(0.42, 0.58, 0.66)
const C_ROOF          := Color(0.19, 0.20, 0.22)
const C_SOLAR         := Color(0.06, 0.08, 0.15)
const C_PAVING        := Color(0.52, 0.51, 0.49)
const C_HAZARD        := Color(0.86, 0.72, 0.14)
const C_SCREEN        := Color(0.05, 0.06, 0.09)

# --- mobilier ---
const C_WOOD       := Color(0.36, 0.24, 0.16)
const C_WOOD_LIGHT := Color(0.58, 0.45, 0.30)
const C_FABRIC_A   := Color(0.18, 0.24, 0.34)
const C_FABRIC_B   := Color(0.34, 0.29, 0.25)
const C_FABRIC_C   := Color(0.22, 0.30, 0.27)
const C_LINEN      := Color(0.82, 0.80, 0.76)
const C_RUG        := Color(0.38, 0.30, 0.26)
const C_APPLIANCE  := Color(0.80, 0.81, 0.80)

const E_WARM  := Color(1.00, 0.82, 0.55)
const E_COLD  := Color(0.45, 0.75, 1.00)
const E_ALERT := Color(1.00, 0.30, 0.18)

# Dimensions de référence (mètres), calibrées pour une caméra 3e personne
const FLOOR_TOP  := 0.06   # niveau de la face superieure des sols interieurs
const FLOOR_H    := 3.2    # hauteur sous plafond
const WALL_T     := 0.25   # épaisseur des murs
const DOOR_W     := 2.0
const DOOR_H     := 2.4
const CORRIDOR_W := 3.0
const PARAPET_H  := 1.15
const APT_W      := 7.0    # largeur d'un logement
const APT_D      := 7.0    # profondeur d'un logement
const APT_COUNT  := 5      # 5 de chaque côté du couloir = 10 logements

# Emprise du périmètre clôturé
const PERIM_X := 62.0
const PERIM_Z := 44.0


# ==================================================
# BRIQUES DE BASE
# ==================================================

# Dalle horizontale : sol, plafond, toit, terrasse.
# ATTENTION : center.y designe la FACE SUPERIEURE, c'est-a-dire le niveau sur
# lequel on marche. La dalle s'etend vers le BAS. C'est ce qui garantit que les
# personnages et le mobilier, places a ce niveau de reference, reposent dessus
# au lieu de s'y enfoncer.
#
# Le visuel garde l'epaisseur demandee, mais la collision est un pave epais et
# invisible : une collision de 15 cm est trop mince, un corps qui tombe dessus
# la traverse, et un corps qui apparait dedans se fait expulser par le bas.
func _slab(center: Vector3, size_x: float, size_z: float, thickness: float, color: Color) -> void:
	create_shape({
		"type": "box",
		"position": center - Vector3(0, thickness * 0.5, 0),
		"size": Vector3(size_x, thickness, size_z),
		"collision": false,
		"color": color
	})
	var solid: float = thickness + 0.60
	var body = create_shape({
		"type": "box",
		"position": center - Vector3(0, solid * 0.5, 0),
		"size": Vector3(size_x, solid, size_z),
		"color": color
	})
	if body != null:
		body.visible = false


# Mur défini par un segment a -> b, avec ouvertures automatiques.
# openings : [{"at": mètres depuis a, "width": float, "height": float}]
# IMPORTANT : les ouvertures doivent être fournies dans l'ordre croissant de "at".
func _wall(a: Vector3, b: Vector3, height: float, thickness: float,
		color: Color, openings: Array = []) -> void:
	var dir: Vector3 = b - a
	var length: float = dir.length()
	if length <= 0.01:
		return
	var dirn: Vector3 = dir / length
	var angle: float = rad_to_deg(atan2(-dirn.z, dirn.x))

	var cursor: float = 0.0
	for i in range(openings.size()):
		var op: Dictionary = openings[i]
		var at: float = float(op.get("at", 0.0))
		var w: float = float(op.get("width", DOOR_W))
		var h: float = float(op.get("height", DOOR_H))
		var s: float = clampf(at - w * 0.5, 0.0, length)
		var e: float = clampf(at + w * 0.5, 0.0, length)
		if s > cursor:
			_wall_piece(a, dirn, angle, cursor, s, 0.0, height, thickness, color)
		if h < height:   # linteau au-dessus de l'ouverture
			_wall_piece(a, dirn, angle, s, e, h, height, thickness, color)
		cursor = e

	if cursor < length:
		_wall_piece(a, dirn, angle, cursor, length, 0.0, height, thickness, color)


func _wall_piece(a: Vector3, dirn: Vector3, angle: float,
		t0: float, t1: float, y0: float, y1: float,
		thickness: float, color: Color) -> void:
	var seg_len: float = t1 - t0
	var seg_h: float = y1 - y0
	if seg_len <= 0.01 or seg_h <= 0.01:
		return
	create_shape({
		"type": "box",
		"position": a + dirn * ((t0 + t1) * 0.5) + Vector3(0, (y0 + y1) * 0.5, 0),
		"rotation": Vector3(0, angle, 0),
		"size": Vector3(seg_len, seg_h, thickness),
		"color": color
	})


# Bandeau vitré émissif, purement décoratif (aucune collision).
func _window(a: Vector3, b: Vector3, y: float, height: float, energy: float) -> void:
	var dir: Vector3 = b - a
	var length: float = dir.length()
	if length <= 0.01:
		return
	var dirn: Vector3 = dir / length
	create_shape({
		"type": "box",
		"position": a + dirn * (length * 0.5) + Vector3(0, y + height * 0.5, 0),
		"rotation": Vector3(0, rad_to_deg(atan2(-dirn.z, dirn.x)), 0),
		"size": Vector3(length, height, 0.08),
		"collision": false,
		"color": C_GLASS,
		"emission_color": E_WARM,
		"emission_energy": energy
	})


# Garde-corps sur les 4 côtés d'un toit.
# gaps : trouées d'accès, par côté — {"n": [...], "s": [...], "w": [...], "e": [...]}
# Chaque trouée : {"at": mètres depuis le début du mur, "width": float, "height": height}
# Pour les côtés "n" et "s", "at" se mesure depuis le coin -X et progresse vers +X.
# Pour les côtés "w" et "e", "at" se mesure depuis le coin -Z et progresse vers +Z.
func _parapet(center: Vector3, size_x: float, size_z: float, y: float,
		height: float, color: Color, gaps: Dictionary = {}) -> void:
	var hx: float = size_x * 0.5
	var hz: float = size_z * 0.5
	var c: Vector3 = Vector3(center.x, y, center.z)
	var gn: Array = gaps.get("n", [])
	var gs: Array = gaps.get("s", [])
	var gw: Array = gaps.get("w", [])
	var ge: Array = gaps.get("e", [])
	_wall(c + Vector3(-hx, 0, -hz), c + Vector3(hx, 0, -hz), height, 0.2, color, gn)
	_wall(c + Vector3(-hx, 0,  hz), c + Vector3(hx, 0,  hz), height, 0.2, color, gs)
	_wall(c + Vector3(-hx, 0, -hz), c + Vector3(-hx, 0, hz), height, 0.2, color, gw)
	_wall(c + Vector3( hx, 0, -hz), c + Vector3( hx, 0, hz), height, 0.2, color, ge)


# Volée d'escalier droite montant depuis "start" dans la direction horizontale "dir".
# Le dessus de la dernière marche se trouve exactement à start.y + total_height,
# et à start + dir * total_run : c'est ce point qui doit tomber au ras de la dalle.
func _stairs(start: Vector3, total_height: float, total_run: float,
		width: float, dir: Vector3) -> void:
	var d: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.001:
		return
	d = d.normalized()
	var angle: float = rad_to_deg(atan2(-d.z, d.x))
	var steps: int = maxi(2, int(ceil(total_height / 0.19)))
	var rise: float = total_height / float(steps)
	var run: float = total_run / float(steps)
	for i in range(steps):
		create_shape({
			"type": "box",
			"position": start + d * (run * (float(i) + 0.5)) + Vector3(0, rise * (float(i) + 0.5), 0),
			"rotation": Vector3(0, angle, 0),
			"size": Vector3(run, rise, width),
			"collision": false,
			"color": C_METAL_DARK
		})

	# Rampe de collision INVISIBLE calée sur le nez des marches.
	# Un CharacterBody3D ne sait pas gravir une marche : sans ça, joueur et PNJ
	# accrochent ou tremblent à chaque degré. Ici la physique voit un plan
	# incliné continu, alors que l'œil voit un escalier.
	var slope_rad: float = atan2(total_height, total_run)
	var tan_slope: float = total_height / total_run

	# Ligne du nez des marches : de (0, rise) au départ à (total_run, total_height).
	# On la PROLONGE de 1 m vers le bas, sinon la rampe présente elle-même une
	# marche de 18 cm au pied de la volée — exactement le défaut qu'on corrige.
	var extra: float = 1.0
	var p_low: Vector3 = start + Vector3(0, rise, 0) - d * extra - Vector3(0, extra * tan_slope, 0)
	var p_high: Vector3 = start + d * total_run + Vector3(0, total_height, 0)

	# Le centre du pavé descend d'une demi-épaisseur mesurée à la verticale,
	# pour que sa FACE SUPÉRIEURE suive exactement la ligne du nez des marches.
	var ramp_center: Vector3 = (p_low + p_high) * 0.5 - Vector3(0, 0.15 / cos(slope_rad), 0)
	var ramp_len: float = (total_run + extra) / cos(slope_rad)

	var ramp = create_shape({
		"type": "box",
		"position": ramp_center,
		"rotation": Vector3(0, angle, rad_to_deg(slope_rad)),
		"size": Vector3(ramp_len, 0.30, width),
		"color": C_METAL_DARK
	})
	if ramp != null:
		ramp.visible = false

	# Petit palier de collision invisible au sommet : la volée s'aborde alors
	# aussi bien en montant qu'en descendant, sans ressaut à la jonction.
	var top_pad = create_shape({
		"type": "box",
		"position": p_high + d * 0.5 - Vector3(0, 0.30, 0),
		"rotation": Vector3(0, angle, 0),
		"size": Vector3(1.0, 0.60, width),
		"color": C_METAL_DARK
	})
	if top_pad != null:
		top_pad.visible = false


# Deux rampes de collision INVISIBLES de part et d'autre d'un ressaut, pour
# qu'il se franchisse dans les deux sens : bordure, seuil, muret bas.
# a et b sont les extremites du ressaut, prises au niveau du SOL.
# half_thick = demi-epaisseur du ressaut, run = longueur du biseau au sol.
# Les deux rampes se rejoignent en cretes au-dessus de l'axe du ressaut :
# vu de la physique, l'obstacle devient un dos d'ane franchissable.
func _step_ramps(a: Vector3, b: Vector3, height: float,
		half_thick: float, run: float = 0.9) -> void:
	var dir: Vector3 = b - a
	var length: float = dir.length()
	if length <= 0.01 or height <= 0.01:
		return
	var d: Vector3 = dir / length
	var n: Vector3 = Vector3(-d.z, 0.0, d.x)          # perpendiculaire horizontale
	var mid: Vector3 = a + d * (length * 0.5)

	var total_run: float = run + half_thick
	var slope: float = atan2(height, total_run)
	var ramp_len: float = total_run / cos(slope)

	for side in [-1.0, 1.0]:
		var sv: float = float(side)
		var p_low: Vector3 = mid + n * (sv * total_run)          # pied, au sol
		var p_high: Vector3 = mid + Vector3(0, height, 0)        # crete, sur l'axe
		var h_dir: Vector3 = -n * sv                             # sens de la montee
		var center: Vector3 = (p_low + p_high) * 0.5 - Vector3(0, 0.15 / cos(slope), 0)
		var ramp = create_shape({
			"type": "box",
			"position": center,
			"rotation": Vector3(0, rad_to_deg(atan2(-h_dir.z, h_dir.x)), rad_to_deg(slope)),
			"size": Vector3(ramp_len, 0.30, length),
			"color": C_CONCRETE_DARK
		})
		if ramp != null:
			ramp.visible = false


# Poteau vertical.
func _pillar(pos: Vector3, height: float, radius: float, color: Color) -> void:
	create_shape({
		"type": "cylinder",
		"position": pos + Vector3(0, height * 0.5, 0),
		"size": Vector3(radius * 2.0, height, radius * 2.0),
		"color": color
	})


# Champ de panneaux solaires inclinés, posé sur un toit.
func _solar_field(center: Vector3, cols: int, rows: int) -> void:
	var sx: float = 1.95
	var sz: float = 2.30
	for cx in range(cols):
		for cz in range(rows):
			var p: Vector3 = center + Vector3(
				(float(cx) - float(cols - 1) * 0.5) * sx,
				0.62,
				(float(cz) - float(rows - 1) * 0.5) * sz
			)
			create_shape({
				"type": "box",
				"position": p,
				"rotation": Vector3(-22, 0, 0),
				"size": Vector3(1.75, 0.06, 1.10),
				"collision": false,
				"color": C_SOLAR,
				"emission_color": E_COLD,
				"emission_energy": 0.08
			})
	# rails de support
	for cz in range(rows):
		create_shape({
			"type": "box",
			"position": Vector3(center.x, center.y + 0.30,
				center.z + (float(cz) - float(rows - 1) * 0.5) * sz),
			"size": Vector3(float(cols) * sx, 0.08, 0.10),
			"collision": false,
			"color": C_METAL_DARK
		})


# Bloc technique de toiture (centrale de traitement d'air).
func _roof_unit(pos: Vector3) -> void:
	create_shape({
		"type": "box",
		"position": pos + Vector3(0, 0.6, 0),
		"size": Vector3(2.4, 1.2, 1.8),
		"color": C_METAL
	})
	create_shape({
		"type": "cylinder",
		"position": pos + Vector3(0, 1.45, 0),
		"size": Vector3(1.0, 0.5, 1.0),
		"collision": false,
		"color": C_METAL_DARK
	})


# Mât d'éclairage.
func _light_mast(pos: Vector3, height: float) -> void:
	_pillar(pos, height, 0.14, C_METAL_DARK)
	create_shape({
		"type": "box",
		"position": pos + Vector3(0, height, 0),
		"size": Vector3(1.4, 0.22, 0.5),
		"collision": false,
		"color": C_METAL_DARK
	})
	create_shape({
		"type": "box",
		"position": pos + Vector3(0, height - 0.16, 0),
		"size": Vector3(1.2, 0.06, 0.4),
		"collision": false,
		"color": C_GLASS,
		"emission_color": E_WARM,
		"emission_energy": 3.0
	})
	create_light({
		"type": "spot",
		"position": pos + Vector3(0, height - 0.3, 0),
		"rotation": Vector3(-90, 0, 0),
		"color": E_WARM,
		"energy": 3.0,
		"range": 18.0,
		"spot_angle": 50.0
	})


# Tronçon de clôture défensive : muret béton + grillage + poteaux.
func _fence(a: Vector3, b: Vector3, height: float) -> void:
	var dir: Vector3 = b - a
	var length: float = dir.length()
	if length <= 0.01:
		return
	var dirn: Vector3 = dir / length
	var angle: float = rad_to_deg(atan2(-dirn.z, dirn.x))
	var mid: Vector3 = a + dirn * (length * 0.5)

	# muret béton (visuel + collision)
	create_shape({
		"type": "box",
		"position": mid + Vector3(0, 0.45, 0),
		"rotation": Vector3(0, angle, 0),
		"size": Vector3(length, 0.9, 0.45),
		"color": C_CONCRETE_DARK
	})
	# grillage
	create_shape({
		"type": "box",
		"position": mid + Vector3(0, 0.9 + (height - 0.9) * 0.5, 0),
		"rotation": Vector3(0, angle, 0),
		"size": Vector3(length, height - 0.9, 0.12),
		"color": C_METAL_DARK
	})
	# poteaux tous les 4 mètres
	var count: int = maxi(2, int(length / 4.0) + 1)
	for i in range(count):
		var t: float = (float(i) / float(count - 1)) * length
		create_shape({
			"type": "box",
			"position": a + dirn * t + Vector3(0, height * 0.5, 0),
			"rotation": Vector3(0, angle, 0),
			"size": Vector3(0.18, height, 0.18),
			"collision": false,
			"color": C_METAL
		})


# Bloc anti-véhicule / chicane.
func _barrier_block(pos: Vector3, rot_y: float) -> void:
	create_shape({
		"type": "box",
		"position": pos + Vector3(0, 0.55, 0),
		"rotation": Vector3(0, rot_y, 0),
		"size": Vector3(2.4, 1.1, 0.9),
		"color": C_CONCRETE_DARK
	})
	create_shape({
		"type": "box",
		"position": pos + Vector3(0, 1.14, 0),
		"rotation": Vector3(0, rot_y, 0),
		"size": Vector3(2.42, 0.10, 0.92),
		"collision": false,
		"color": C_HAZARD
	})


# Mirador d'angle : position de tir surélevée pour les militaires.
# side_z = +1 ou -1 : côté sur lequel se trouve l'escalier (toujours vers l'intérieur).
func _watchtower(pos: Vector3, height: float, side_z: float) -> void:
	var deck_y: float = height + 0.22          # niveau de la plateforme
	var run: float = 9.0                       # 7.22 m de denivele -> 38.7 deg de pente,
											   # sous les 45 deg de floor_max_angle

	for sx in [-1.6, 1.6]:
		for sz in [-1.6, 1.6]:
			_pillar(pos + Vector3(float(sx), 0, float(sz)), height, 0.18, C_METAL_DARK)
	_slab(pos + Vector3(0, deck_y, 0), 4.4, 4.4, 0.22, C_METAL_DARK)

	# trouée du garde-corps face à l'arrivée de l'escalier
	var gap: Array = [{"at": 2.2, "width": 1.8, "height": 1.05}]
	if side_z > 0.0:
		_parapet(pos, 4.4, 4.4, deck_y, 1.05, C_METAL, {"s": gap})
	else:
		_parapet(pos, 4.4, 4.4, deck_y, 1.05, C_METAL, {"n": gap})

	_slab(pos + Vector3(0, height + 3.16, 0), 5.0, 5.0, 0.16, C_ROOF)
	for sx in [-2.0, 2.0]:
		for sz in [-2.0, 2.0]:
			_pillar(pos + Vector3(float(sx), deck_y, float(sz)), 2.8, 0.09, C_METAL)

	# l'escalier monte vers la tour et débouche au ras de la plateforme
	_stairs(pos + Vector3(0, 0, side_z * (2.2 + run)), deck_y, run, 1.3,
		Vector3(0, 0, -side_z))
	create_light({
		"type": "spot",
		"position": pos + Vector3(0, height + 2.6, 0),
		"rotation": Vector3(-55, 0, 0),
		"color": E_COLD,
		"energy": 4.0,
		"range": 30.0,
		"spot_angle": 35.0
	})


# ==================================================
# AMEUBLEMENT DES LOGEMENTS
# ==================================================

# Repère local d'un logement : origine au centre, +Z vers la fenêtre,
# -Z vers la porte donnant sur le couloir. facing vaut +1 ou -1 selon
# le côté du couloir où se trouve le logement, ce qui suffit à retourner
# tout l'aménagement (le mobilier est volontairement aligné sur les axes).
func _ap(center: Vector3, facing: float, x: float, y: float, z: float) -> Vector3:
	return center + Vector3(x, y, facing * z)


func _box(pos: Vector3, size: Vector3, color: Color, with_col: bool = true) -> void:
	create_shape({
		"type": "box",
		"position": pos,
		"size": size,
		"collision": with_col,
		"color": color
	})


func _glow(pos: Vector3, size: Vector3, color: Color, emit: Color, energy: float) -> void:
	create_shape({
		"type": "box",
		"position": pos,
		"size": size,
		"collision": false,
		"color": color,
		"emission_color": emit,
		"emission_energy": energy
	})


# Meuble un logement de 7 x 7 m. variant fait varier tissus, écran et détails
# pour que les dix appartements ne soient pas dix copies identiques.
func _furnish_apartment(center: Vector3, facing: float, variant: int) -> void:
	var fabrics: Array = [C_FABRIC_A, C_FABRIC_B, C_FABRIC_C]
	var sofa_color: Color = fabrics[variant % 3]
	var tv_on: bool = (variant % 2) == 0

	# ---------- cloison de la chambre ----------
	# mur en Z = 0.6 (avec porte), et retour en X = 0.2
	_wall(_ap(center, facing, -3.5, 0, 0.6), _ap(center, facing, 0.2, 0, 0.6),
		FLOOR_H, 0.16, C_PANEL_WORN, [{"at": 3.1, "width": 0.95, "height": 2.1}])
	_wall(_ap(center, facing, 0.2, 0, 0.6), _ap(center, facing, 0.2, 0, 3.5),
		FLOOR_H, 0.16, C_PANEL_WORN)

	# ---------- séjour ----------
	# tapis
	_box(_ap(center, facing, 1.9, 0.02, 2.0), Vector3(2.8, 0.03, 2.2), C_RUG, false)

	# canapé contre le mur droit, face à l'écran
	_box(_ap(center, facing, 3.0, 0.22, 2.0), Vector3(0.9, 0.42, 2.4), sofa_color)
	_box(_ap(center, facing, 3.38, 0.68, 2.0), Vector3(0.18, 0.55, 2.4), sofa_color)
	_box(_ap(center, facing, 3.0, 0.55, 0.9), Vector3(0.85, 0.18, 0.35), sofa_color, false)

	# table basse
	_box(_ap(center, facing, 1.9, 0.36, 2.0), Vector3(0.7, 0.06, 1.2), C_WOOD, true)
	for sx in [-0.28, 0.28]:
		for sz in [-0.5, 0.5]:
			_box(_ap(center, facing, 1.9 + float(sx), 0.17, 2.0 + float(sz)),
				Vector3(0.06, 0.34, 0.06), C_METAL_DARK, false)

	# meuble télé adossé à la cloison
	_box(_ap(center, facing, 0.5, 0.25, 2.0), Vector3(0.4, 0.5, 1.7), C_METAL_DARK)
	if tv_on:
		_glow(_ap(center, facing, 0.76, 1.20, 2.0), Vector3(0.05, 0.72, 1.4),
			C_SCREEN, E_COLD, 1.6)
	else:
		_box(_ap(center, facing, 0.76, 1.20, 2.0), Vector3(0.05, 0.72, 1.4), C_SCREEN, false)

	# bibliothèque dans l'entrée
	_box(_ap(center, facing, -3.20, 0.95, -1.10), Vector3(0.40, 1.90, 1.40), C_WOOD_LIGHT)
	for i in range(3):
		_box(_ap(center, facing, -3.05, 0.55 + float(i) * 0.55, -1.10),
			Vector3(0.16, 0.28, 1.10), C_WOOD, false)

	# ---------- coin repas ----------
	_box(_ap(center, facing, 1.2, 0.72, -1.5), Vector3(1.5, 0.08, 0.9), C_WOOD)
	for sx in [-0.65, 0.65]:
		for sz in [-0.35, 0.35]:
			_box(_ap(center, facing, 1.2 + float(sx), 0.34, -1.5 + float(sz)),
				Vector3(0.07, 0.68, 0.07), C_METAL_DARK, false)
	for sx in [-0.75, 0.75]:
		var cx: float = 1.2 + float(sx)
		_box(_ap(center, facing, cx, 0.22, -1.5), Vector3(0.44, 0.44, 0.44), C_METAL_DARK)
		_box(_ap(center, facing, cx, 0.66, -1.5 + (0.19 if sx < 0.0 else -0.19)),
			Vector3(0.44, 0.44, 0.06), C_WOOD, false)

	# ---------- cuisine, le long du mur d'entrée ----------
	_box(_ap(center, facing, 2.15, 0.45, -3.10), Vector3(2.5, 0.90, 0.60), C_PANEL)
	_box(_ap(center, facing, 2.15, 0.93, -3.10), Vector3(2.6, 0.06, 0.66), C_APPLIANCE, false)
	_box(_ap(center, facing, 2.15, 1.95, -3.25), Vector3(2.5, 0.70, 0.35), C_PANEL_WORN)
	_box(_ap(center, facing, 1.40, 0.94, -3.10), Vector3(0.50, 0.06, 0.42), C_METAL, false)
	_box(_ap(center, facing, 1.40, 1.15, -3.32), Vector3(0.05, 0.40, 0.05), C_METAL, false)

	# réfrigérateur, à gauche de la porte
	_box(_ap(center, facing, -2.95, 0.95, -3.05), Vector3(0.75, 1.90, 0.70), C_APPLIANCE)
	_box(_ap(center, facing, -2.57, 1.20, -3.05), Vector3(0.04, 0.60, 0.05), C_METAL_DARK, false)

	# meuble d'entrée
	_box(_ap(center, facing, -1.65, 0.45, -3.20), Vector3(1.20, 0.90, 0.45), C_WOOD_LIGHT)

	# ---------- chambre ----------
	# Emprise utile : x de -3.37 a 0.12, z de 0.68 a 3.37.
	# La porte de la chambre s'ouvre entre x = -0.875 et x = 0.075 : cet axe
	# reste totalement libre jusqu'au mur du fond.
	# lit plaque contre le mur gauche
	_box(_ap(center, facing, -2.55, 0.18, 2.35), Vector3(1.55, 0.36, 2.05), C_WOOD)
	_box(_ap(center, facing, -2.55, 0.47, 2.35), Vector3(1.48, 0.24, 1.98), C_LINEN, false)
	_box(_ap(center, facing, -2.55, 0.66, 3.15), Vector3(1.20, 0.14, 0.42), C_APPLIANCE, false)
	_box(_ap(center, facing, -2.55, 0.44, 1.60), Vector3(1.50, 0.06, 0.90),
		fabrics[(variant + 1) % 3], false)

	# table de chevet et lampe, entre le lit et l'armoire
	_box(_ap(center, facing, -1.45, 0.26, 3.05), Vector3(0.50, 0.52, 0.45), C_WOOD)
	_glow(_ap(center, facing, -1.45, 0.66, 3.05), Vector3(0.22, 0.28, 0.22),
		C_LINEN, E_WARM, 1.4)

	# armoire dans l'angle du fond, hors de l'axe de la porte
	_box(_ap(center, facing, -0.35, 1.05, 3.05), Vector3(0.90, 2.10, 0.58), C_WOOD_LIGHT)
	_box(_ap(center, facing, -0.10, 1.05, 2.74), Vector3(0.04, 1.90, 0.04), C_METAL_DARK, false)

	# bureau : deplace dans le sejour, adosse a la cloison de la chambre
	_box(_ap(center, facing, -2.20, 0.74, 0.24), Vector3(1.30, 0.06, 0.50), C_WOOD)
	for sx in [-0.58, 0.58]:
		_box(_ap(center, facing, -2.20 + float(sx), 0.37, 0.24),
			Vector3(0.06, 0.68, 0.46), C_METAL_DARK, false)

	# ---------- plafonniers ----------
	_glow(_ap(center, facing, 1.6, 3.12, 0.0), Vector3(0.90, 0.06, 0.90),
		C_LINEN, E_WARM, 2.0)
	_glow(_ap(center, facing, -1.8, 3.12, 2.2), Vector3(0.60, 0.06, 0.60),
		C_LINEN, E_WARM, 1.2)

	# ---------- détails variables ----------
	if variant % 3 == 0:
		for i in range(2):
			_box(_ap(center, facing, -3.05, 0.30 + float(i) * 0.62, -2.20),
				Vector3(0.60, 0.60, 0.60), C_ACCENT)
	if variant % 4 == 1:
		_box(_ap(center, facing, -2.42, 0.40, -3.15), Vector3(0.30, 0.80, 0.30), C_METAL_DARK)


# ==================================================
# BÂTIMENTS
# ==================================================

# Bloc résidentiel : couloir central, 5 logements de chaque côté.
# Toit accessible par escaliers extérieurs — position de tir pendant l'assaut.
func build_residential_block(c: Vector3) -> void:
	var total_x: float = float(APT_COUNT) * APT_W          # 35
	var total_z: float = APT_D * 2.0 + CORRIDOR_W          # 17
	var hx: float = total_x * 0.5
	var hz: float = total_z * 0.5
	var cz: float = CORRIDOR_W * 0.5                       # 1.5

	# sol et toiture — center.y = niveau de marche (voir _slab)
	var roof_y: float = FLOOR_H + 0.3
	_slab(c + Vector3(0, FLOOR_TOP, 0), total_x + 0.6, total_z + 0.6, 0.2, C_CONCRETE)
	_slab(c + Vector3(0, roof_y, 0), total_x + 0.6, total_z + 0.6, 0.3, C_CONCRETE_DARK)

	# façades longues, fermées
	_wall(c + Vector3(-hx, 0, -hz), c + Vector3(hx, 0, -hz), FLOOR_H, WALL_T, C_PANEL)
	_wall(c + Vector3(-hx, 0,  hz), c + Vector3(hx, 0,  hz), FLOOR_H, WALL_T, C_PANEL)

	# pignons : une porte au centre = entrée du couloir
	_wall(c + Vector3(-hx, 0, -hz), c + Vector3(-hx, 0, hz), FLOOR_H, WALL_T, C_PANEL_WORN,
		[{"at": hz, "width": 2.6, "height": 2.6}])
	_wall(c + Vector3(hx, 0, -hz), c + Vector3(hx, 0, hz), FLOOR_H, WALL_T, C_PANEL_WORN,
		[{"at": hz, "width": 2.6, "height": 2.6}])

	# murs du couloir, une porte par logement
	var doors: Array = []
	for i in range(APT_COUNT):
		doors.append({"at": (float(i) + 0.5) * APT_W, "width": DOOR_W, "height": DOOR_H})
	_wall(c + Vector3(-hx, 0, -cz), c + Vector3(hx, 0, -cz), FLOOR_H, WALL_T, C_PANEL_WORN, doors)
	_wall(c + Vector3(-hx, 0,  cz), c + Vector3(hx, 0,  cz), FLOOR_H, WALL_T, C_PANEL_WORN, doors)

	# refends entre logements
	for i in range(1, APT_COUNT):
		var x: float = c.x - hx + float(i) * APT_W
		_wall(Vector3(x, c.y, c.z - hz), Vector3(x, c.y, c.z - cz), FLOOR_H, WALL_T, C_PANEL_WORN)
		_wall(Vector3(x, c.y, c.z + cz), Vector3(x, c.y, c.z + hz), FLOOR_H, WALL_T, C_PANEL_WORN)

	# baies vitrées et éclairage par logement
	for i in range(APT_COUNT):
		var xc: float = c.x - hx + (float(i) + 0.5) * APT_W
		_window(Vector3(xc - 2.4, c.y, c.z - hz - 0.10), Vector3(xc + 2.4, c.y, c.z - hz - 0.10), 1.0, 1.5, 0.45)
		_window(Vector3(xc - 2.4, c.y, c.z + hz + 0.10), Vector3(xc + 2.4, c.y, c.z + hz + 0.10), 1.0, 1.5, 0.45)
		create_light({"type": "omni", "position": Vector3(xc, c.y + 2.7, c.z - 4.8),
			"color": E_WARM, "energy": 1.6, "range": 6.5})
		create_light({"type": "omni", "position": Vector3(xc, c.y + 2.7, c.z + 4.8),
			"color": E_WARM, "energy": 1.6, "range": 6.5})
		create_light({"type": "omni", "position": Vector3(xc, c.y + 2.9, c.z),
			"color": E_COLD, "energy": 1.2, "range": 6.0})

		# ameublement des deux logements de la travée
		# nord : la fenêtre est en -Z, donc le repère local est retourné
		_furnish_apartment(Vector3(xc, c.y + FLOOR_TOP, c.z - 5.0), -1.0, i)
		_furnish_apartment(Vector3(xc, c.y + FLOOR_TOP, c.z + 5.0),  1.0, i + 2)

	# toit : parapet, panneaux solaires, blocs techniques
	# bord réel de la dalle de toit (elle déborde de 0,3 m sur les façades)
	var edge_x: float = (total_x + 0.6) * 0.5    # 17.8
	var edge_z: float = (total_z + 0.6) * 0.5    # 8.8
	# les deux escaliers arrivent en x = -11.5 (côté nord) et x = +11.5 (côté sud)
	_parapet(c, total_x + 0.6, total_z + 0.6, c.y + roof_y, PARAPET_H, C_PANEL_WORN, {
		"n": [{"at": edge_x - 11.5, "width": 2.4, "height": PARAPET_H}],
		"s": [{"at": edge_x + 11.5, "width": 2.4, "height": PARAPET_H}]
	})
	_solar_field(c + Vector3(-8.0, roof_y, 0), 7, 5)
	_solar_field(c + Vector3( 8.0, roof_y, 0), 7, 5)
	_roof_unit(c + Vector3(0, roof_y, -6.0))
	_roof_unit(c + Vector3(0, roof_y,  6.0))

	# accès toit : deux escaliers perpendiculaires aux façades.
	# La dernière marche affleure la dalle, pile en face de la trouée du parapet.
	_stairs(c + Vector3(-11.5, 0, -edge_z - 5.0), roof_y, 5.0, 1.6, Vector3(0, 0, 1))
	_stairs(c + Vector3( 11.5, 0,  edge_z + 5.0), roof_y, 5.0, 1.6, Vector3(0, 0, -1))

	# auvents d'entrée
	for sx in [-1.0, 1.0]:
		var s: float = float(sx)
		create_shape({
			"type": "box",
			"position": c + Vector3(s * (hx + 1.1), 2.75, 0),
			"size": Vector3(2.2, 0.16, 3.4),
			"color": C_ROOF
		})
		create_shape({
			"type": "box",
			"position": c + Vector3(s * (hx + 0.25), 2.95, 0),
			"size": Vector3(0.08, 0.35, 2.2),
			"collision": false,
			"color": C_ACCENT,
			"emission_color": E_ALERT,
			"emission_energy": 1.2
		})


# Centre technique : halle de production, salle de contrôle, cour transfo.
func build_power_center(c: Vector3) -> void:
	var hall_x: float = 26.0
	var hall_z: float = 16.0
	var hall_h: float = 9.0
	var hx: float = hall_x * 0.5
	var hz: float = hall_z * 0.5

	var roof_y: float = hall_h + 0.35   # niveau de marche du toit

	# halle
	_slab(c + Vector3(0, FLOOR_TOP, 0), hall_x + 0.6, hall_z + 0.6, 0.25, C_CONCRETE_DARK)
	_wall(c + Vector3(-hx, 0, -hz), c + Vector3(hx, 0, -hz), hall_h, 0.35, C_PANEL)
	_wall(c + Vector3(-hx, 0,  hz), c + Vector3(hx, 0,  hz), hall_h, 0.35, C_PANEL)
	# porte de halle côté place (ouest)
	_wall(c + Vector3(-hx, 0, -hz), c + Vector3(-hx, 0, hz), hall_h, 0.35, C_PANEL_WORN,
		[{"at": hz, "width": 6.0, "height": 5.0}])
	_wall(c + Vector3(hx, 0, -hz), c + Vector3(hx, 0, hz), hall_h, 0.35, C_PANEL_WORN,
		[{"at": hz, "width": DOOR_W, "height": DOOR_H}])
	_slab(c + Vector3(0, roof_y, 0), hall_x + 0.8, hall_z + 0.8, 0.35, C_ROOF)

	# nervures verticales sur les façades — lecture industrielle
	for i in range(1, 7):
		var x: float = c.x - hx + float(i) * (hall_x / 7.0)
		for sz in [-1.0, 1.0]:
			create_shape({
				"type": "box",
				"position": Vector3(x, c.y + hall_h * 0.5, c.z + float(sz) * (hz + 0.24)),
				"size": Vector3(0.35, hall_h, 0.12),
				"collision": false,
				"color": C_METAL_DARK
			})

	# bandeau vitré haut
	_window(c + Vector3(-hx + 2.0, 0, -hz - 0.26), c + Vector3(hx - 2.0, 0, -hz - 0.26), 6.2, 1.4, 0.3)

	# intérieur : piliers, machines, écrans
	for i in range(1, 4):
		var x2: float = c.x - hx + float(i) * (hall_x / 4.0)
		_pillar(Vector3(x2, c.y + FLOOR_TOP, c.z - 4.0), hall_h - FLOOR_TOP, 0.26, C_METAL)
		_pillar(Vector3(x2, c.y + FLOOR_TOP, c.z + 4.0), hall_h - FLOOR_TOP, 0.26, C_METAL)
	for i in range(4):
		var xm: float = c.x - 10.0 + float(i) * 6.0
		create_shape({
			"type": "box",
			"position": Vector3(xm, c.y + FLOOR_TOP + 1.10, c.z - 5.5),
			"size": Vector3(4.0, 2.2, 2.0),
			"color": C_METAL
		})
		create_shape({
			"type": "box",
			"position": Vector3(xm, c.y + FLOOR_TOP + 1.85, c.z - 4.45),
			"size": Vector3(1.6, 0.7, 0.06),
			"collision": false,
			"color": C_SCREEN,
			"emission_color": E_COLD,
			"emission_energy": 1.4
		})
		create_light({"type": "omni", "position": Vector3(xm, c.y + 7.0, c.z),
			"color": E_COLD, "energy": 2.4, "range": 12.0})

	# annexe salle de contrôle, accolée à l'est
	var ax: float = c.x + hx + 5.0
	create_shape({
		"type": "box",
		"position": Vector3(ax, c.y + 3.4, c.z),
		"size": Vector3(10.0, 6.8, 9.0),
		"color": C_PANEL_WORN
	})
	_slab(Vector3(ax, c.y + 7.1, c.z), 10.6, 9.6, 0.3, C_ROOF)
	_window(Vector3(ax - 4.0, c.y, c.z + 4.6), Vector3(ax + 4.0, c.y, c.z + 4.6), 4.4, 1.8, 0.6)
	_window(Vector3(ax - 4.0, c.y, c.z - 4.6), Vector3(ax + 4.0, c.y, c.z - 4.6), 4.4, 1.8, 0.6)

	# cour technique : transformateurs et tours de refroidissement
	for i in range(3):
		var zt: float = c.z - 5.0 + float(i) * 5.0
		create_shape({
			"type": "cylinder",
			"position": Vector3(c.x, c.y + 1.6, zt - hz - 8.0),
			"size": Vector3(2.6, 3.2, 2.6),
			"color": C_METAL
		})
		create_shape({
			"type": "box",
			"position": Vector3(c.x, c.y + 3.5, zt - hz - 8.0),
			"size": Vector3(1.8, 0.6, 1.8),
			"collision": false,
			"color": C_METAL_DARK
		})
	for i in range(2):
		create_shape({
			"type": "cylinder",
			"position": Vector3(c.x - 7.0 + float(i) * 14.0, c.y + 5.0, c.z - hz - 14.0),
			"size": Vector3(4.2, 10.0, 4.2),
			"color": C_CONCRETE
		})

	# toit : panneaux solaires, mât de communication, accès
	var edge_x: float = (hall_x + 0.8) * 0.5     # 13.4
	var edge_z: float = (hall_z + 0.8) * 0.5     # 8.4
	_parapet(c, hall_x + 0.8, hall_z + 0.8, c.y + roof_y, 1.0, C_METAL_DARK, {
		"s": [{"at": edge_x - 8.0, "width": 2.6, "height": 1.0}]
	})
	# panneaux décalés vers le nord pour dégager l'arrivée de l'escalier
	_solar_field(c + Vector3(0, roof_y, -1.2), 10, 5)
	_pillar(c + Vector3(hx - 2.0, roof_y, -hz + 2.0), 7.0, 0.16, C_METAL_DARK)
	create_shape({
		"type": "sphere",
		"position": c + Vector3(hx - 2.0, roof_y + 7.2, -hz + 2.0),
		"size": Vector3(0.7, 0.7, 0.7),
		"collision": false,
		"color": C_ACCENT,
		"emission_color": E_ALERT,
		"emission_energy": 3.0
	})
	# 9,35 m de dénivelé : volée longue pour rester praticable
	_stairs(c + Vector3(-8.0, 0, edge_z + 14.0), roof_y, 14.0, 1.6, Vector3(0, 0, -1))


# Atelier / dépôt : petit volume, sert de repère et de couverture.
func build_workshop(c: Vector3) -> void:
	var sx: float = 16.0
	var sz: float = 10.0
	var h: float = 5.0

	_slab(c + Vector3(0, FLOOR_TOP, 0), sx + 0.4, sz + 0.4, 0.2, C_CONCRETE_DARK)
	_wall(c + Vector3(-sx * 0.5, 0, -sz * 0.5), c + Vector3(sx * 0.5, 0, -sz * 0.5), h, 0.3, C_PANEL_WORN)
	_wall(c + Vector3(-sx * 0.5, 0,  sz * 0.5), c + Vector3(sx * 0.5, 0,  sz * 0.5), h, 0.3, C_PANEL_WORN,
		[{"at": sx * 0.5, "width": 4.0, "height": 3.6}])
	_wall(c + Vector3(-sx * 0.5, 0, -sz * 0.5), c + Vector3(-sx * 0.5, 0, sz * 0.5), h, 0.3, C_PANEL_WORN)
	_wall(c + Vector3( sx * 0.5, 0, -sz * 0.5), c + Vector3( sx * 0.5, 0, sz * 0.5), h, 0.3, C_PANEL_WORN,
		[{"at": sz * 0.5, "width": DOOR_W, "height": DOOR_H}])
	_slab(c + Vector3(0, h + 0.25, 0), sx + 0.6, sz + 0.6, 0.25, C_ROOF)
	_parapet(c, sx + 0.6, sz + 0.6, c.y + h + 0.25, 0.9, C_METAL_DARK)
	_solar_field(c + Vector3(0, h + 0.25, 0), 6, 3)
	create_light({"type": "omni", "position": c + Vector3(0, 4.0, 0),
		"color": E_WARM, "energy": 2.0, "range": 11.0})

	# caisses empilées à l'extérieur
	for i in range(5):
		create_shape({
			"type": "box",
			"position": c + Vector3(-sx * 0.5 - 2.0, 0.6 + float(i % 2) * 1.2, -3.0 + float(i) * 1.6),
			"rotation": Vector3(0, -12.0 + float(i) * 6.0, 0),
			"size": Vector3(1.2, 1.2, 1.2),
			"color": C_ACCENT if i % 3 == 0 else C_METAL_DARK
		})


# Place centrale : dallage, pylône, bancs, mâts d'éclairage.
func build_plaza(c: Vector3, size: float) -> void:
	var h: float = size * 0.5

	_slab(c + Vector3(0, FLOOR_TOP, 0), size, size, 0.15, C_PAVING)

	# bordure surélevée
	for s in [-1.0, 1.0]:
		var sv: float = float(s)
		create_shape({
			"type": "box",
			"position": c + Vector3(sv * h, 0.18, 0),
			"size": Vector3(0.5, 0.36, size),
			"color": C_CONCRETE_DARK
		})
		create_shape({
			"type": "box",
			"position": c + Vector3(0, 0.18, sv * h),
			"size": Vector3(size, 0.36, 0.5),
			"color": C_CONCRETE_DARK
		})
		# biseaux invisibles : la bordure se franchit dans les deux sens.
		# On deborde de 1 m aux extremites pour couvrir les quatre angles.
		_step_ramps(c + Vector3(sv * h, 0, -h - 1.0), c + Vector3(sv * h, 0, h + 1.0),
			0.36, 0.25, 0.9)
		_step_ramps(c + Vector3(-h - 1.0, 0, sv * h), c + Vector3(h + 1.0, 0, sv * h),
			0.36, 0.25, 0.9)

	# pylône central
	create_shape({
		"type": "cylinder",
		"position": c + Vector3(0, 4.5, 0),
		"size": Vector3(1.4, 9.0, 1.4),
		"color": C_METAL
	})
	for i in range(4):
		create_shape({
			"type": "cylinder",
			"position": c + Vector3(0, 1.6 + float(i) * 2.0, 0),
			"size": Vector3(1.6, 0.16, 1.6),
			"collision": false,
			"color": C_ACCENT,
			"emission_color": E_ALERT,
			"emission_energy": 1.8
		})
	create_shape({
		"type": "cone",
		"position": c + Vector3(0, 9.8, 0),
		"size": Vector3(1.8, 1.6, 1.8),
		"collision": false,
		"color": C_METAL_DARK
	})

	# bancs
	for i in range(4):
		var ang: float = deg_to_rad(45.0 + float(i) * 90.0)
		var p: Vector3 = c + Vector3(cos(ang), 0, sin(ang)) * 5.5
		create_shape({
			"type": "box",
			"position": p + Vector3(0, 0.45, 0),
			"rotation": Vector3(0, rad_to_deg(-ang), 0),
			"size": Vector3(2.6, 0.16, 0.6),
			"color": C_METAL_DARK
		})

	# mâts d'angle
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_light_mast(c + Vector3(float(sx) * (h - 2.0), 0, float(sz) * (h - 2.0)), 7.5)

	# panneau d'information
	create_shape({
		"type": "box",
		"position": c + Vector3(-h + 3.0, 1.6, 0),
		"size": Vector3(0.15, 2.0, 3.0),
		"color": C_SCREEN,
		"emission_color": E_COLD,
		"emission_energy": 1.0
	})


# Périmètre défensif : clôture, portails, chicanes, miradors.
func build_perimeter(c: Vector3) -> void:
	var gate_w: float = 8.0

	# côtés nord et sud, coupés par un portail au centre
	for sz in [-1.0, 1.0]:
		var s: float = float(sz)
		var z: float = c.z + s * PERIM_Z
		_fence(Vector3(c.x - PERIM_X, c.y, z), Vector3(c.x - gate_w * 0.5, c.y, z), 3.4)
		_fence(Vector3(c.x + gate_w * 0.5, c.y, z), Vector3(c.x + PERIM_X, c.y, z), 3.4)
		# portique
		for sx in [-1.0, 1.0]:
			_pillar(Vector3(c.x + float(sx) * gate_w * 0.5, c.y, z), 5.5, 0.3, C_METAL_DARK)
		create_shape({
			"type": "box",
			"position": Vector3(c.x, c.y + 5.5, z),
			"size": Vector3(gate_w + 0.8, 0.5, 0.5),
			"color": C_METAL_DARK
		})
		create_shape({
			"type": "box",
			"position": Vector3(c.x, c.y + 5.5, z + s * 0.32),
			"size": Vector3(gate_w - 1.0, 0.32, 0.06),
			"collision": false,
			"color": C_HAZARD,
			"emission_color": E_ALERT,
			"emission_energy": 1.5
		})
		# chicanes
		_barrier_block(Vector3(c.x - 3.5, c.y, z + s * 4.0), 12.0)
		_barrier_block(Vector3(c.x + 3.5, c.y, z + s * 7.0), -12.0)

	# côtés est et ouest, continus
	for sx in [-1.0, 1.0]:
		var x: float = c.x + float(sx) * PERIM_X
		_fence(Vector3(x, c.y, c.z - PERIM_Z), Vector3(x, c.y, c.z + PERIM_Z), 3.4)

	# miradors d'angle
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			# escalier toujours du côté intérieur, sinon il sortirait de l'enceinte
			_watchtower(c + Vector3(float(sx) * (PERIM_X - 4.0), 0, float(sz) * (PERIM_Z - 4.0)),
				7.0, -float(sz))


# Voie de circulation : simple dalle sombre.
func _road(a: Vector3, b: Vector3, width: float) -> void:
	var dir: Vector3 = b - a
	var length: float = dir.length()
	if length <= 0.01:
		return
	var dirn: Vector3 = dir / length
	create_shape({
		"type": "box",
		"position": (a + b) * 0.5 + Vector3(0, 0.02, 0),
		"rotation": Vector3(0, rad_to_deg(atan2(-dirn.z, dirn.x)), 0),
		"size": Vector3(length, 0.06, width),
		"collision": false,
		"color": C_CONCRETE_DARK
	})


# ==================================================
# ASSEMBLAGE DE LA BASE
# ==================================================

func build_base(origin: Vector3) -> void:
	var t0: int = Time.get_ticks_msec()

	build_plaza(origin, 24.0)
	build_residential_block(origin + Vector3(-32.0, 0, 0))
	build_power_center(origin + Vector3(30.0, 0, 0))
	build_workshop(origin + Vector3(0, 0, -26.0))
	build_perimeter(origin)

	_road(origin + Vector3(-13.0, 0, 0), origin + Vector3(-46.0, 0, 0), 6.0)
	_road(origin + Vector3( 13.0, 0, 0), origin + Vector3( 44.0, 0, 0), 6.0)
	_road(origin + Vector3(0, 0, -13.0), origin + Vector3(0, 0, -PERIM_Z), 6.0)
	_road(origin + Vector3(0, 0,  13.0), origin + Vector3(0, 0,  PERIM_Z), 6.0)

	print("[GeometryFactory] Base générée en %d ms — %d nœuds sous '%s'."
		% [Time.get_ticks_msec() - t0, generated_root.get_child_count(), generated_root.get_path()])

	_bake_navigation()


# La géométrie naissant à l'exécution, un navmesh baké dans l'éditeur ne la
# contient pas. On inscrit la racine dans le groupe lu par la NavigationRegion3D,
# puis on relance le bake.
func _bake_navigation() -> void:
	generated_root.add_to_group("navmesh_source")

	var region = get_tree().current_scene.find_child("NavRegion", true, false)
	if region is NavigationRegion3D:
		region.bake_navigation_mesh(true)
		print("[GeometryFactory] Bake du navmesh lancé sur '%s'." % region.get_path())
	else:
		push_warning("[GeometryFactory] Aucun nœud 'NavRegion' de type NavigationRegion3D trouvé — les PNJ ne pourront pas contourner les bâtiments.")


# ==================================================
# PRÉFABS - CONSTRUCTIONS COMPLÈTES
# ==================================================

# Assemble un appartement moderne (2 étages, toit plat, baies vitrées,
# balcon, entrée avec auvent et piliers, éclairage intérieur)
# base_position = coin au sol où l'appartement doit apparaître
func build_modern_apartment(base_position: Vector3) -> void:

	# --- Sol intérieur ---
	create_shape({
		"type": "box",
		"position": base_position + Vector3(0, 0.05, 0),
		"size": Vector3(6, 0.1, 5),
		"color": Color(0.6, 0.55, 0.5)
	})

	# --- Mur arrière ---
	create_shape({
		"type": "box",
		"position": base_position + Vector3(0, 1.5, -2.4),
		"size": Vector3(6, 3, 0.2),
		"color": Color(0.78, 0.76, 0.72)
	})

	# --- Mur gauche ---
	create_shape({
		"type": "box",
		"position": base_position + Vector3(-3, 1.5, 0),
		"size": Vector3(0.2, 3, 5),
		"color": Color(0.78, 0.76, 0.72)
	})

	# --- Mur droit ---
	create_shape({
		"type": "box",
		"position": base_position + Vector3(3, 1.5, 0),
		"size": Vector3(0.2, 3, 5),
		"color": Color(0.78, 0.76, 0.72)
	})

	# --- Mur avant, gauche de l'entrée ---
	create_shape({
		"type": "box",
		"position": base_position + Vector3(-1.8, 1.5, 2.4),
		"size": Vector3(2.4, 3, 0.2),
		"color": Color(0.78, 0.76, 0.72)
	})

	# --- Mur avant, droite de l'entrée ---
	create_shape({
		"type": "box",
		"position": base_position + Vector3(1.8, 1.5, 2.4),
		"size": Vector3(2.4, 3, 0.2),
		"color": Color(0.78, 0.76, 0.72)
	})

	# --- Linteau au-dessus de l'entrée ---
	create_shape({
		"type": "box",
		"position": base_position + Vector3(0, 2.55, 2.4),
		"size": Vector3(1.2, 0.9, 0.2),
		"color": Color(0.78, 0.76, 0.72)
	})

	# --- Étage (inaccessible sans escalier pour l'instant, purement visuel) ---
	create_shape({
		"type": "box",
		"position": base_position + Vector3(0, 4.5, 0),
		"size": Vector3(6, 3, 5),
		"color": Color(0.92, 0.92, 0.9)
	})

	# --- Toit plat ---
	create_shape({
		"type": "box",
		"position": base_position + Vector3(0, 6.15, 0),
		"size": Vector3(6.4, 0.3, 5.4),
		"color": Color(0.18, 0.18, 0.2)
	})

	# --- Baie vitrée façade avant (étage) ---
	create_shape({
		"type": "box",
		"position": base_position + Vector3(0, 3.2, 2.55),
		"size": Vector3(5.4, 4.6, 0.1),
		"collision": false,
		"color": Color(0.55, 0.75, 0.85),
		"emission_color": Color(0.5, 0.75, 1.0),
		"emission_energy": 0.35
	})

	# --- Balcon (dalle) ---
	create_shape({
		"type": "box",
		"position": base_position + Vector3(0, 4.6, 3.2),
		"size": Vector3(3.2, 0.2, 1.4),
		"color": Color(0.78, 0.76, 0.72)
	})

	# --- Balcon (garde-corps vitré) ---
	create_shape({
		"type": "box",
		"position": base_position + Vector3(0, 5.1, 3.85),
		"size": Vector3(3.2, 0.9, 0.06),
		"collision": false,
		"color": Color(0.6, 0.75, 0.85),
		"emission_color": Color(0.5, 0.7, 0.9),
		"emission_energy": 0.2
	})

	# --- Auvent au-dessus de l'entrée ---
	create_shape({
		"type": "box",
		"position": base_position + Vector3(0, 2.3, 3.0),
		"size": Vector3(2.2, 0.15, 1.0),
		"color": Color(0.18, 0.18, 0.2)
	})

	# --- Piliers de l'auvent ---
	create_shape({
		"type": "cylinder",
		"position": base_position + Vector3(-1.0, 1.15, 3.4),
		"size": Vector3(0.25, 2.3, 0.25),
		"color": Color(0.92, 0.92, 0.9)
	})
	create_shape({
		"type": "cylinder",
		"position": base_position + Vector3(1.0, 1.15, 3.4),
		"size": Vector3(0.25, 2.3, 0.25),
		"color": Color(0.92, 0.92, 0.9)
	})

	# --- Éclairage intérieur ---
	create_light({
		"type": "omni",
		"position": base_position + Vector3(0, 1.6, 0),
		"color": Color(1.0, 0.85, 0.6),
		"energy": 1.0,
		"range": 5.0
	})
	create_light({
		"type": "omni",
		"position": base_position + Vector3(0, 4.6, 0),
		"color": Color(1.0, 0.85, 0.6),
		"energy": 1.0,
		"range": 5.0
	})

	# ==================================================
	# MOBILIER (rez-de-chaussée)
	# ==================================================

	# --- Canapé ---
	create_shape({
		"type": "box",
		"position": base_position + Vector3(-1.5, 0.25, -1.9),
		"size": Vector3(1.8, 0.5, 0.8),
		"color": Color(0.15, 0.2, 0.35)
	})
	create_shape({
		"type": "box",
		"position": base_position + Vector3(-1.5, 0.75, -2.25),
		"size": Vector3(1.8, 0.6, 0.15),
		"color": Color(0.15, 0.2, 0.35)
	})

	# --- Table basse ---
	create_shape({
		"type": "box",
		"position": base_position + Vector3(-1.5, 0.175, -1.0),
		"size": Vector3(1.0, 0.35, 0.5),
		"color": Color(0.35, 0.22, 0.12)
	})

	# --- Meuble TV + écran ---
	create_shape({
		"type": "box",
		"position": base_position + Vector3(2.6, 0.25, -1.5),
		"size": Vector3(0.4, 0.5, 1.2),
		"color": Color(0.15, 0.15, 0.15)
	})
	create_shape({
		"type": "box",
		"position": base_position + Vector3(2.75, 1.0, -1.5),
		"size": Vector3(0.05, 0.6, 1.1),
		"collision": false,
		"color": Color(0.05, 0.05, 0.08),
		"emission_color": Color(0.3, 0.5, 0.9),
		"emission_energy": 0.5
	})

	# --- Comptoir de cuisine ---
	create_shape({
		"type": "box",
		"position": base_position + Vector3(2.5, 0.45, 1.0),
		"size": Vector3(0.6, 0.9, 2.0),
		"color": Color(0.85, 0.85, 0.82)
	})

	# --- Table à manger + 2 chaises ---
	create_shape({
		"type": "box",
		"position": base_position + Vector3(1.0, 0.375, 1.7),
		"size": Vector3(1.0, 0.75, 0.7),
		"color": Color(0.35, 0.22, 0.12)
	})
	create_shape({
		"type": "box",
		"position": base_position + Vector3(0.5, 0.225, 1.3),
		"size": Vector3(0.4, 0.45, 0.4),
		"color": Color(0.2, 0.2, 0.2)
	})
	create_shape({
		"type": "box",
		"position": base_position + Vector3(1.5, 0.225, 1.3),
		"size": Vector3(0.4, 0.45, 0.4),
		"color": Color(0.2, 0.2, 0.2)
	})


# ==================================================
# UTILITAIRES
# ==================================================

func clear_all() -> void:
	for c in generated_root.get_children():
		c.queue_free()
