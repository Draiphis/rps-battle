extends Node
class_name DeckManager

var decks := {}
var cards := {}

func _ready():
	_load_decks()
	_load_cards()

func _load_decks():
	_register_deck("deck1", "res://decks/deck1.tres")
	_register_deck("EnnemyBasic", "res://decks/EnnemyBasic.tres")


func _register_deck(id: String, path: String):
	var deck = load(path)
	if deck:
		decks[id] = deck

func get_deck(id: String) -> Deck:
	return decks.get(id)
	
func _load_cards():
	# Exemples : id → displayCard resource
	cards["ciseaux"] = load("res://cards/ciseaux.tres")
	cards["feuille"] = load("res://cards/feuille.tres")
	cards["pierre"] = load("res://cards/pierre.tres")
	cards["grokayou"] = load("res://cards/grokayou.tres")
	cards["profchene"] = load("res://cards/profchene.tres")
	cards["puit"] = load("res://cards/puit.tres")
	cards["tronconneuse"] = load("res://cards/tronconneuse.tres")
	

# ⚡ Retourne la Resource displayCard par ID
func get_card_data(id: String) -> displayCard:
	if cards.has(id):
		return cards[id]
	return null
