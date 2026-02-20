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
@export var currenthp: int
@export var maxhp : int

var card_data


func setup():
	card_data = deckManager.get_card_data(id)
	
