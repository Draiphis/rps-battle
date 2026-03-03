extends Node
class_name BattleManager

var game_controller
var player_hp_bar: ProgressBar
var enemy_hp_bar: ProgressBar
var info_label: Label = null  # Label pour afficher les instructions
var attacker: Card = null
var attacked_cards: Array = []  # cartes déjà attaquées ce tour

# Références aux cartes sur le terrain
var player_field_cards: Array = []
var enemy_field_cards: Array = []

var current_player: String = "player"  # Joueur actif, mis à jour par TurnManager

func _ready():
	TurnManager.phase_changed.connect(Callable(self, "_on_phase_changed"))


# --- Démarrer la battle phase ---
func start_battle_phase(player_cards: Array, enemy_cards: Array, info: Label, active_player: String, player_bar: ProgressBar, enemy_bar: ProgressBar):
	info_label = info
	player_field_cards = player_cards.duplicate()
	enemy_field_cards = enemy_cards.duplicate()
	attacker = null
	attacked_cards.clear()
	current_player = active_player
	
	player_hp_bar = player_bar
	enemy_hp_bar = enemy_bar
	
	TurnManager.current_phase = TurnManager.Phase.BATTLE
	
	# Autoriser toutes les cartes invoquées à attaquer ce tour
	for c in player_field_cards + enemy_field_cards:
		if c.is_summoned:
			c.can_attack_this_turn = true
	
	_update_info_text()

	# Connecter le signal card_selected pour toutes les cartes
	for c in player_field_cards + enemy_field_cards:
		if c.is_connected("card_selected_combat", Callable(self, "_on_card_clicked")):
			c.disconnect("card_selected_combat", Callable(self, "_on_card_clicked"))
		c.connect("card_selected_combat", Callable(self, "_on_card_clicked"))


# --- Gestion clic carte ---
func _on_card_clicked(card_instance_id: String):
	var clicked_card: Card = _find_card_by_instance_id(card_instance_id)
	if clicked_card == null or not clicked_card.card:
		return
	
	if attacker == null:
		# Sélection de l'attaquant
		if clicked_card.is_player_card and clicked_card.is_summoned and clicked_card.can_attack_this_turn:
			attacker = clicked_card
			_update_info_text()
			highlight_attackable_targets()
			
			# Si aucune carte ennemie → attaque directe
			if enemy_field_cards.size() == 0 and attacker != null:
				await _direct_attack(attacker)
				attacker.can_attack_this_turn = false
				attacker = null
				_update_info_text()
				return
		else:
			print("Carte invalide pour attaquer")
	else:
		# Sélection de la cible
		if not clicked_card.is_player_card and clicked_card.is_summoned:
			_perform_attack(attacker, clicked_card)
			attacker.can_attack_this_turn = false
			attacker = null
			_update_info_text()
		else:
			print("Cible invalide")


# --- Effectuer l'attaque ---
func _perform_attack(attacker_card: Card, target_card: Card) -> void:
	if not is_instance_valid(attacker_card) or not is_instance_valid(target_card):
		reset_highlight()
		return

	# Déterminer l'ordre selon la vitesse
	var first: Card
	var second: Card
	if target_card.card.spd > attacker_card.card.spd:
		first = target_card
		second = attacker_card
	else:
		first = attacker_card
		second = target_card

	# Première attaque
	second.card.hp -= first.card.atq
	second.card.hp = max(second.card.hp, 0)
	if is_instance_valid(second):
		second.update_display()
	await attacker_card.animate_attack(target_card)
	await target_card.animate_hit()
	_show_damage_on_card(first.card.atq, second)

	if second.card.hp <= 0:
		_destroy_card(second)
		reset_highlight()
		return

	# Contre-attaque
	first.card.hp -= second.card.atq
	first.card.hp = max(first.card.hp, 0)
	if is_instance_valid(first):
		first.update_display()
	_show_damage_on_card(second.card.atq, first)

	if first.card.hp <= 0:
		_destroy_card(first)
		
	
	attacker_card.can_attack_this_turn = false

	reset_highlight()


