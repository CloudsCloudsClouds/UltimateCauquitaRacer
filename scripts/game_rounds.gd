# GameRounds - Central game coordinator
# Manages the full game loop:
# 1. Load random level
# 2. Players join in lobby (WAITING_FOR_PLAYERS) - can drive freely, respawn on death
# 3. Majority hits "ready" → competitive round starts (ROUND_ACTIVE)
# 4. Last car standing wins the round
# 5. First to max_rounds_to_win wins the game
# 6. Load next random level or podium

class_name GameRounds
extends Node3D

# ============================================
# EXPORTS
# ============================================

# Level Management
@export var levels: Array[PackedScene]
@export var win_level: PackedScene  # Podium scene

# Car Management
@export var car_scene: PackedScene

# Round Management
@export var max_rounds_to_win: int = 3

# Powerup Management (only during ROUND_ACTIVE)
@export var powerups: Array[PackedScene]
@export var powerup_spawn_interval := 2.0
@export var powerup_spawn_variance := 0.5

# ============================================
# STATE
# ============================================

enum GameState {
	WAITING_FOR_PLAYERS,  # Lobby phase - free roam, respawn on death
	ROUND_ACTIVE,         # Competitive - no respawn, powerups active
	ROUND_ENDED,          # Animation and transition
	GAME_ENDED            # Someone won the game
}

var game_state := GameState.WAITING_FOR_PLAYERS

# ============================================
# DATA STRUCTURES
# ============================================

# Level
var current_level: LevelInstance

# Player ↔ Car mapping
var player_cars := {}      # player_slot:int -> PlayerCar
var car_to_player := {}    # PlayerCar -> player_slot:int

# Scoring
var player_round_wins := {}   # player_slot:int -> int (rounds won)
var player_ready_status := {} # player_slot:int -> bool

# Timers
var round_timer := 0.0
var powerup_timer := 0.0

# ============================================
# LIFECYCLE
# ============================================

func _ready() -> void:
	# Connect to PlayerManager signals
	PlayerManager.player_joined.connect(_on_player_joined)
	PlayerManager.player_left.connect(_on_player_left)

	# Load first random level
	load_random_level()

func _process(delta: float) -> void:
	match game_state:
		GameState.WAITING_FOR_PLAYERS:
			_process_lobby(delta)
		GameState.ROUND_ACTIVE:
			_process_round(delta)
		GameState.ROUND_ENDED:
			pass  # Waiting for animation to complete
		GameState.GAME_ENDED:
			pass  # Game over

func _process_lobby(delta: float) -> void:
	# Handle join/leave inputs
	PlayerManager.handle_join_input()
	PlayerManager.handle_leave_input()

	# Handle ready inputs
	for player_slot in player_ready_status.keys():
		var device = PlayerManager.get_player_device(player_slot)
		if MultiplayerInput.is_action_just_pressed(device, "ready"):
			player_ready_status[player_slot] = !player_ready_status[player_slot]
			print("Player ", player_slot, " ready: ", player_ready_status[player_slot])

	# Check if majority is ready to start
	if check_majority_ready():
		transition_to_round_start()

func _process_round(delta: float) -> void:
	# Update round timer
	round_timer += delta

	# Handle powerup spawning
	if powerups.size() > 0:
		powerup_timer -= delta
		if powerup_timer <= 0:
			spawn_powerup()
			powerup_timer = powerup_spawn_interval + randf_range(-powerup_spawn_variance, powerup_spawn_variance)

	# TODO: Difficulty ramping
	# if round_timer > 60.0:
	#     break_brakes_of_all_cars()

	# Check for round winner
	var alive_cars = get_alive_cars()
	if alive_cars.size() == 1:
		var winner_car = alive_cars[0]
		end_round(winner_car)
	elif alive_cars.size() == 0:
		# Everyone died somehow? Restart round
		print("All cars destroyed! Restarting round...")
		transition_to_round_start()

# ============================================
# LEVEL MANAGEMENT
# ============================================

func load_random_level() -> void:
	if levels.is_empty():
		printerr("No levels to load!")
		return

	var random_level = levels.pick_random()
	load_level(random_level)

func load_level(level_scene: PackedScene) -> void:
	# Unload current level if exists
	if current_level:
		unload_level()

	# Instantiate and add new level
	current_level = level_scene.instantiate() as LevelInstance
	if !current_level:
		printerr("Failed to instantiate level!")
		return

	add_child(current_level)
	print("Level loaded: ", level_scene.resource_path)

