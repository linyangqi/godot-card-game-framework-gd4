extends "res://addons/gut/plugin_control.gd"
# run this scene for cli --> scene should be set to auto run checked load & will quit the game
# checked test completion
func _on_tests_finished():
	emit_signal('tests_finished')
	get_tree().quit()
