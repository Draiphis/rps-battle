extends Node

signal turn_started(player)
signal phase_changed(phase)
signal turn_ended(player)


enum Phase {
	DRAW,
	MAIN,
	BATTLE,
	END
}
var has_summoned_this_turn := false
var current_phase : Phase
var current_player : String = "player"  # "player" ou "enemy"
var battle_manager : BattleManager = null

var game_scene = null  # va stocker la référence à la scène Game

# Fonction pour passer la référence
func set_game(scene):
	game_scene = scene

func start_game():
	start_turn("player")

func start_turn(player):
	current_player = player
	current_phase = Phase.DRAW
	has_summoned_this_turn = false
	
	emit_signal("turn_started", player)
	
	if current_player == "player":
		start_draw_phase()  # Joueur humain → bouton Next Phase contrôle les phases
	else:
		enemy_play_turn()   # Ennemi automatique

func start_draw_phase():
	current_phase = Phase.DRAW
	print("Draw phase started, game_scene =", game_scene)
	if game_scene != null:
		game_scene.refill_hand()
	emit_signal("phase_changed", current_phase)
	print("Draw phase")
	# Le joueur ou bouton Next Phase passe à Main Phase

	

	change_phase(Phase.MAIN)

func start_main_phase():
	current_phase = Phase.MAIN
	emit_signal("phase_changed", current_phase)

	print("Main phase")

func start_battle_phase():
	current_phase = Phase.BATTLE
	emit_signal("phase_changed", current_phase)
	print("Battle phase")

	if game_scene != null:
		game_scene.start_battle_phase_for_battle_manager()
	print("Battle phase")

func start_end_phase():
	current_phase = Phase.END
	emit_signal("phase_changed", current_phase)
	print("End phase")
	
	# Termine automatiquement le tour
	end_turn()

func change_phase(new_phase):
	match new_phase:
		Phase.DRAW:
			start_draw_phase()
		Phase.MAIN:
			start_main_phase()
		Phase.BATTLE:
			start_battle_phase()
		Phase.END:
			start_end_phase()

func end_turn():
	emit_signal("turn_ended", current_player)
	
	# Alterner le joueur
	if current_player == "player":
		start_turn("enemy")
	else:
		start_turn("player")
		
func next_phase():
	match current_phase:
		Phase.DRAW:
			change_phase(Phase.MAIN)
		Phase.MAIN:
			change_phase(Phase.BATTLE)
		Phase.BATTLE:
			change_phase(Phase.END)
		Phase.END:
			pass
			
func enemy_play_turn() -> void:
	# Draw
	print("Enemy Draw Phase")
	emit_signal("phase_changed", Phase.DRAW)
	if game_scene != null:
		game_scene.refill_enemy_hand()
	# Petite pause pour visualiser l'action
	await get_tree().create_timer(0.5).timeout  # 0.5 seconde

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
	# Fin du tour de l'ennemi
	await get_tree().create_timer(0.5).timeout
	end_turn()
	
func set_battle_manager(bm: BattleManager) -> void:
	battle_manager = bm