func unload_level() -> void:
	if current_level:
		# Clear all cars first
		for car in player_cars.values():
			if is_instance_valid(car):
				car.queue_free()
		player_cars.clear()
		car_to_player.clear()

		# Remove level
		current_level.queue_free()
		current_level = null

func load_podium() -> void:
	if !win_level:
		print("No podium scene configured!")
		return

	load_level(win_level)
	game_state = GameState.GAME_ENDED
	print("Game ended! Loading podium...")

# ============================================
# PLAYER MANAGEMENT
# ============================================

func _on_player_joined(player_slot: int, device_id: int) -> void:
	print("GameRounds: Player ", player_slot, " joined with device ", device_id)

	# Initialize player data
	if !player_round_wins.has(player_slot):
		player_round_wins[player_slot] = 0

	player_ready_status[player_slot] = false

	# Only spawn car if in lobby (not during active round)
	if game_state == GameState.WAITING_FOR_PLAYERS:
		spawn_car_for_player(player_slot, device_id)

	# TODO: announce_player_joined() - visual/audio feedback

func _on_player_left(player_slot: int) -> void:
	print("GameRounds: Player ", player_slot, " left")

	# Destroy their car
	destroy_player_car(player_slot)

	# Clean up player data
	player_round_wins.erase(player_slot)
	player_ready_status.erase(player_slot)

	# If in round and not enough players, might need to handle this
	if game_state == GameState.ROUND_ACTIVE:
		var alive_cars = get_alive_cars()
		if alive_cars.size() <= 1:
			# Round might be decided now
			if alive_cars.size() == 1:
				end_round(alive_cars[0])
			else:
				# No one left, restart
				transition_to_round_start()

# ============================================
# CAR MANAGEMENT
# ============================================

func spawn_car_for_player(player_slot: int, device_id: int) -> void:
	if !current_level:
		printerr("Cannot spawn car: no level loaded!")
		return

	if !car_scene:
		printerr("Cannot spawn car: no car scene configured!")
		return

	# Instantiate car
	var car = car_scene.instantiate() as PlayerCar
	if !car:
		printerr("Failed to instantiate car!")
		return

	# Initialize car
	car.init(player_slot, device_id)

	# Set spawn position
	car.position = get_random_car_spawn_position()

	# Add to scene
	add_child(car)

	# Track car
	player_cars[player_slot] = car
	car_to_player[car] = player_slot

	# Connect to car's destroy signal
	if car.has_signal("destroy"):
		car.destroy.connect(_on_car_destroyed)
	else:
		printerr("Car does not have 'destroy' signal!")

	# Add to camera tracking
	if current_level.view_camera:
		current_level.view_camera.add_objective(car)

	print("Car spawned for player ", player_slot)

func destroy_player_car(player_slot: int) -> void:
	if !player_cars.has(player_slot):
		return

	var car = player_cars[player_slot]
	if !is_instance_valid(car):
		player_cars.erase(player_slot)
		return

	# Remove from camera
	if current_level and current_level.view_camera:
		current_level.view_camera.remove_objective(car)

	# Clean up tracking
	car_to_player.erase(car)
	player_cars.erase(player_slot)

	# Destroy car
	car.queue_free()

func _on_car_destroyed(car: PlayerCar) -> void:
	print("Car destroyed: ", car)

	# Get player slot
	if !car_to_player.has(car):
		printerr("Car destroyed but not tracked!")
		return

	var player_slot = car_to_player[car]

	# Remove from camera
	if current_level and current_level.view_camera:
		current_level.view_camera.remove_objective(car)

	# Clean up tracking
	car_to_player.erase(car)
	player_cars.erase(player_slot)

	# Handle based on game state
	match game_state:
		GameState.WAITING_FOR_PLAYERS:
			# Respawn immediately in lobby
			var device_id = PlayerManager.get_player_device(player_slot)
			if device_id != null:
				spawn_car_for_player(player_slot, device_id)

		GameState.ROUND_ACTIVE:
			# Permanent death - round logic will check for winner
			print("Player ", player_slot, " eliminated!")

func get_alive_cars() -> Array[PlayerCar]:
	var alive: Array[PlayerCar] = []
	for car in player_cars.values():
		if is_instance_valid(car):
			alive.append(car)
	return alive

