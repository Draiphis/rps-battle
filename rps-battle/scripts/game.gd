extends Control

var player_deck := GameDeck.new()
var enemy_deck := GameDeck.new()
var card_waiting_for_summon : Card = null
var player_hp := 50
var enemy_hp := 50
var sacrifice_target_card: Card = null
var sacrifice_required_count: int = 0
var sacrifice_selected_cards: Array = []


@onready var battle_manager = $BattleManager
@onready var player_hp_bar = $CanvasLayer/PlayerHpBar
@onready var player_hp_text = $CanvasLayer/PlayerHpText
@onready var enemy_hp_bar = $CanvasLayer/EnemyHpBar
@onready var enemy_hp_text = $CanvasLayer/EnemyHpText
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
@onready var player_field_slots = $VBoxContainer/PlayerField
@onready var enemy_field_slots = $VBoxContainer/EnnemyField  # Slots: Slot1..Slot5



const MAX_HAND := 5
var zoomed_card: Control = null

func _ready():
	player_hp_bar.max_value = player_hp
	player_hp_bar.value = player_hp
	enemy_hp_bar.max_value = enemy_hp
	enemy_hp_bar.value = enemy_hp
	$ConfirmSacrificeButton.pressed.connect(on_confirm_sacrifice_pressed)
	$ConfirmSacrificeButton.visible = false
	
	update_hp_display()
	
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
	TurnManager.start_game()
	TurnManager.set_game(self)
	TurnManager.set_battle_manager(battle_manager)
	battle_manager.game_controller = self


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
	var base_card = deckManager.get_card_data(card_id) as displayCard
	if base_card == null:
		print("Carte introuvable:", card_id)
		return
	
	var card_resource = base_card.duplicate() as displayCard
	var card_instance = card_scene.instantiate() as Card
	card_instance.set_card(card_resource)
	card_instance.set_display_size(Card.CardSize.HAND)
	card_instance.game_controller = self
	card_instance.is_player_card = is_player
	
	card_instance.connect("card_zoom", Callable(self, "_on_card_zoom"))
	if is_player:
		card_instance.connect("card_selected_for_sacrifice", Callable(self, "on_sacrifice_card_clicked"))

	var hand = player_hand if is_player else enemy_hand
	hand.add_child(card_instance)
	update_hand_positions(is_player)


# --- Zoom carte ---
func _on_card_zoom(card_res: displayCard):
	# Si une carte est déjà zoomée → on ferme
	print("zoom")
	if zoomed_card:
		_close_zoom()

	zoom_background.visible = true

	# On prend **la même instance**, pas une nouvelle copie
	zoomed_card = card_scene.instantiate() as Card
	zoomed_card.set_card(card_res)  # PAS de duplicate !
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

	# Crée une copie si nécessaire (si tu passes la même référence de la main)
	card.card = card.card.duplicate() as displayCard

	card.get_parent().remove_child(card)
	slot.add_child(card)
	card.position = Vector2.ZERO
	card.set_display_size(Card.CardSize.FIELD)
	card.is_summoned = true
	card.is_summonable = false
	card_waiting_for_summon = null
	
	for s in player_field_slots.get_children():
		s.modulate = Color(1,1,1)
	
func refill_hand_generic(is_player: bool):
	var hand = player_hand if is_player else enemy_hand
	var deck = player_deck if is_player else enemy_deck

	while hand.get_child_count() < MAX_HAND:
		if deck.is_empty():
			print("Deck vide")
			break
		var card_id = deck.draw()
		if card_id == "":
			break
		create_card_in_hand(card_id, is_player)
		update_deck_counts()

	update_hand_positions(is_player)
	
func refill_hand():
	refill_hand_generic(true)

func refill_enemy_hand():
	refill_hand_generic(false)


func _on_next_phase_button_pressed() -> void:
	TurnManager.next_phase()
	
func update_hand_positions(is_player: bool):
	var hand = player_hand if is_player else enemy_hand
	var card_width := 200 * 0.6
	var spacing := 50
	for i in range(hand.get_child_count()):
		var card = hand.get_child(i)
		card.position = Vector2(i * (card_width + spacing), 0)
		
  # repositionne les cartes restantes du joueur

func enemy_summon_random_card():
	# Récupérer toutes les cartes en main de l'ennemi
	var enemy_cards_on_field = get_cards_on_field(false)
	var playable_cards := []
	for i in range(enemy_hand.get_child_count()):
		var c = enemy_hand.get_child(i)
		
		if can_summon_card(c, enemy_cards_on_field):
			playable_cards.append(c)
	
	if playable_cards.size() == 0:
		print("Aucune carte jouable à invoquer")
		return
	
	# Choisir une carte jouable au hasard
	var card = playable_cards[randi() % playable_cards.size()]
	
	# Sacrifices nécessaires
	
	var sacrifices = select_sacrifices(card, enemy_cards_on_field)
	for c in sacrifices:
		battle_manager._destroy_card(c)
	
	# Chercher un slot vide
	var empty_slots = []
	for slot in enemy_field_slots.get_children():
		if slot.get_child_count() == 0:
			empty_slots.append(slot)
	if empty_slots.size() == 0:
		print("Pas de slot vide pour invoquer")
		return
	
	var chosen_slot = empty_slots[randi() % empty_slots.size()]

	# Invoquer la carte
	card.get_parent().remove_child(card)
	chosen_slot.add_child(card)
	card.position = Vector2.ZERO
	card.set_display_size(Card.CardSize.FIELD)
	card.is_summoned = true
	card.is_summonable = false
	battle_manager.enemy_field_cards.append(card)
	card.can_attack_this_turn = true
	
	print("Enemy invoque :", card.card.name)
	
