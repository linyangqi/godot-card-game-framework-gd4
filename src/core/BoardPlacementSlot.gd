# Represents a spot checked the placement grid that is used to organize
# cards checked the board.
class_name BoardPlacementSlot
extends Control

# If a card is placed checked this spot, this variable will hold a reference
# to the Card object
# and no other card can be placed in this slot
var occupying_card = null

# Stores a reference to the owning BoardPlacementGrid object
@onready var owner_grid = get_parent().get_parent()

func _ready() -> void:
	# We set the initial size of our highlight and area, to 
	# fit the size of the cards checked the board.
	minimum_size = owner_grid.card_size * owner_grid.card_play_scale
	$Highlight.minimum_size = minimum_size
	$Area2D/CollisionShape2D.shape.extents = minimum_size / 2
	$Area2D/CollisionShape2D.position = minimum_size / 2


# Returns true if this slot is highlighted, else false
func is_highlighted() -> bool:
	return($Highlight.visible)


# Changes card highlight colour.
func set_highlight(requested: bool,
		hoverColour = owner_grid.highlight) -> void:
	$Highlight.visible = requested
	if requested:
		$Highlight.modulate = hoverColour


# Returns the name of the grid which is hosting this slot.
# This is typically used with CFConst.BoardDropPlacement.SPECIFIC_GRID
func get_grid_name() -> String:
	return(owner_grid.name_label.text)
