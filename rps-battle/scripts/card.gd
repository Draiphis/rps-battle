extends Control
class_name Card

@export var card: displayCard
@onready var summon_button = $Invoquer/SummonButton
var game_controller
var is_player_card := true
var is_summoned := false
var is_summonable := false
var can_attack_this_turn := true
var instance_id: String
var rank: int = 1  
var is_selectable_for_sacrifice := false

enum CardSize { NORMAL, MINI, MAXI, HAND, FIELD }

signal card_selected_combat(instance_id: String)
signal card_selected_collection(card_id: String)
signal card_to_remove(card_id: String)
signal card_zoom(card: displayCard)
signal card_selected_for_sacrifice(card_node: Card)

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
		rank = card.rank
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
		CardSize.NORMAL: ratio = 1.0
		CardSize.HAND: ratio = 0.6
		CardSize.FIELD: ratio = 0.5
		CardSize.MINI: ratio = 0.4
		CardSize.MAXI: ratio = 2.0
	self.scale = Vector2(ratio, ratio)
	self.custom_minimum_size = Vector2(200,280) * ratio

func _gui_input(event):
	if event is InputEventMouseButton:
		# Sélection de carte pour sacrifice
		if is_selectable_for_sacrifice and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			emit_signal("card_selected_for_sacrifice", self)
			return
		# Sélection normale
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			emit_signal("card_selected_combat", instance_id)
			emit_signal("card_selected_collection", card.id)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			emit_signal("card_to_remove", card.id)
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			emit_signal("card_zoom", card)

func _on_mouse_entered():
	if is_player_card and is_summonable and not is_summoned and not TurnManager.has_summoned_this_turn:
		summon_button.visible = true

func _on_mouse_exited():
	if not summon_button.get_global_rect().has_point(get_viewport().get_mouse_position()):
		summon_button.visible = false

func _on_summon_pressed():
	if TurnManager.current_player != TurnManager.Player.PLAYER:
		print("Vous ne pouvez invoquer que pendant votre tour !")
		return
	# --- Bloquer si une invocation a déjà été faite ---
	if TurnManager.has_summoned_this_turn:
		print("Vous ne pouvez invoquer qu'une seule carte par tour !")
		return

	if not game_controller:
		return

	var field_cards = game_controller.get_cards_on_field(true)

	# --- Vérifier si assez de sacrifices ---
	if not game_controller.can_summon_card(self, field_cards):
		print("Pas assez de sacrifices pour invoquer cette carte !")
		return

	var required = self.rank - 1

	# Carte rang 1 → invoquer directement
	if required <= 0:
		game_controller.start_summon_selection(self)
		# Marquer comme invoqué pour le tour
		TurnManager.has_summoned_this_turn = true
		return

	# Carte rang >1 → sélectionner les sacrifices
	var selectable = game_controller.get_cards_on_field(true).filter(func(c):
		return c.is_summoned
	)

	# --- Démarrer la sélection de sacrifice ---
	game_controller.start_sacrifice_selection(self, selectable, required)

func _on_phase_changed(phase):
	is_summonable = (phase == TurnManager.Phase.MAIN)

func update_display():
	if not card: return
	$AspectRatioContainer/Panel/HP.text = "HP : %s" % str(card.hp)
	$AspectRatioContainer/Panel/ATQ.text = "ATQ : %s" % str(card.atq)
	$AspectRatioContainer/Panel/SPD.text = "SPD : %s" % str(card.spd)
	
func animate_attack(target: Card) -> void:
	var original_position = position
	var local_direction = Vector2(0, -60)  # déplacement vers l'avant par défaut

	if target and is_instance_valid(target):
		var direction = (target.global_position - global_position).normalized()
		local_direction = direction * 60

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	# Avance
	tween.tween_property(self, "position", original_position + local_direction, 0.12)
	tween.tween_interval(0.05)
	# Retour
	tween.tween_property(self, "position", original_position, 0.15)

	await tween.finished
	
func animate_hit() -> void:
	var original_modulate = modulate
	
	var tween = create_tween()
	
	# Flash rouge
	tween.tween_property(self, "modulate", Color(1, 0.4, 0.4), 0.08)
	tween.tween_property(self, "modulate", original_modulate, 0.08)

	await tween.finished
