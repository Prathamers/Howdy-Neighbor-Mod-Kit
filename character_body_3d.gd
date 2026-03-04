extends CharacterBody3D

@export_category("Movement Speeds")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var crouch_speed: float = 2.5
@export var jump_velocity: float = 7.0

@export_category("Mouse Settings")
@export var mouse_sensitivity: float = 0.002

var current_speed: float = walk_speed
var is_crouching: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- NODES ---
@onready var camera: Camera3D = $Camera3D
@onready var pickup_zone: Area3D = $Camera3D/PickupZone 
@onready var hold_position: Marker3D = $Camera3D/HoldPosition
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# --- PICKUP VARIABLES ---
var held_object: RigidBody3D = null
var original_collision_layer: int = 0
var original_collision_mask: int = 0

# --- CROUCHING VARIABLES ---
var original_camera_y: float
var original_shape_height: float
var original_shape_pos_y: float

func _ready() -> void:
	add_to_group("Player")
	
	# JOLT FIX: Save the actual height and position instead of scale
	original_camera_y = camera.position.y
	original_shape_pos_y = collision_shape.position.y
	if collision_shape.shape and "height" in collision_shape.shape:
		original_shape_height = collision_shape.shape.height
	
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# --- PICKUP LOGIC (Press 'E') ---
	if event is InputEventKey and event.physical_keycode == KEY_E and event.pressed and not event.echo:
		if held_object == null:
			try_pickup()
		else:
			drop_object()

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * mouse_sensitivity)
			camera.rotate_x(-event.relative.y * mouse_sensitivity)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta: float) -> void:
	# --- SPRINTING & CROUCHING LOGIC (JOLT FRIENDLY) ---
	if Input.is_physical_key_pressed(KEY_CTRL):
		current_speed = crouch_speed
		if not is_crouching:
			is_crouching = true
			camera.position.y = original_camera_y - 0.5
			# Halve the height, and shift the capsule down so our feet stay on the floor
			if collision_shape.shape and "height" in collision_shape.shape:
				collision_shape.shape.height = original_shape_height * 0.5
				collision_shape.position.y = original_shape_pos_y - (original_shape_height * 0.25)
	
	elif Input.is_physical_key_pressed(KEY_SHIFT) and not is_crouching:
		current_speed = sprint_speed
	
	else:
		current_speed = walk_speed
		if is_crouching:
			is_crouching = false
			camera.position.y = original_camera_y
			# Restore original height and position
			if collision_shape.shape and "height" in collision_shape.shape:
				collision_shape.shape.height = original_shape_height
				collision_shape.position.y = original_shape_pos_y

	# 1. Apply Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Handle Jump 
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_crouching:
		velocity.y = jump_velocity

	# 3. Handle Movement
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

	# 4. Handle Held Object Position
	if held_object != null:
		held_object.global_transform.origin = hold_position.global_transform.origin
		held_object.global_rotation = hold_position.global_rotation

# --- CUSTOM FUNCTIONS FOR INVENTORY/HOLDING ---

func try_pickup() -> void:
	var bodies = pickup_zone.get_overlapping_bodies()
	
	# DEBUG TEST: Prints everything the sphere sees to the console!
	print("BODIES IN ZONE: ", bodies)
	
	var closest_body: RigidBody3D = null
	var closest_distance: float = INF
	
	for body in bodies:
		if body is RigidBody3D:
			var distance = camera.global_position.distance_to(body.global_position)
			if distance < closest_distance:
				closest_body = body
				closest_distance = distance
				
	if closest_body != null:
		held_object = closest_body
		original_collision_layer = held_object.collision_layer
		original_collision_mask = held_object.collision_mask
		held_object.freeze = true
		held_object.collision_layer = 0
		held_object.collision_mask = 0
		print("Smart Picked up: ", held_object.name)

func drop_object() -> void:
	if held_object != null:
		held_object.freeze = false
		held_object.collision_layer = original_collision_layer
		held_object.collision_mask = original_collision_mask
		print("Dropped: ", held_object.name)
		held_object = null
