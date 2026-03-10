extends CardEffect
class_name EffectSummonOnDeath

@export var card_to_summon: displayCard

func on_death(card, game):
	if card_to_summon == null:
		return

	# Appelle la fonction summon_card dans GameController
	game.summon_card(card_to_summon, card.is_player_card)
	print("Carte invoquée à la mort de", card.card.name)
