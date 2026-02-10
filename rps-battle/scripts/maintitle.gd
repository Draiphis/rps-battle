extends Control

# Préchargement des scènes
#var GameModeScene = preload("res://GameMode.tscn") # écran "vs joueur / vs IA / tutoriel"
var CollectionScene = preload("res://scenes/Collection.tscn") # scène de la collection de cartes

func _ready():
	$VBoxContainer/Jouer.connect("pressed", Callable(self, "_on_jouer_pressed"))
	$VBoxContainer/Collection.connect("pressed", Callable(self, "_on_collection_pressed"))
	$VBoxContainer/Quitter.connect("pressed", Callable(self, "_on_quitter_pressed"))

func _on_jouer_pressed():
	pass

func _on_collection_pressed():
	# Charge la collection du joueur
	get_tree().change_scene_to(CollectionScene)

func _on_quitter_pressed():
	get_tree().quit()
