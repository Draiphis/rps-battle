extends Control

class_name Card

@export var card: displayCard

enum CardSize { NORMAL, MINI, MAXI }

func set_display_size(card_size: int):
	var ratio := 1.0
	match card_size:
		CardSize.NORMAL:
			ratio = 1.0
		CardSize.MINI:
			ratio = 0.4
		CardSize.MAXI:
			ratio = 2.0  # ajustable pour le zoom

	self.scale = Vector2(ratio, ratio)
	#NE PAS TOUCHER SINON LES CARTES NE S'AFFICHENT PAS DANS COLLECTION
	self.custom_minimum_size = Vector2(200,280)

signal card_selected(card_id: String)
signal card_to_remove(card_id: String)
signal card_zoom(card: displayCard)

func set_card(c: displayCard):
	card = c
	if card:
		$AspectRatioContainer/Panel/CardName.text = card.name
		$AspectRatioContainer/Panel/Rank.text = str(card.rank)
		$AspectRatioContainer/Panel/Type.text = card.type
		$AspectRatioContainer/Panel/ImageBorder/CardImage.texture = card.image
		$AspectRatioContainer/Panel/MarginContainer/CardBackground.texture = card.background
		$AspectRatioContainer/Panel/DescriptionBorder/MarginContainer/Description.text = card.description
		$AspectRatioContainer/Panel/ATQ.text = "ATQ : %s" % str(card.atq)
		$AspectRatioContainer/Panel/SPD.text = "SPD : %s" % str(card.spd)
		$AspectRatioContainer/Panel/Panel/CurrentHP.text = str(card.currenthp)
		$AspectRatioContainer/Panel/Panel/MaxHP.text = str(card.maxhp)


func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			emit_signal("card_selected", card.id)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			emit_signal("card_to_remove", card.id)
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			print("MOLETTE détectée sur carte :", card.name)
			emit_signal("card_zoom", card)
		
		
