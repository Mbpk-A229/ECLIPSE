extends Control

@onready var overlay = $Overlay
@onready var vbox = $VBoxContainer
@onready var text_label = $VBoxContainer/TextLabel
@onready var continue_button = $VBoxContainer/ContinueButton

const INTRO_TEXT = "[center][b]Thursday, March 14th, 2157[/b]

[i]Containment Zone — Base Beta[/i]
[i]High-Security Solar Power Plant — Omega Sector[/i]

You are part of an elite adventurer unit assigned to Base Beta, one of the last solar power plants still operational in this ravaged world.

For several days now, perimeter sensors have been detecting disturbing anomalies. Hordes of infected and mutated creatures are growing in number, and increasingly aggressive.

Reinforcements will not come.

[b]You are alone.[/b]

[i]Will you survive the invasions that lie ahead?[/i][/center]"

func _ready() -> void:
	overlay.visible = false
	vbox.visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	# on attend 3 secondes sur l'image puis on affiche le texte
	await get_tree().create_timer(3.0).timeout
	_show_intro()

func _show_intro() -> void:
	# fondu de l'overlay
	overlay.visible = true
	overlay.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 1.5)
	await tween.finished
	# affichage du texte et du bouton
	vbox.visible = true
	text_label.text = INTRO_TEXT

@onready var progress_bar = $ProgressBar  # a ajouter dans la scene
@onready var loading_label = $LoadingLabel  # a ajouter dans la scene

var is_loading : bool = false

func _on_continue_pressed() -> void:
	continue_button.visible = false
	progress_bar.visible = true
	loading_label.visible = true
	loading_label.text = "Loading..."
	# démarrage du chargement en arrière-plan
	ResourceLoader.load_threaded_request("res://game/node_3d.tscn")
	is_loading = true

func _process(_delta: float) -> void:
	if not is_loading:
		return
	var progress = []
	var status = ResourceLoader.load_threaded_get_status("res://game/node_3d.tscn", progress)
	if progress.size() > 0:
		progress_bar.value = progress[0] * 100
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			loading_label.text = "Loading... " + str(int(progress_bar.value)) + "%"
		ResourceLoader.THREAD_LOAD_LOADED:
			is_loading = false
			var scene = ResourceLoader.load_threaded_get("res://game/node_3d.tscn")
			get_tree().change_scene_to_packed(scene)
		ResourceLoader.THREAD_LOAD_FAILED:
			loading_label.text = "Erreur de chargement !"