# --- Attaque directe ---
func _direct_attack(attacker_card: Card) -> void:
	var damage = attacker_card.card.atq
	print(attacker_card.card.name, "attaque directement pour", damage)

	var target_hp_bar: ProgressBar
	var target_hp_text: Label
	var new_hp: int

	if attacker_card.is_player_card:
		game_controller.enemy_hp -= damage
		game_controller.enemy_hp = max(game_controller.enemy_hp, 0)
		new_hp = game_controller.enemy_hp
		target_hp_bar = game_controller.enemy_hp_bar
		target_hp_text = game_controller.enemy_hp_text
	else:
		game_controller.player_hp -= damage
		game_controller.player_hp = max(game_controller.player_hp, 0)
		new_hp = game_controller.player_hp
		target_hp_bar = game_controller.player_hp_bar
		target_hp_text = game_controller.player_hp_text

	# Mise à jour immédiate du texte
	target_hp_text.text = str(new_hp)

	# Afficher le damage flottant
	# Jouer l'animation de l'attaque
	if is_instance_valid(attacker_card):
		await attacker_card.animate_attack(null)
	game_controller.show_damage(damage, target_hp_bar.global_position)
	attacker_card.can_attack_this_turn = false

	# Tween HP
	var tween = create_tween()
	tween.tween_property(target_hp_bar, "value", new_hp, 0.6)
	game_controller._check_victory_condition()
	await tween.finished


# --- IA ennemie ---
func enemy_battle_phase() -> void:
	while true:
		# Créer la liste des cartes ennemies disponibles à attaquer
		var alive_enemy_cards := []
		for c in enemy_field_cards:
			if is_instance_valid(c) and c.is_summoned and c.can_attack_this_turn:
				alive_enemy_cards.append(c)

		if alive_enemy_cards.size() == 0:
			break  # plus de cartes pouvant attaquer → fin du combat

		# Créer la liste des cibles ennemies
		var alive_player_cards := []
		for t in player_field_cards:
			if is_instance_valid(t) and t.is_summoned:
				alive_player_cards.append(t)

		for c in alive_enemy_cards:
			if alive_player_cards.size() == 0:
				await _direct_attack(c)
				
				continue

			var target = alive_player_cards[randi() % alive_player_cards.size()]
			_perform_attack(c, target)
			

			# Mettre à jour la liste des cartes vivantes
			alive_player_cards = []
			for t in player_field_cards:
				if is_instance_valid(t) and t.is_summoned:
					alive_player_cards.append(t)
			
			c.can_attack_this_turn = false
					
# --- Helpers ---
func _check_if_can_attack() -> bool:
	for c in player_field_cards:
		if c.is_summoned and c.can_attack_this_turn:
			return true
	return false


func _find_card_by_instance_id(instance_id: String) -> Card:
	for c in player_field_cards + enemy_field_cards:
		if c.instance_id == instance_id:
			return c
	return null


func _on_phase_changed(_new_phase):
	_update_info_text()


func _destroy_card(card: Card) -> void:
	if is_instance_valid(card) and card.get_parent():
		card.get_parent().remove_child(card)
		card.queue_free()
	if card.is_player_card:
		player_field_cards.erase(card)
	else:
		enemy_field_cards.erase(card)


func highlight_attackable_targets() -> void:
	for c in enemy_field_cards:
		if is_instance_valid(c):
			c.modulate = Color(1,1,1)  # normal

	if attacker:
		for c in enemy_field_cards:
			if is_instance_valid(c) and c.is_summoned:
				c.modulate = Color(1,0.5,0.5)


func reset_highlight() -> void:
	for c in enemy_field_cards:
		if is_instance_valid(c):
			c.modulate = Color(1,1,1)


func _show_damage_on_card(amount: int, target_card: Card) -> void:
	if not is_instance_valid(target_card):
		return
	game_controller.show_damage(amount, target_card.global_position)
	
func _update_info_text():
	if info_label == null:
		return

	# Si on n'est pas en battle phase, on vide le texte
	if TurnManager.current_phase != TurnManager.Phase.BATTLE:
		info_label.text = ""
		return

	# Vérifie si le joueur a des cartes qui peuvent attaquer
	if current_player == "player" and not _check_if_can_attack():
		info_label.text = "Terminez votre tour."
		return

	if attacker == null:
		info_label.text = "Choisissez l'attaquant"
	else:
		info_label.text = "Choisissez la cible de l'attaque"