func start_battle_phase_for_battle_manager():
	# Récupérer toutes les cartes sur le terrain
	var player_cards = []
	for slot in player_field_slots.get_children():
		if slot.get_child_count() > 0:
			player_cards.append(slot.get_child(0))

	var enemy_cards = []
	for slot in enemy_field_slots.get_children():
		if slot.get_child_count() > 0:
			enemy_cards.append(slot.get_child(0))

	var active_player_str = "player" if TurnManager.current_player == TurnManager.Player.PLAYER else "enemy"
	battle_manager.start_battle_phase(player_cards, enemy_cards, $Info, active_player_str, player_hp_bar, enemy_hp_bar)


func update_hp_display():
	player_hp_text.text = str(player_hp)
	enemy_hp_text.text = str(enemy_hp)
	
func damage_player(amount):
	player_hp -= amount
	player_hp = max(player_hp, 0)

	var tween = create_tween()
	tween.tween_property(player_hp_bar, "value", player_hp, 0.5)

	update_hp_display()
	show_damage(amount, player_hp_bar.global_position)
	_check_victory_condition()
	
func damage_enemy(amount):

	enemy_hp -= amount
	enemy_hp = max(enemy_hp, 0)

	var tween = create_tween()
	tween.tween_property(enemy_hp_bar, "value", enemy_hp, 0.5)

	update_hp_display()
	show_damage(amount, enemy_hp_bar.global_position)
	_check_victory_condition()


func show_damage(damage: int, pos: Vector2):
	var dmg_label = Label.new()
	dmg_label.text = "-%d" % damage
	dmg_label.add_theme_color_override("font_color", Color.RED)
	dmg_label.position = pos
	add_child(dmg_label)
	dmg_label.position = pos + Vector2(-30, 50)

	var tween = create_tween()
	tween.tween_property(dmg_label, "position:y", dmg_label.position.y -20, 0.8)
	tween.tween_property(dmg_label, "modulate:a", 0, 0.8)
	tween.tween_callback(Callable(dmg_label, "queue_free"))
	await tween.finished
	
func can_summon_card(card_to_summon: Card, field_cards: Array) -> bool:
	var required_rank = card_to_summon.rank - 1
	if required_rank <= 0:
		return true  # Carte de rang 1, pas de sacrifice nécessaire
	
	var high_rank_cards := []
	var low_rank_cards := []
	for c in field_cards:
		if is_instance_valid(c) and c.is_summoned:
			if c.rank >= required_rank:
				high_rank_cards.append(c)
			else:
				low_rank_cards.append(c)
	
	# Si une carte ≥ required_rank existe → peut sacrifier 1 seule
	if high_rank_cards.size() > 0:
		return true
	
	# Sinon, vérifier si la somme des cartes plus faibles suffit
	low_rank_cards.sort_custom(Callable(self, "_compare_rank_desc"))  # commence par les plus grandes
	var total = 0
	for c in low_rank_cards:
		total += c.rank
		if total >= required_rank:
			return true
	
	return false

func _sort_desc(a, b):
	return b - a
	
func select_sacrifices(card_to_summon: Card, field_cards: Array) -> Array:
	var required_rank = card_to_summon.rank - 1
	var selection := []
	if required_rank <= 0:
		return selection  # pas besoin de sacrifice
	
	# Priorité cartes de rang >= required_rank
	for c in field_cards:
		if is_instance_valid(c) and c.is_summoned and c.rank >= required_rank:
			selection.append(c)
			return selection  # Une seule carte suffit
	
	# Combiner plusieurs cartes plus faibles
	var low_rank_cards := []
	for c in field_cards:
		if is_instance_valid(c) and c.is_summoned and c.rank < required_rank:
			low_rank_cards.append(c)
	low_rank_cards.sort_custom(Callable(self, "_compare_rank_desc"))
	
	var total = 0
	for c in low_rank_cards:
		selection.append(c)
		total += c.rank
		if total >= required_rank:
			break
	
	if total >= required_rank:
		return selection
	return []  # Pas assez de rangs

	
	
func _compare_rank_desc(a: Card, b: Card):
	return b.rank - a.rank
	
func summon_card_with_sacrifice(card_node: Card, slot):
	var field_cards = get_cards_on_field(true)
	if not can_summon_card(card_node, field_cards):
		print("Pas assez de sacrifices")
		return

	var sacrifices = select_sacrifices(card_node, field_cards)
	for c in sacrifices:
		battle_manager._destroy_card(c)

	# Invoquer la carte
	card_node.get_parent().remove_child(card_node)
	slot.add_child(card_node)
	card_node.position = Vector2.ZERO
	card_node.set_display_size(Card.CardSize.FIELD)
	card_node.is_summoned = true
	card_node.is_summonable = false
	card_waiting_for_summon = null
	
