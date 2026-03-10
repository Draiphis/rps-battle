
extends CardEffect
class_name EffectDamageReducer

@export var reduction_factor_card := 0.5
@export var vulnerable_types_card := ["Végétaux"]  # types qui ne sont pas réduits

func on_receive_attack(defender, attacker, battle_manager, damage: int) -> int:
	# Si l'attaquant est dans les types vulnérables (eau ici), ne pas réduire
	if attacker.card.type in vulnerable_types_card:
		return damage

	# Sinon réduire les dégâts
	return int(damage * reduction_factor_card)
