# ##############################################################################
#(G)odot (U)nit (T)est class
#
# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2020 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################
# Description
# -----------
# This class is a PSUEDO SINGLETON.  You should not make instances of it but use
# the get_instance static method.
# ##############################################################################
extends Node

# ------------------------------------------------------------------------------
# The instance name as a function since you can't have static variables.
# ------------------------------------------------------------------------------
static func INSTANCE_NAME():
	return '__GutUtilsInstName__'

# ------------------------------------------------------------------------------
# Gets the root node without having to be in the tree and pushing out an error
# if we don't have a main loop ready to go yet.
# ------------------------------------------------------------------------------
static func get_root_node():
	var to_return = null
	var main_loop = Engine.get_main_loop()
	if(main_loop != null):
		return main_loop.root
	else:
		push_error('No Main Loop Yet')
		return null

# ------------------------------------------------------------------------------
# Get the ONE instance of utils
# ------------------------------------------------------------------------------
static func get_instance():
	var the_root = get_root_node()
	var inst = null
	if(the_root.has_node(INSTANCE_NAME())):
		inst = the_root.get_node(INSTANCE_NAME())
	else:
		inst = load('res://addons/gut/utils.gd').new()
		inst.set_name(INSTANCE_NAME())
		the_root.add_child(inst)
	return inst

var Logger = load('res://addons/gut/logger.gd') # everything should use get_logger
var _lgr = null

var _test_mode = false

var AutoFree = load('res://addons/gut/autofree.gd')
var Comparator = load('res://addons/gut/comparator.gd')
var CompareResult = load('res://addons/gut/compare_result.gd')
var DiffTool = load('res://addons/gut/diff_tool.gd')
var Doubler = load('res://addons/gut/doubler.gd')
var Gut = load('res://addons/gut/gut.gd')
var HookScript = load('res://addons/gut/hook_script.gd')
var InputFactory = load("res://addons/gut/input_factory.gd")
var InputSender = load("res://addons/gut/input_sender.gd")
var JunitXmlExport = load('res://addons/gut/junit_xml_export.gd')
var MethodMaker = load('res://addons/gut/method_maker.gd')
var OneToMany = load('res://addons/gut/one_to_many.gd')
var OrphanCounter = load('res://addons/gut/orphan_counter.gd')
var ParameterFactory = load('res://addons/gut/parameter_factory.gd')
var ParameterHandler = load('res://addons/gut/parameter_handler.gd')
var Printers = load('res://addons/gut/printers.gd')
var ResultExporter = load('res://addons/gut/result_exporter.gd')
var Spy = load('res://addons/gut/spy.gd')
var Strutils = load('res://addons/gut/strutils.gd')
var Stubber = load('res://addons/gut/stubber.gd')
var StubParams = load('res://addons/gut/stub_params.gd')
var Summary = load('res://addons/gut/summary.gd')
var Test = load('res://addons/gut/test.gd')
var TestCollector = load('res://addons/gut/test_collector.gd')
var ThingCounter = load('res://addons/gut/thing_counter.gd')

# Source of truth for the GUT version
var version = '7.3.0'
# The required Godot version as an array.
var req_godot = [3, 2, 0]
# Used for doing file manipulation stuff so as to not keep making File instances.
# could be a bit of overkill but who cares.
var _file_checker = File.new()
# Online fetch of the latest version available checked github
var latest_version = null
var should_display_latest_version = false


# These methods all call super implicitly.  Stubbing them to call super causes
# super to be called twice.
var non_super_methods = [
	"_init",
	"_ready",
	"_notification",
	"_enter_world",
	"_exit_world",
	"_process",
	"_physics_process",
	"_exit_tree",
	"_gui_input	",
]


func _ready() -> void:
	_http_request_latest_version()

func _http_request_latest_version() -> void:
	var http_request = HTTPRequest.new()
	http_request.name = "http_request"
	add_child(http_request)
	http_request.connect("request_completed",Callable(self,"_on_http_request_latest_version_completed"))
	# Perform a GET request. The URL below returns JSON as of writing.
	var error = http_request.request("https://api.github.com/repos/bitwes/Gut/releases/latest")

func _on_http_request_latest_version_completed(result, response_code, headers, body):
	if not result == HTTPRequest.RESULT_SUCCESS:
		return

	var test_json_conv = JSON.new()
	test_json_conv.parse(body.get_string_from_utf8())
	var response = test_json_conv.get_data()
	# Will print the user agent string used by the HTTPRequest node (as recognized by httpbin.org).
	if response:
		if response.get("html_url"):
			latest_version = Array(response.html_url.split("/")).pop_back().right(1)
			if latest_version != version:
				should_display_latest_version = true



const GUT_METADATA = '__gut_metadata_'

enum DOUBLE_STRATEGY{
	FULL,
	PARTIAL
}

enum DIFF {
	DEEP,
	SHALLOW,
	SIMPLE
}

# ------------------------------------------------------------------------------
# Blurb of text with GUT and Godot versions.
# ------------------------------------------------------------------------------
func get_version_text():
	var v_info = Engine.get_version_info()
	var gut_version_info =  str('GUT version:  ', version)
	var godot_version_info  = str('Godot version:  ', v_info.major,  '.',  v_info.minor,  '.',  v_info.patch)
	return godot_version_info + "\n" + gut_version_info


