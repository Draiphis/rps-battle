extends Node
class_name GameDeck

var cards: Array[String] = []

func setup(deck_data: Deck):
	cards = deck_data.cards.duplicate()
	cards.shuffle()

func draw() -> String:
	if cards.is_empty():
		return ""
	return cards.pop_back()
func size() -> int:
	return cards.size()
