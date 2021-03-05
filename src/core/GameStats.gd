# This class handles submitting game stats 
# to a [CGF-Stats](https://github.com/db0/CGF-Stats) instance
# It requires CFConst.STATS_URI and CFConst.STATS_PORT to be set
# And the game name in the Project > Settings should match the
# game name set when running CGF-Stats.
class_name GameStats
extends Reference

# Stores the unique id for this match. It is used to submit final results
var game_uuid : String


# Initiates the game stats for this game as soon as this object is instanced
func _init(deck = {}):
	call_api("new_game", deck)


# Submits results of the game (victory/defeat etc) to the CFG-Stats
func complete_game(game_data):
	call_api("complete_game", game_data)


# Handles calling CGF-Stats for all request types.
func call_api(type = "new_game", game_data = null):
	# Convert data to json string:
	# Add 'Content-Type' header:
	var err = 0
	# Create the Client.
	var http = HTTPClient.new()
	# Connect to host/port.
	err = http.connect_to_host(CFConst.STATS_URI, CFConst.STATS_PORT)
	# Make sure connection was OK.
	assert(err == OK)

	# Wait until resolved and connected.
	while http.get_status() == HTTPClient.STATUS_CONNECTING\
			or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(500)

	# Could not connect
	assert(http.get_status() == HTTPClient.STATUS_CONNECTED)

	var headers = ["Content-Type: application/json"]
	match type:
		"new_game":
			var data := {
				"game_name": ProjectSettings.get_setting(
							"application/config/name"),
				# We're expecting the game_data to be deck dict
				"deck": game_data
			}
			var query = JSON.print(data)
			err = http.request(
				HTTPClient.METHOD_POST,
				"/newgame/",
				headers,
				query)
		"complete_game":
			var data := {
				# We're expecting the game_data to be dict
				# with the final game state as "Victory" or "Loss"
				# But your game could pass whatever
				"state": game_data.get('state'),
			}
			var query = JSON.print(data)
			err = http.request(
				HTTPClient.METHOD_PUT,
				"/game/" + game_uuid,
				headers,
				query)
	# Make sure all is OK.
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		# Keep polling for as long as the request is being processed.
		http.poll()
		if not OS.has_feature("web"):
			OS.delay_msec(500)
		else:
			# Synchronous HTTP requests are not supported on the web,
			# so wait for the next main loop iteration.
			yield(Engine.get_main_loop(), "idle_frame")
	# Make sure request finished well.
	assert(http.get_status() == HTTPClient.STATUS_BODY\
			or http.get_status() == HTTPClient.STATUS_CONNECTED)

	if http.has_response():
		# If there is a response...
		headers = http.get_response_headers_as_dictionary() # Get response headers.
		if http.get_response_code() == 201:
			# Array that will hold the data.
			var rb = PoolByteArray()

			while http.get_status() == HTTPClient.STATUS_BODY:
				# While there is body left to be read
				http.poll()
				# Get a chunk.
				var chunk = http.read_response_body_chunk()
				if chunk.size() == 0:
					# Got nothing, wait for buffers to fill a bit.
					OS.delay_usec(1000)
				else:
					# Append to read buffer.
					rb = rb + chunk
			game_uuid = rb.get_string_from_ascii()
		elif http.get_response_code() == 403:
			print_debug("WARNING: Game Stats server reported that this is "\
					+ "the wrong game name! Please check your URL.")
		elif http.get_response_code() == 404:
			print_debug("WARNING: Stats for this game have not been initiated.")
		elif http.get_response_code() == 409:
			print_debug("WARNING: Game has already been resolved.")
		else:
			print_debug("WARNING: Could submit game stats."\
					+ "Server response code:" + http.get_response_code())
	# We don't want to keep the connection open indefinitelly
	http.close()
