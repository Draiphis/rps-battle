extends Node

signal turn_started(player : int)
signal phase_changed(phase : int)
signal turn_ended(player : int)

# --- Phases ---
enum Phase {
	DRAW,
	MAIN,
	BATTLE,
	END
}

# --- Joueurs ---
enum Player {
	PLAYER,
	ENEMY
}

var current_player : int = Player.PLAYER
var current_phase : int = Phase.DRAW

var has_summoned_this_turn := false

var battle_manager : BattleManager = null
var game_scene = null  # Référence à la scène Game

# --- Référence à la scène Game ---
func set_game(scene):
	game_scene = scene

func set_battle_manager(bm: BattleManager) -> void:
	battle_manager = bm

# --- Début de la partie ---
func start_game():
	start_turn(Player.PLAYER)

# --- Début d'un tour ---
func start_turn(player : int):
	current_player = player
	current_phase = Phase.DRAW
	has_summoned_this_turn = false
	emit_signal("turn_started", player)
	
	if current_player == Player.PLAYER:
		start_draw_phase()
	else:
		await enemy_play_turn()

# --- Phases joueurs ---
func start_draw_phase():
	current_phase = Phase.DRAW
	emit_signal("phase_changed", current_phase)
	
	if game_scene != null:
		if current_player == Player.PLAYER:
			game_scene.refill_hand()
		else:
			game_scene.refill_enemy_hand()
	
	change_phase(Phase.MAIN)

func start_main_phase():
	current_phase = Phase.MAIN
	emit_signal("phase_changed", current_phase)
	print("Main Phase: Player =", current_player)

func start_battle_phase():
	current_phase = Phase.BATTLE
	emit_signal("phase_changed", current_phase)
	print("Battle phase")

	if game_scene != null:
		
		game_scene.start_battle_phase_for_battle_manager()

func start_end_phase():
	current_phase = Phase.END
	emit_signal("phase_changed", current_phase)
	end_turn()

# --- Changement de phase ---
func change_phase(new_phase : int):
	match new_phase:
		Phase.DRAW: start_draw_phase()
		Phase.MAIN: start_main_phase()
		Phase.BATTLE: start_battle_phase()
		Phase.END: start_end_phase()

# --- Fin de tour ---
func end_turn():
	emit_signal("turn_ended", current_player)
	
	if current_player == Player.PLAYER:
		start_turn(Player.ENEMY)
	else:
		start_turn(Player.PLAYER)

# --- Passage à la phase suivante (bouton Next Phase) ---
func next_phase():
	match current_phase:
		Phase.DRAW: change_phase(Phase.MAIN)
		Phase.MAIN: change_phase(Phase.BATTLE)
		Phase.BATTLE: change_phase(Phase.END)
		Phase.END: pass

# --- Tour automatique de l'ennemi ---
func enemy_play_turn() -> void:
	# Draw
	print("Enemy Draw Phase")
	emit_signal("phase_changed", Phase.DRAW)
	if game_scene != null:
		game_scene.refill_enemy_hand()
	await get_tree().create_timer(0.5).timeout

	# Main
	print("Enemy Main Phase")
	emit_signal("phase_changed", Phase.MAIN)
	if game_scene != null:
		game_scene.enemy_summon_random_card()
	await get_tree().create_timer(0.5).timeout

	# Battle
	print("Enemy Battle Phase")
	emit_signal("phase_changed", Phase.BATTLE)
	if battle_manager != null:
		battle_manager.enemy_battle_phase()
	await get_tree().create_timer(0.5).timeout

	# End
	print("Enemy End Phase")
	emit_signal("phase_changed", Phase.END)
	await get_tree().create_timer(0.5).timeout

	# Fin du tour
	end_turn()
