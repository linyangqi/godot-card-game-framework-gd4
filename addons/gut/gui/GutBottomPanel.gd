@tool
extends Control

const RUNNER_JSON_PATH = 'res://.gut_editor_config.json'
const RESULT_FILE = 'user://.gut_editor.bbcode'
const RESULT_JSON = 'user://.gut_editor.json'
const SHORTCUTS_PATH = 'res://.gut_editor_shortcuts.cfg'

var TestScript = load('res://addons/gut/test.gd')
var GutConfigGui = load('res://addons/gut/gui/gut_config_gui.gd')

var _interface = null;
var _is_running = false;
var _gut_config = load('res://addons/gut/gut_config.gd').new()
var _gut_config_gui = null
var _gut_plugin = null
var _light_color = Color(0, 0, 0, .5)
var _panel_button = null
var _last_selected_path = null


@onready var _ctrls = {
	output = $layout/RSplit/CResults/Output,
	run_button = $layout/ControlBar/RunAll,
	settings = $layout/RSplit/sc/Settings,
	shortcut_dialog = $BottomPanelShortcuts,
	light = $layout/RSplit/CResults/ControlBar/Light3D,
	results = {
		passing = $layout/RSplit/CResults/ControlBar/Passing/value,
		failing = $layout/RSplit/CResults/ControlBar/Failing/value,
		pending = $layout/RSplit/CResults/ControlBar/Pending/value,
		errors = $layout/RSplit/CResults/ControlBar/Errors/value,
		warnings = $layout/RSplit/CResults/ControlBar/Warnings/value,
		orphans = $layout/RSplit/CResults/ControlBar/Orphans/value
	},
	run_at_cursor = $layout/ControlBar/RunAtCursor
}


func _init():
	_gut_config.load_panel_options(RUNNER_JSON_PATH)


func _ready():
	_gut_config_gui = GutConfigGui.new(_ctrls.settings)
	_gut_config_gui.set_options(_gut_config.options)
	_set_all_fonts_in_ftl(_ctrls.output, _gut_config.options.panel_options.font_name)
	_set_font_size_for_rtl(_ctrls.output, _gut_config.options.panel_options.font_size)


func _process(delta):
	if(_is_running):
		if(!_interface.is_playing_scene()):
			_is_running = false
			_ctrls.output.add_text("\ndone")
			load_result_output()
			_gut_plugin.make_bottom_panel_item_visible(self)

# ---------------
# Private
# ---------------

func load_shortcuts():
	_ctrls.shortcut_dialog.load_shortcuts(SHORTCUTS_PATH)
	_apply_shortcuts()


# -----------------------------------
func _set_font(rtl, font_name, custom_name):
	if(font_name == null):
		rtl.set('custom_fonts/' + custom_name, null)
	else:
		var dyn_font = FontFile.new()
		var font_data = FontFile.new()
		font_data.font_path = 'res://addons/gut/fonts/' + font_name + '.ttf'
		font_data.antialiased = true
		dyn_font.font_data = font_data
		rtl.set('custom_fonts/' + custom_name, dyn_font)


func _set_all_fonts_in_ftl(ftl, base_name):
	if(base_name == 'Default'):
		_set_font(ftl, null, 'normal_font')
		_set_font(ftl, null, 'bold_font')
		_set_font(ftl, null, 'italics_font')
		_set_font(ftl, null, 'bold_italics_font')
	else:
		_set_font(ftl, base_name + '-Regular', 'normal_font')
		_set_font(ftl, base_name + '-Bold', 'bold_font')
		_set_font(ftl, base_name + '-Italic', 'italics_font')
		_set_font(ftl, base_name + '-BoldItalic', 'bold_italics_font')


func _set_font_size_for_rtl(rtl, new_size):
	if(rtl.get('custom_fonts/normal_font') != null):
		rtl.get('custom_fonts/bold_italics_font').size = new_size
		rtl.get('custom_fonts/bold_font').size = new_size
		rtl.get('custom_fonts/italics_font').size = new_size
		rtl.get('custom_fonts/normal_font').size = new_size
# -----------------------------------


func _is_test_script(script):
	var from = script.get_base_script()
	while(from and from.resource_path != 'res://addons/gut/test.gd'):
		from = from.get_base_script()

	return from != null


func _update_last_run_label():
	var text = ''

	if(	_gut_config.options.selected == null and
		_gut_config.options.inner_class == null and
		_gut_config.options.unit_test_name == null):
		text = 'All'
	else:
		text = nvl(_gut_config.options.selected, '') + ' '
		text += nvl(_gut_config.options.inner_class, '') + ' '
		text += nvl(_gut_config.options.unit_test_name, '')



func _show_errors(errs):
	_ctrls.output.clear()
	var text = "Cannot run tests, you have a conrfiguration error:\n"
	for e in errs:
		text += str('*  ', e, "\n")
	text += "[right]Check your settings here ----->[/right]"
	_ctrls.output.text = text


func _run_tests():
	var issues = _gut_config_gui.get_config_issues()
	if(issues.size() > 0):
		_show_errors(issues)
		return

	write_file(RESULT_FILE, 'Run in progress')
	_gut_config.options = _gut_config_gui.get_options(_gut_config.options)
	_set_all_fonts_in_ftl(_ctrls.output, _gut_config.options.panel_options.font_name)
	_set_font_size_for_rtl(_ctrls.output, _gut_config.options.panel_options.font_size)

	var w_result = _gut_config.write_options(RUNNER_JSON_PATH)
	if(w_result != OK):
		push_error(str('Could not write options to ', RUNNER_JSON_PATH, ': ', w_result))
		return;

	_ctrls.output.clear()

	_update_last_run_label()
	_interface.play_custom_scene('res://addons/gut/gui/GutRunner.tscn')

	_is_running = true
	_ctrls.output.add_text('running...')


