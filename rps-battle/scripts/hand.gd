extends Node

var cards = []  # La liste de cartes dans la main
var max_cards = 5
var card_owner = null  # peut être Player ou Enemy

signal card_played(card)

func add_card(card):
	if cards.size() < max_cards:
		cards.append(card)
		add_child(card)
		card.position = Vector2( (cards.size()-1) * 100, 0 )  # espacement simple
		return true
	return false

func remove_card(card):
	if card in cards:
		cards.erase(card)
		card.queue_free()
		_update_positions()
		return true
	return false

func _update_positions():
	for i in range(cards.size()):
		cards[i].position = Vector2(i * 100, 0)

func play_card(card, target_slot):
	if remove_card(card):
		target_slot.place_card(card)
		emit_signal("card_played", card)
