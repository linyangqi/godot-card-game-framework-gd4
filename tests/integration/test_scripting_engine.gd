extends "res://tests/UTcommon.gd"

var cards := []
var card: Card 
var target: Card

func before_all():
	cfc.fancy_movement = false

func after_all():
	cfc.fancy_movement = true

func before_each():
	setup_board()
	cards = draw_test_cards(5)
	yield(yield_for(0.5), YIELD)
	card = cards[0]
	target = cards[2]


func test_basics():
	card.scripts = {"hand": [{'name': 'rotate_self','args': [270]}]}
	watch_signals(card.scripting_engine) 
	card._execute_scripts()
	assert_eq(card.scripting_engine.card_owner, card,
			"Scripting Engine owner card is self")
	assert_false(card.scripting_engine._common_target, 
			"_common_target should start false unless defined")
	assert_signal_emitted(card.scripting_engine,"scripts_completed")
	yield(drag_drop(card, Vector2(100,200)), 'completed')
	card._execute_scripts()
	assert_eq(target.card_rotation, 0, 
			"Script should not work from a different state")
	assert_signal_emitted(card.scripting_engine,"scripts_completed")

	# The below tests _common_target == false
	card.scripts = {"board": 
			[{'name': 'rotate_target','args': [270,false]},
			{'name': 'rotate_target','args': [90,false]}]}
	card._execute_scripts()
	yield(target_card(card,card), 'completed')
	yield(yield_to(card.get_node('Tween'), "tween_all_completed", 1), YIELD)
	assert_eq(card.card_rotation, 270, 
			"First rotation should happen before targetting second")
	yield(target_card(card,card), 'completed')
	yield(yield_to(card.get_node('Tween'), "tween_all_completed", 1), YIELD)
	assert_eq(card.card_rotation, 90, 
			"Second rotation should also happen")


# Checks that scripts from the CardScripts have been loaded correctly
func test_CardScripts():
	card = cards[0]
	target = cards[2]
	yield(drag_drop(target, Vector2(800,200)), 'completed')
	yield(drag_drop(card, Vector2(100,200)), 'completed')
	card._execute_scripts()
	yield(target_card(card,target,"slow"), 'completed')
	#yield(yield_for(1), YIELD)
	yield(yield_to(target.get_node('Tween'), "tween_all_completed", 1), YIELD)
	# This also tests the _common_target set
	assert_false(target.is_faceup, 
			"Test1 script leaves target facedown")
	assert_eq(target.card_rotation, 180, 
			"Test1 script rotates 180 degrees")


func test_rotate_self():
	card.scripts = {"board": [{'name': 'rotate_self','args': [90]}]}
	yield(drag_drop(card, Vector2(100,200)), 'completed')
	card._execute_scripts()
	yield(yield_to(card.get_node('Tween'), "tween_all_completed", 1), YIELD)
	assert_eq(card.card_rotation, 90, 
			"Test1 script rotates 90 degrees")


func test_rotate_target():
	card.scripts = {"board": [{'name': 'rotate_target','args': [270,false]}]}
	yield(drag_drop(target, Vector2(800,200)), 'completed')
	yield(drag_drop(card, Vector2(100,200)), 'completed')
	card._execute_scripts()
	yield(target_card(card,target), 'completed')
	#yield(yield_for(1), YIELD)
	yield(yield_to(target.get_node('Tween'), "tween_all_completed", 1), YIELD)
	assert_eq(target.card_rotation, 270, 
			"Target Rotated 270 degrees")