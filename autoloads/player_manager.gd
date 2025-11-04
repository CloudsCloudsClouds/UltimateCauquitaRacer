extends Node

signal player_joined(player_slot, device_id)
signal player_left(player_slot)

# Maps: Player Slot -> Data Dictionary
# { 0: {"device": 5, "score": 10}, 1: {"device": -1, "score": 0} }
var player_data: Dictionary = {}

# CRITICAL FIX 1: Add a reverse map.
# Maps: Device ID -> Player Slot
# { 5: 0, -1: 1 }
# This makes lookups *much* faster.
var device_to_slot_map: Dictionary = {}

const MAX_PLAYER = 8

func _ready():
	# CRITICAL FIX 2: Handle disconnects.
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

# --- Public API ---

func join(device: int) -> void:
	# 1. Check if device is already joined (now fast)
	if device_to_slot_map.has(device):
		return

	# 2. Find a slot
	var player_slot = next_viable_player()
	if player_slot < 0:
		return # Game is full

	# 3. Update *both* maps
	player_data[player_slot] = {
		"device": device
		# other data...
	}
	device_to_slot_map[device] = player_slot
	
	# 4. Tell the plugin to map this.
	# THIS IS THE MISSING LINK TO YOUR PLUGIN.
	# The name will be different based on your plugin.
	MultiplayerInput.assign_device_to_slot(device, player_slot)
	
	# 5. Emit signal
	player_joined.emit(player_slot, device)

func leave(player_slot: int) -> void:
	if !player_data.has(player_slot):
		return # This slot is already empty

	# 1. Get device ID *before* erasing
	var device = get_player_device(player_slot)

	# 2. Erase from both maps
	player_data.erase(player_slot)
	if device_to_slot_map.has(device): # Safety check
		device_to_slot_map.erase(device)
	
	# 3. Tell the plugin to unmap this.
	MultiplayerInput.unassign_slot(player_slot)

	# 4. Emit signal
	player_left.emit(player_slot)

# --- Input Handlers ---

func handle_join_input():
	for device in get_unjoined_devices():
		# This assumes your plugin is set up to map a "join" action
		# to all unassigned devices.
		if MultiplayerInput.is_action_just_pressed(device, "join"):
			join(device)

# You may also want a way for players to *choose* to leave
func handle_leave_input():
	for player_slot in get_player_indexes():
		var device = get_player_device(player_slot)
		# Assumes "ui_cancel" is mapped to the player's slot (p1_ui_cancel, etc.)
		if MultiplayerInput.is_action_just_pressed(device, "ui_cancel"):
			leave(player_slot)

# --- Getters / Setters ---

func get_player_count():
	return player_data.size()

func get_player_indexes():
	return player_data.keys()

# This is now fast and simple
func is_device_joined(device: int) -> bool:
	return device_to_slot_map.has(device)

# This is fast and simple
func get_slot_from_device(device: int) -> int:
	return device_to_slot_map.get(device, -1) # Returns -1 if not found

func get_unjoined_devices():
	var devices = Input.get_connected_joypads()
	devices.append(-1) # Add keyboard
	
	# Now *much* faster.
	return devices.filter(func(device): return !is_device_joined(device))

func next_viable_player() -> int:
	for i in MAX_PLAYER:
		if !player_data.has(i): return i
	return -1

# --- Signal Callback ---

func _on_joy_connection_changed(device: int, connected: bool):
	if !connected:
		# Device disconnected. Check if it was a player.
		var player_slot = get_slot_from_device(device)
		if player_slot != -1:
			# It was a player. Make them leave.
			leave(player_slot)

# --- (Your other helper functions like get/set_player_data are fine) ---

func get_player_device(player: int) -> int:
	return get_player_data(player, "device")

func get_player_data(player: int, key: StringName):
	if player_data.has(player) and player_data[player].has(key):
		return player_data[player][key]
	return null

func set_player_data(player: int, key: StringName, value: Variant):
	if !player_data.has(player):
		return
	player_data[player][key] = value
