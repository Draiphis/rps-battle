extends Control

# Toutes les ressources .tres
@export var cards: Array[displayCard]

# GridContainer pour la collection
@onready var grid = $ScrollContainer/CardsGrid

# Card.tscn pour instancier chaque carte
@export var card_scene: PackedScene

# Decks en mémoire
var decks := [Deck.new(), Deck.new()]
var current_deck_index := 0

# Panels pour mini-cartes
@onready var deck_panels = [
	$DeckPanel/ListeDecks/VBoxContainer/Deck1,
	$DeckPanel/ListeDecks/VBoxContainer2/Deck2,
]

# Labels pour les compteurs
@onready var deck_labels = [
	$DeckPanel/ListeDecks/VBoxContainer/Compteur1,
	$DeckPanel/ListeDecks/VBoxContainer2/Compteur2,
]

# Chevauchement des mini-cartes
var overlap := 0.95


func _ready():
	# Initialisation des decks
	load_all_decks()
	for i in range(decks.size()):
		decks[i].name = "Deck %d" % (i + 1)

	# Connecter les boutons de sélection des decks
	$DeckPanel/ListeDecks/VBoxContainer/ButtonDeck1.pressed.connect(Callable(self, "_on_select_deck").bind(0))
	$DeckPanel/ListeDecks/VBoxContainer2/ButtonDeck2.pressed.connect(Callable(self, "_on_select_deck").bind(1))
	
	# Créer toutes les cartes de la collection
	for c in cards:
		var card_instance = card_scene.instantiate() as Card
		card_instance.set_card(c)
		card_instance.set_display_size(Card.CardSize.NORMAL)
		grid.add_child(card_instance)
		card_instance.card_selected.connect(Callable(self, "_on_card_selected"))

	# Afficher le deck actif au démarrage
	_refresh_deck_panel(current_deck_index)
	_update_card_count(current_deck_index)


# Sélection du deck actif
func _on_select_deck(deck_index: int):
	current_deck_index = deck_index
	_refresh_deck_panel(deck_index)
	_update_card_count(deck_index)
	print("Deck sélectionné :", deck_index + 1)


# Ajouter une carte au deck actif
func _on_card_selected(card_id: String):
	var active_deck = decks[current_deck_index]

	if active_deck.cards.size() >= active_deck.max_cards:
		print("Deck plein")
		return

	active_deck.cards.append(card_id)
	print("Carte ajoutée au deck", current_deck_index + 1, ":", card_id)

	_refresh_deck_panel(current_deck_index)
	_update_card_count(current_deck_index)
	save_all_decks()


# Rafraîchir l'affichage des mini-cartes d'un deck
func _refresh_deck_panel(deck_index: int):
	var active_deck = decks[deck_index]
	var panel = deck_panels[deck_index]

	# Supprime toutes les anciennes mini-cartes
	for child in panel.get_children():
		child.queue_free()

	# Taille mini de base (ratio MINI défini dans Card.gd)
	var mini_size = Vector2(200, 280) * 0.4  # normal_size * ratio MINI
	var card_width_effective = mini_size.x
	var card_height_effective = mini_size.y
	var offset_x = card_width_effective * (1.0 - overlap)

	# Créer les mini-cartes
	for n in range(active_deck.cards.size()):
		var card_id = active_deck.cards[n]
		var card_res: displayCard = null
		for c in cards:
			if c.id == card_id:
				card_res = c
				break
		if card_res == null:
			continue

		# Instancie la carte mini
		var mini_card = card_scene.instantiate() as Card
		mini_card.set_card(card_res)
		mini_card.set_display_size(Card.CardSize.MINI)

		# Position horizontale pour empilement
		mini_card.position = Vector2(n * offset_x, 0)
		panel.add_child(mini_card)

	# Ajuste la largeur du panel pour que le scroll fonctionne
	var total_width = max(card_width_effective, active_deck.cards.size() * offset_x + card_width_effective)
	panel.custom_minimum_size = Vector2(total_width, card_height_effective)


# Mettre à jour le compteur de cartes pour un deck
func _update_card_count(deck_index: int):
	var active_deck = decks[deck_index]
	deck_labels[deck_index].text = "Cartes : %d / %d" % [active_deck.cards.size(), active_deck.max_cards]


# Sauvegarder tous les decks
func save_all_decks():
	var dir_path = "res://decks/"

	# Crée une instance de DirAccess
	var dir = DirAccess.open("res://")
	if dir == null:
		print("Impossible d'ouvrir le dossier res://")
		return

	# Crée le dossier 'decks' si nécessaire
	var err = dir.make_dir_recursive("res://decks/")
	if err != OK:
		print("Impossible de créer le dossier:", dir_path)

	# Sauvegarde chaque deck
	for i in range(decks.size()):
		var filename = dir_path + "deck" + str(i + 1) + ".tres"
		ResourceSaver.save(decks[i], filename)

	print("Tous les decks sauvegardés !")




# Charger tous les decks
func load_all_decks():
	var dir_path = "res://decks/"
	var dir = DirAccess.open(dir_path)
	if dir != null:
		for i in range(decks.size()):
			var path = dir_path + "deck" + str(i + 1) + ".tres"
			if FileAccess.file_exists(path):
				decks[i] = load(path)

	# Rafraîchir tous les panels et compteurs
	for i in range(decks.size()):
		_refresh_deck_panel(i)
		_update_card_count(i)

	print("Tous les decks chargés !")