func get_random_car_spawn_position() -> Vector3:
	if !current_level or !current_level.car_spawn_area:
		# Fallback position
		return Vector3(randf_range(-10, 10), 1, randf_range(-10, 10))

	return get_random_point_in_box(
		current_level.car_spawn_area.shape as BoxShape3D,
		current_level.car_spawn_area.global_transform
	)

# ============================================
# ROUND MANAGEMENT
# ============================================

func check_majority_ready() -> bool:
	var total_players = player_ready_status.size()

	# Need at least 2 players
	if total_players < 2:
		return false

	# Count ready players
	var ready_count = 0
	for is_ready in player_ready_status.values():
		if is_ready:
			ready_count += 1

	# Check if majority (more than half)
	return ready_count > (total_players / 2.0)

func transition_to_round_start() -> void:
	print("Starting round! Transitioning to competitive mode...")

	# Clear all lobby cars
	for car in player_cars.values():
		if is_instance_valid(car):
			# Remove from camera
			if current_level and current_level.view_camera:
				current_level.view_camera.remove_objective(car)
			car.queue_free()

	player_cars.clear()
	car_to_player.clear()

	# Reset ready status
	for player_slot in player_ready_status.keys():
		player_ready_status[player_slot] = false

	# Spawn fresh cars for the round
	for player_slot in player_ready_status.keys():
		var device_id = PlayerManager.get_player_device(player_slot)
		if device_id != null:
			spawn_car_for_player(player_slot, device_id)

	# Reset timers
	round_timer = 0.0
	powerup_timer = powerup_spawn_interval

	# Change state
	game_state = GameState.ROUND_ACTIVE
	print("Round started!")

func end_round(winner_car: PlayerCar) -> void:
	if !car_to_player.has(winner_car):
		printerr("Winner car not tracked!")
		return

	var winner_slot = car_to_player[winner_car]
	print("Round ended! Winner: Player ", winner_slot)

	# Change state
	game_state = GameState.ROUND_ENDED

	# Pause game
	get_tree().paused = true

	# Create animation tween
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # Continue during pause


	# Zoom to objective and wait one second
	# Cam3d can't zoom, so let's move the cam closer to the objective
	var cam := current_level.view_camera
	tween.tween_property(cam, "position", cam.position + Vector3(0, 0, -10), 1.0)
	tween.tween_interval(1.0)

	# Callback after animation
	tween.tween_callback(_on_round_end_animation_complete.bind(winner_slot))

func _on_round_end_animation_complete(winner_slot: int) -> void:
	# Unpause
	get_tree().paused = false

	# Award point
	player_round_wins[winner_slot] += 1
	print("Player ", winner_slot, " now has ", player_round_wins[winner_slot], " round wins")

	# Check if game is won
	if player_round_wins[winner_slot] >= max_rounds_to_win:
		print("Player ", winner_slot, " wins the game!")
		load_podium()
	else:
		# Load next level
		load_random_level()

		# Back to lobby
		game_state = GameState.WAITING_FOR_PLAYERS

		# Respawn all player cars
		for player_slot in player_ready_status.keys():
			var device_id = PlayerManager.get_player_device(player_slot)
			if device_id != null:
				spawn_car_for_player(player_slot, device_id)

# ============================================
# POWERUP MANAGEMENT
# ============================================

func spawn_powerup() -> void:
	if !current_level or powerups.is_empty():
		return

	var powerup_scene = powerups.pick_random()
	var powerup = powerup_scene.instantiate()

	powerup.position = get_random_powerup_spawn_position()

	# Add to level (not GameRounds)
	current_level.add_child(powerup)

func get_random_powerup_spawn_position() -> Vector3:
	if !current_level or !current_level.power_spawn_area:
		# Fallback position
		return Vector3(randf_range(-10, 10), 1, randf_range(-10, 10))

	return get_random_point_in_box(
		current_level.power_spawn_area.shape as BoxShape3D,
		current_level.power_spawn_area.global_transform
	)


# HELPER FUNCTIONS

func get_random_point_in_box(box: BoxShape3D, shape_transform: Transform3D) -> Vector3:
	if !box:
		return Vector3.ZERO

	var size = box.size

	# Random local position within box
	var local_pos = Vector3(
		randf_range(-size.x / 2.0, size.x / 2.0),
		randf_range(-size.y / 2.0, size.y / 2.0),
		randf_range(-size.z / 2.0, size.z / 2.0)
	)

	# Transform to global position
	var global_pos = shape_transform * local_pos

	return global_pos