# ------------------------------------------------------------------------------
# Returns a nice string for erroring out when we have a bad Godot version.
# ------------------------------------------------------------------------------
func get_bad_version_text():
	var ver = '.'.join(PackedStringArray(req_godot))
	var info = Engine.get_version_info()
	var gd_version = str(info.major, '.', info.minor, '.', info.patch)
	return 'GUT ' + version + ' requires Godot ' + ver + ' or greater.  Godot version is ' + gd_version


# ------------------------------------------------------------------------------
# Checks the Godot version against req_godot array.
# ------------------------------------------------------------------------------
func is_version_ok(engine_info=Engine.get_version_info(),required=req_godot):
	var is_ok = null
	var engine_array = [engine_info.major, engine_info.minor, engine_info.patch]

	var idx = 0
	while(is_ok == null and idx < engine_array.size()):
		if(int(engine_array[idx]) > int(required[idx])):
			is_ok = true
		elif(int(engine_array[idx]) < int(required[idx])):
			is_ok = false

		idx += 1

	# still null means each index was the same.
	return nvl(is_ok, true)


# ------------------------------------------------------------------------------
# Everything should get a logger through this.
#
# When running in test mode this will always return a new logger so that errors
# are not caused by getting bad warn/error/etc counts.
# ------------------------------------------------------------------------------
func get_logger():
	if(_test_mode):
		return Logger.new()
	else:
		if(_lgr == null):
			_lgr = Logger.new()
		return _lgr



# ------------------------------------------------------------------------------
# return if_null if value is null otherwise return value
# ------------------------------------------------------------------------------
func nvl(value, if_null):
	if(value == null):
		return if_null
	else:
		return value


# ------------------------------------------------------------------------------
# returns true if the object has been freed, false if not
#
# From what i've read, the weakref approach should work.  It seems to work most
# of the time but sometimes it does not catch it.  The str comparison seems to
# fill in the gaps.  I've not seen any errors after adding that check.
# ------------------------------------------------------------------------------
func is_freed(obj):
	var wr = weakref(obj)
	return !(wr.get_ref() and str(obj) != '[Deleted Object]')


# ------------------------------------------------------------------------------
# Pretty self explanitory.
# ------------------------------------------------------------------------------
func is_not_freed(obj):
	return !is_freed(obj)


# ------------------------------------------------------------------------------
# Checks if the passed in object is a GUT Double or Partial Double.
# ------------------------------------------------------------------------------
func is_double(obj):
	var to_return = false
	if(typeof(obj) == TYPE_OBJECT and is_instance_valid(obj)):
		to_return = obj.has_method('__gut_instance_from_id')
	return to_return


# ------------------------------------------------------------------------------
# Checks if the passed in is an instance of a class
# ------------------------------------------------------------------------------
func is_instance(obj):
	return typeof(obj) == TYPE_OBJECT and !obj.has_method('new') and !obj.has_method('instance')

# ------------------------------------------------------------------------------
# Checks if the passed in is a GDScript
# ------------------------------------------------------------------------------
func is_gdscript(obj):
	return typeof(obj) == TYPE_OBJECT and str(obj).begins_with('[GDScript:')

# ------------------------------------------------------------------------------
# Returns an array of values by calling get(property) checked each element in source
# ------------------------------------------------------------------------------
func extract_property_from_array(source, property):
	var to_return = []
	for i in (source.size()):
		to_return.append(source[i].get(property))
	return to_return


# ------------------------------------------------------------------------------
# true if file exists, false if not.
# ------------------------------------------------------------------------------
func file_exists(path):
	return _file_checker.file_exists(path)


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
# true if what is passed in is null or an empty string.
# ------------------------------------------------------------------------------
func is_null_or_empty(text):
	return text == null or text == ''


# ------------------------------------------------------------------------------
# Get the name of a native class or null if the object passed in is not a
# native class.
# ------------------------------------------------------------------------------
func get_native_class_name(thing):
	var to_return = null
	if(is_native_class(thing)):
		var newone = thing.new()
		to_return = newone.get_class()
		if(!newone is RefCounted):
			newone.free()
	return to_return


# ------------------------------------------------------------------------------
# Checks an object to see if it is a GDScriptNativeClass
# ------------------------------------------------------------------------------
func is_native_class(thing):
	var it_is = false
	if(typeof(thing) == TYPE_OBJECT):
		it_is = str(thing).begins_with("[GDScriptNativeClass:")
	return it_is


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
# Loops through an array of things and calls a method or checks a property checked
# each element until it finds the returned value.  The item in the array is
# returned or null if it is not found.
# ------------------------------------------------------------------------------
func search_array(ar, prop_method, value):
	var found = false
	var idx = 0

	while(idx < ar.size() and !found):
		var item = ar[idx]
		if(item.get(prop_method) != null):
			if(item.get(prop_method) == value):
				found = true
		elif(item.has_method(prop_method)):
			if(item.call(prop_method) == value):
				found = true

		if(!found):
			idx += 1

	if(found):
		return ar[idx]
	else:
		return null


func are_datatypes_same(got, expected):
	return !(typeof(got) != typeof(expected) and got != null and expected != null)


func pretty_print(dict):
	print(str(JSON.print(dict, ' ')))


func get_script_text(obj):
	return obj.get_script().get_source_code()


func get_singleton_by_name(name):
	var source = str("var singleton = ", name)
	var script = GDScript.new()
	script.set_source_code(source)
	script.reload()
	return script.new().singleton
