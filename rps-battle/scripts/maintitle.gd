extends Control

# Préchargement des scènes


func _ready():
	$Jouer.connect("pressed", Callable(self, "_on_jouer_pressed"))
	$Collection.connect("pressed", Callable(self, "_on_collection_pressed"))
	$Quitter.connect("pressed", Callable(self, "_on_quitter_pressed"))

func _on_jouer_pressed():
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_collection_pressed():
	# Charge la collection du joueur
	get_tree().change_scene_to_file("res://scenes/collection.tscn") # chemin vers la collection

func _on_quitter_pressed():
	get_tree().quit()