func _apply_shortcuts():
	_ctrls.run_button.shortcut = _ctrls.shortcut_dialog.get_run_all()

	_ctrls.run_at_cursor.get_script_button().shortcut = \
		_ctrls.shortcut_dialog.get_run_current_script()
	_ctrls.run_at_cursor.get_inner_button().shortcut = \
		_ctrls.shortcut_dialog.get_run_current_inner()
	_ctrls.run_at_cursor.get_test_button().shortcut = \
		_ctrls.shortcut_dialog.get_run_current_test()

	_panel_button.shortcut = _ctrls.shortcut_dialog.get_panel_button()


func _run_all():
	_gut_config.options.selected = null
	_gut_config.options.inner_class = null
	_gut_config.options.unit_test_name = null

	_run_tests()


# ---------------
# Events
# ---------------
func _on_editor_script_changed(script):
	if(script):
		set_current_script(script)


func _on_RunAll_pressed():
	_on_RunTests_pressed()


func _on_RunTests_pressed():
	_run_all()


func _on_CopyButton_pressed():
	OS.clipboard = _ctrls.output.text


func _on_ClearButton_pressed():
	_ctrls.output.clear()


func _on_Shortcuts_pressed():
	_ctrls.shortcut_dialog.popup_centered()


func _on_BottomPanelShortcuts_popup_hide():
	_apply_shortcuts()
	_ctrls.shortcut_dialog.save_shortcuts(SHORTCUTS_PATH)


func _on_Light_draw():
	var l = _ctrls.light
	l.draw_circle(Vector2(l.size.x / 2, l.size.y / 2), l.size.x / 2, _light_color)


func _on_RunAtCursor_run_tests(what):
	_gut_config.options.selected = what.script
	_gut_config.options.inner_class = what.inner_class
	_gut_config.options.unit_test_name = what.test_method

	_run_tests()


# ---------------
# Public
# ---------------

func load_result_output():
	_ctrls.output.text = get_file_as_text(RESULT_FILE)
	_ctrls.output.grab_focus()
	_ctrls.output.scroll_to_line(_ctrls.output.get_line_count() -1)

	var summary = get_file_as_text(RESULT_JSON)
	var test_json_conv = JSON.new()
	test_json_conv.parse(summary)
	var results = test_json_conv.get_data()
	if(results.error != OK):
		return
	var summary_json = results.result['test_scripts']['props']
	_ctrls.results.passing.text = str(summary_json.passing)
	_ctrls.results.passing.get_parent().visible = true

	_ctrls.results.failing.text = str(summary_json.failures)
	_ctrls.results.failing.get_parent().visible = true

	_ctrls.results.pending.text = str(summary_json.pending)
	_ctrls.results.pending.get_parent().visible = _ctrls.results.pending.text != '0'

	_ctrls.results.errors.text = str(summary_json.errors)
	_ctrls.results.errors.get_parent().visible = _ctrls.results.errors.text != '0'

	_ctrls.results.warnings.text = str(summary_json.warnings)
	_ctrls.results.warnings.get_parent().visible = _ctrls.results.warnings.text != '0'

	_ctrls.results.orphans.text = str(summary_json.orphans)
	_ctrls.results.orphans.get_parent().visible = _ctrls.results.orphans.text != '0' and !_gut_config.options.hide_orphans

	if(summary_json.tests == 0):
		_light_color = Color(1, 0, 0, .75)
	elif(summary_json.failures != 0):
		_light_color = Color(1, 0, 0, .75)
	elif(summary_json.pending != 0):
		_light_color = Color(1, 1, 0, .75)
	else:
		_light_color = Color(0, 1, 0, .75)
	_ctrls.light.update()



func set_current_script(script):
	if(script):
		if(_is_test_script(script)):
			var file = script.resource_path.get_file()
			_last_selected_path = script.resource_path.get_file()
			_ctrls.run_at_cursor.activate_for_script(script.resource_path)


func set_interface(value):
	_interface = value
	_interface.get_script_editor().connect("editor_script_changed",Callable(self,'_on_editor_script_changed'))
	_ctrls.run_at_cursor.set_script_editor(_interface.get_script_editor())
	set_current_script(_interface.get_script_editor().get_current_script())


func set_plugin(value):
	_gut_plugin = value


func set_panel_button(value):
	_panel_button = value

# ------------------------------------------------------------------------------
# Write a file.
# ------------------------------------------------------------------------------
func write_file(path, content):
	var f = File.new()
	var result = f.open(path, f.WRITE)
	if(result == OK):
		f.store_string(content)
		f.close()
	return result


# ------------------------------------------------------------------------------
# Returns the text of a file or an empty string if the file could not be opened.
# ------------------------------------------------------------------------------
func get_file_as_text(path):
	var to_return = ''
	var f = File.new()
	var result = f.open(path, f.READ)
	if(result == OK):
		to_return = f.get_as_text()
		f.close()
	return to_return


# ------------------------------------------------------------------------------
# return if_null if value is null otherwise return value
# ------------------------------------------------------------------------------
func nvl(value, if_null):
	if(value == null):
		return if_null
	else:
		return value


