extends Control
class_name Card

@export var card: displayCard
@onready var summon_button = $Invoquer/SummonButton
var game_controller
var is_player_card := true
var is_summoned := false
var is_summonable := false
var instance_id: String

enum CardSize { NORMAL, MINI, MAXI, HAND, FIELD }

signal card_selected_combat(instance_id: String)
signal card_selected_collection(card_id: String)
signal card_to_remove(card_id: String)
signal card_zoom(card: displayCard)

func _ready():
	summon_button.visible = false
	summon_button.mouse_filter = Control.MOUSE_FILTER_STOP
	summon_button.pressed.connect(_on_summon_pressed)
	TurnManager.phase_changed.connect(_on_phase_changed)
	instance_id = str(self.get_instance_id())

	# hover sur la carte
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))

	# hover sur le bouton
	summon_button.connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	summon_button.connect("mouse_exited", Callable(self, "_on_mouse_exited"))

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
		$AspectRatioContainer/Panel/HP.text = "HP : %s" % str(card.hp)
		

func set_display_size(card_size: int):
	var ratio := 1.0
	match card_size:
		CardSize.NORMAL:
			ratio = 1.0
		CardSize.HAND:
			ratio = 0.6
		CardSize.FIELD:
			ratio=0.5
		CardSize.MINI:
			ratio = 0.4
		CardSize.MAXI:
			ratio = 2.0
	self.scale = Vector2(ratio, ratio)
	self.custom_minimum_size = Vector2(200,280)*ratio

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			emit_signal("card_selected_combat", instance_id)
			emit_signal("card_selected_collection", card.id)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			emit_signal("card_to_remove", card.id)
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			emit_signal("card_zoom", card)

func _on_mouse_entered():
	if is_player_card and is_summonable and not is_summoned and not TurnManager.has_summoned_this_turn :
		summon_button.visible = true

func _on_mouse_exited():
	# Vérifie si la souris est encore sur le bouton avant de cacher
	if not summon_button.get_global_rect().has_point(get_viewport().get_mouse_position()):
		summon_button.visible = false

func _on_summon_pressed():
	if TurnManager.has_summoned_this_turn:
		
		print("Vous ne pouvez invoquer qu'une seule carte par tour !")
		return
	if game_controller:
		game_controller.start_summon_selection(self)
		TurnManager.has_summoned_this_turn = true  # marquer qu'on a invoqué
		summon_button.visible = false
		
func _on_phase_changed(phase):
	if phase == TurnManager.Phase.MAIN:
		is_summonable = true
	else:
		is_summonable = false

func update_display():
	if not card:
		return
	$AspectRatioContainer/Panel/HP.text = "HP : %s" % str(card.hp)
	$AspectRatioContainer/Panel/ATQ.text = "ATQ : %s" % str(card.atq)
	$AspectRatioContainer/Panel/SPD.text = "SPD : %s" % str(card.spd)
