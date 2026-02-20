extends Control

var player_deck := GameDeck.new()
var enemy_deck := GameDeck.new()
var card_waiting_for_summon : Card = null

@export var card_scene: PackedScene
@onready var player_hand = $VBoxContainer/PlayerHand/PlayerHand
@onready var enemy_hand = $VBoxContainer/EnnemyHand/EnnemyHand
@onready var zoom_layer = $ZoomLayer
@onready var zoom_background = $ZoomLayer/Background
@onready var player_deck_zone = $PlayerDeckZone
@onready var enemy_deck_zone = $EnnemyDeckZone
@onready var player_deck_label = $PlayerDeckZone/NbCard
@onready var enemy_deck_label = $EnnemyDeckZone/NbCard
@export var card_back_texture : Texture2D
@onready var player_stack_container = $PlayerDeckZone/StackContainer
@onready var ennemy_stack_container = $EnnemyDeckZone/StackContainer
@onready var player_field_slots = $VBoxContainer/PlayerField  # Slots: Slot1..Slot5

const MAX_HAND := 5
var zoomed_card: Control = null

func _ready():
	if card_scene == null:
		card_scene = preload("res://scenes/Card.tscn")
	
	player_deck.setup(deckManager.get_deck("deck1"))
	enemy_deck.setup(deckManager.get_deck("EnnemyBasic"))

	# Connecte les slots joueur
	for slot in player_field_slots.get_children():
		slot.gui_input.connect(_on_slot_clicked.bind(slot))

	# Dessine les mains
	update_deck_counts()
	draw_starting_hand()
	draw_enemy_starting_hand()


# --- Deck visuals ---
func update_player_deck_visual():
	for child in player_stack_container.get_children():
		child.queue_free()
	var visual_count = min(player_deck.size(), 8)
	for i in range(visual_count):
		var card = TextureRect.new()
		card.texture = card_back_texture
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.custom_minimum_size = Vector2(120,170)
		card.position = Vector2(i*2, -i*2)
		player_stack_container.add_child(card)

func update_ennemy_deck_visual():
	for child in ennemy_stack_container.get_children():
		child.queue_free()
	var visual_count = min(enemy_deck.size(), 8)
	for i in range(visual_count):
		var card = TextureRect.new()
		card.texture = card_back_texture
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.custom_minimum_size = Vector2(120,170)
		card.position = Vector2(i*2, -i*2)
		ennemy_stack_container.add_child(card)

func update_deck_counts():
	player_deck_label.text = str(player_deck.size())
	enemy_deck_label.text = str(enemy_deck.size())
	update_player_deck_visual()
	update_ennemy_deck_visual()


# --- Draw hands ---
func draw_starting_hand():
	for c in player_hand.get_children():
		c.queue_free()
	for i in range(MAX_HAND):
		var card_id = player_deck.draw()
		update_deck_counts()
		if card_id == "":
			break
		create_card_in_hand(card_id, true)

func draw_enemy_starting_hand():
	for c in enemy_hand.get_children():
		c.queue_free()
	for i in range(MAX_HAND):
		var card_id = enemy_deck.draw()
		update_deck_counts()
		if card_id == "":
			break
		create_card_in_hand(card_id, false)


# --- Create card instance ---
func create_card_in_hand(card_id: String, is_player: bool):
	var card_resource = deckManager.get_card_data(card_id) as displayCard
	if card_resource == null:
		print("Carte introuvable:", card_id)
		return
	
	var card_instance = card_scene.instantiate()
	if not card_instance is Card:
		print("ERREUR : la scène instanciée n'est pas une Card")
		return
	
	card_instance.set_card(card_resource)
	card_instance.set_display_size(Card.CardSize.HAND)
	card_instance.game_controller = self
	card_instance.is_player_card = is_player
	
	card_instance.connect("card_zoom", Callable(self, "_on_card_zoom"))
	
	# Ajout dans la bonne main et positionnement horizontal
	
	var hand = player_hand if is_player else enemy_hand
	hand.add_child(card_instance)
	
	var index := hand.get_child_count() - 1
	var card_width := 200 * 0.6  # largeur approximative * scale HAND
	var spacing := 50             # espace entre les cartes
	card_instance.position = Vector2(index * (card_width + spacing), 0)


# --- Zoom carte ---
func _on_card_zoom(card_res: displayCard):
	if zoomed_card:
		_close_zoom()
		return
	zoom_background.visible = true
	zoomed_card = card_scene.instantiate() as Card
	zoomed_card.set_card(card_res)
	zoomed_card.set_display_size(Card.CardSize.NORMAL)
	zoom_layer.add_child(zoomed_card)
	await get_tree().process_frame
	var zoom_factor := 2.0
	zoomed_card.scale = Vector2.ZERO
	var viewport_size = get_viewport_rect().size
	var card_size = zoomed_card.size * zoom_factor
	zoomed_card.position = (viewport_size - card_size)/2
	var tween = create_tween()
	tween.tween_property(zoomed_card, "scale", Vector2(zoom_factor, zoom_factor), 0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	zoomed_card.gui_input.connect(_on_zoom_input)
	print("Carte zoomée")

func _on_zoom_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_close_zoom()

func _close_zoom():
	if zoomed_card:
		zoomed_card.queue_free()
		zoomed_card = null
	zoom_background.visible = false

func _input(event):
	if zoomed_card and event is InputEventMouseButton and event.pressed:
		_close_zoom()


# --- Invocation ---
func start_summon_selection(card_node: Card):
	card_waiting_for_summon = card_node
	print("Sélectionne un slot pour invoquer")
	for slot in player_field_slots.get_children():
		slot.modulate = Color(1,1,0)

func _on_slot_clicked(event, slot):
	if event is InputEventMouseButton and event.pressed:
		if card_waiting_for_summon == null:
			return
		if slot.get_child_count() > 0:
			print("Slot occupé")
			return
		summon_to_slot(slot)

func summon_to_slot(slot):
	var card = card_waiting_for_summon
	card.get_parent().remove_child(card)
	slot.add_child(card)
	card.position = Vector2.ZERO
	card.set_display_size(Card.CardSize.FIELD)
	
	card.is_summoned = true
	card_waiting_for_summon = null
	
	for s in player_field_slots.get_children():
		s.modulate = Color(1,1,1)
