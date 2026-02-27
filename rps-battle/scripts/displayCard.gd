extends Resource
class_name displayCard  # le nom de ton type ressource

@export var id: String
@export var name: String
@export var rank: int
@export var description: String
@export var image: Texture2D
@export var background: Texture2D
@export var type: String
@export var atq: int
@export var spd: int
@export var hp: int


var card_data


func setup():
	card_data = deckManager.get_card_data(id)
	
func deep_copy() -> displayCard:
	var copy = displayCard.new()
	copy.id = id
	copy.name = name
	copy.rank = rank
	copy.description = description
	copy.image = image
	copy.background = background
	copy.type = type
	copy.atq = atq
	copy.spd = spd
	copy.hp = hp
	copy.card_data = card_data
	return copy