func get_cards_on_field(is_player: bool) -> Array:
	var arr := []
	var slots = player_field_slots if is_player else enemy_field_slots
	for slot in slots.get_children():
		if slot.get_child_count() > 0:
			arr.append(slot.get_child(0))
	return arr
	
func start_sacrifice_selection(card_to_summon: Card, selectable_cards: Array, required: int):

	reset_sacrifice_selection() # sécurité

	for c in selectable_cards:
		c.modulate = Color(1,1,0)
		c.is_selectable_for_sacrifice = true

	sacrifice_target_card = card_to_summon
	sacrifice_required_count = required
	sacrifice_selected_cards = []

	$ConfirmSacrificeButton.visible = true
	
func on_sacrifice_card_clicked(card: Card):
	if card in sacrifice_selected_cards:
		sacrifice_selected_cards.erase(card)
		card.modulate = Color(1,1,0)
	else:
		if sacrifice_selected_cards.size() < sacrifice_required_count:
			sacrifice_selected_cards.append(card)
			card.modulate = Color(1,0.5,0.5)  # rouge
			
func on_confirm_sacrifice_pressed():

	if sacrifice_target_card == null:
		print("Aucune carte à invoquer")
		return

	var total_rank = 0
	for c in sacrifice_selected_cards:
		total_rank += c.rank

	if total_rank < sacrifice_required_count:
		print("Pas assez de rang pour invoquer")
		return


	# Sacrifier les cartes sélectionnées
	for c in sacrifice_selected_cards:
		battle_manager._destroy_card(c)


	# Chercher un slot vide
	var empty_slots = []
	for slot in player_field_slots.get_children():
		if slot.get_child_count() == 0:
			empty_slots.append(slot)

	if empty_slots.size() == 0:
		print("Pas de slot vide pour invoquer")
		reset_sacrifice_selection()
		return


	var chosen_slot = empty_slots[0]


	# Invoquer la carte
	if sacrifice_target_card.get_parent():
		sacrifice_target_card.get_parent().remove_child(sacrifice_target_card)

	chosen_slot.add_child(sacrifice_target_card)
	sacrifice_target_card.position = Vector2.ZERO
	sacrifice_target_card.set_display_size(Card.CardSize.FIELD)

	sacrifice_target_card.is_summoned = true
	sacrifice_target_card.is_summonable = false


	TurnManager.has_summoned_this_turn = true


	# Reset COMPLET des états de sacrifice
	reset_sacrifice_selection()

	print("Invocation sacrifice réussie")
	
func reset_sacrifice_selection():
	for c in get_cards_on_field(true):
		c.modulate = Color(1,1,1)
		c.is_selectable_for_sacrifice = false

	sacrifice_selected_cards.clear()
	sacrifice_target_card = null
	$ConfirmSacrificeButton.visible = false
	
func _check_victory_condition():
	if player_hp <= 0:
		_on_game_over(false)
	elif enemy_hp <= 0:
		_on_game_over(true)
		
func _on_game_over(player_won: bool):
	if player_won:
		print("Victoire ! Vous avez réduit l'adversaire à 0 HP !")
		await get_tree().process_frame  # permet de rendre la frame finale
		await get_tree().create_timer(1.5).timeout  # demi-seconde pause
		$EndGameScreenV.visible = true
	else:
		print("Défaite... Votre HP est à 0.")
		await get_tree().process_frame  # permet de rendre la frame finale
		await get_tree().create_timer(1.5).timeout  # demi-seconde pause
		$EndGameScreenL.visible = true
	
func summon_card(card_data: displayCard, is_player: bool) -> void:
	var slots = player_field_slots if is_player else enemy_field_slots
	var empty_slots := []

	for slot in slots.get_children():
		if slot.get_child_count() == 0:
			empty_slots.append(slot)

	if empty_slots.size() == 0:
		print("Pas de slot vide pour invoquer :", card_data.name)
		return

	var chosen_slot = empty_slots[0]

	# Création de la carte
	var card_instance = card_scene.instantiate() as Card
	card_instance.set_card(card_data.duplicate())
	card_instance.set_display_size(Card.CardSize.FIELD)

	card_instance.game_controller = self
	card_instance.is_player_card = is_player
	card_instance.is_summoned = true
	card_instance.is_summonable = false
	card_instance.can_attack_this_turn = true

	# 🔗 IMPORTANT : mêmes connexions que les autres cartes
	card_instance.connect("card_zoom", Callable(self, "_on_card_zoom"))

	if is_player:
		card_instance.connect("card_selected_for_sacrifice", Callable(self, "on_sacrifice_card_clicked"))

	# Ajout au terrain
	chosen_slot.add_child(card_instance)
	card_instance.position = Vector2.ZERO

	print("Carte invoquée :", card_data.name)
