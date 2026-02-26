extends Node
class_name BattleManager

var info_label: Label = null  # Label pour afficher les instructions
var attacker: Card = null
var attacked_cards: Array = []  # cartes déjà attaquées ce tour

# Références aux cartes sur le terrain
var player_field_cards: Array = []
var enemy_field_cards: Array = []

var current_player: String = "player"  # Joueur actif, mis à jour par TurnManager


func _ready():
	# ... ton code existant
	TurnManager.phase_changed.connect(Callable(self, "_on_phase_changed"))
# --- Démarrer la battle phase ---
func start_battle_phase(player_cards: Array, enemy_cards: Array, info: Label, active_player: String):
	info_label = info
	player_field_cards = player_cards.duplicate()
	enemy_field_cards = enemy_cards.duplicate()
	attacker = null
	attacked_cards.clear()
	current_player = active_player
	
	TurnManager.current_phase = TurnManager.Phase.BATTLE

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
		if clicked_card.is_player_card and clicked_card.is_summoned and not attacked_cards.has(clicked_card):
			attacker = clicked_card
			_update_info_text()
			print("Attaquant sélectionné :", attacker.card.name)
		else:
			print("Carte invalide pour attaquer")
	else:
		# Sélection de la cible
		if not clicked_card.is_player_card and clicked_card.is_summoned:
			_perform_attack(attacker, clicked_card)
			attacked_cards.append(attacker)
			attacker = null
			_update_info_text()
		else:
			print("Cible invalide")

# --- Effectuer l'attaque ---
func _perform_attack(attacker_card: Card, target_card: Card):
	if not is_instance_valid(attacker_card) or not is_instance_valid(target_card):
		return

	# Déterminer qui attaque en premier selon la vitesse
	var first: Card
	var second: Card
	if target_card.card.spd >= attacker_card.card.spd:
		first = target_card
		second = attacker_card
	else:
		first = attacker_card
		second = target_card

	# Première attaque
	second.card.hp -= first.card.atq
	if second.card.hp < 0:
		second.card.hp = 0
	if is_instance_valid(second):
		second.update_display()

	# Si la première attaque tue la cible
	if second.card.hp <= 0:
		print("%s est détruite !" % second.card.name)
		if is_instance_valid(second) and second.get_parent():
			# Retirer la carte du terrain
			second.get_parent().remove_child(second)
			second.queue_free()
		# Retirer des listes de cartes
		if second.is_player_card:
			player_field_cards.erase(second)
		else:
			enemy_field_cards.erase(second)
		return  # fin du combat entre ces deux cartes

	# Contre-attaque
	first.card.hp -= second.card.atq
	if first.card.hp < 0:
		first.card.hp = 0
	if is_instance_valid(first):
		first.update_display()

	if first.card.hp <= 0:
		print("%s est détruite !" % first.card.name)
		if is_instance_valid(first) and first.get_parent():
			first.get_parent().remove_child(first)
			first.queue_free()
		if first.is_player_card:
			player_field_cards.erase(first)
		else:
			enemy_field_cards.erase(first)

# --- Mettre à jour le texte du Label ---
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

# --- Trouver carte par ID ---
func _find_card_by_instance_id(instance_id: String) -> Card:
	for c in player_field_cards + enemy_field_cards:
		if c.instance_id == instance_id:
			return c
	return null

# --- IA ennemie simple ---
func enemy_battle_phase():
	# Filtrer les cartes ennemies vivantes et invoquées
	var alive_enemy_cards := []
	for c in enemy_field_cards:
		if is_instance_valid(c) and c.is_summoned:
			alive_enemy_cards.append(c)

	# Filtrer les cartes du joueur vivantes et invoquées
	var alive_player_cards := []
	for t in player_field_cards:
		if is_instance_valid(t) and t.is_summoned:
			alive_player_cards.append(t)

	# Boucle de l'IA
	for c in alive_enemy_cards:
		# Vérifie qu'il reste des cartes à attaquer
		if alive_player_cards.size() == 0:
			break

		# Choisir une cible aléatoire
		var target = alive_player_cards[randi() % alive_player_cards.size()]

		# Effectuer l'attaque en toute sécurité
		_perform_attack(c, target)

		# Mettre à jour la liste des cartes vivantes après chaque attaque
		var temp := []
		for t in alive_player_cards:
			if is_instance_valid(t) and t.is_summoned:
				temp.append(t)
		alive_player_cards = temp
func _check_if_can_attack() -> bool:
	var available_attackers = []
	for c in player_field_cards:
		if c.is_summoned and not attacked_cards.has(c):
			available_attackers.append(c)
	return available_attackers.size() > 0

func _on_phase_changed(new_phase):
	_update_info_text()
