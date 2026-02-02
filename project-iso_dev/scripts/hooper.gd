extends CharacterBody3D
@onready var animation_player: AnimationPlayer = $visuals/AnimationPlayer
@onready var yaw_pivot: Node3D = $yaw_pivot
@onready var camera_mount: Node3D = $yaw_pivot/camera_mount
@onready var visuals: Node3D = $visuals
@onready var limb_mount: Node3D = $visuals/metarig/Skeleton3D/limbs
@onready var ball_pickup_area: Area3D = $ball_pickup_area 
@onready var pickup_cooldown_timer: Timer = $pickup_cooldown
@onready var world: Node3D = $".."
@onready var anim_tree = $visuals/AnimationPlayer/AnimationTree

# hello world

var held_ball: RigidBody3D = null
var can_pickup = true

var SPEED = 2.8
const JUMP_VELOCITY = 4.5
const LERP = .15

var walking_speed = 2.8
var running_speed = 5.8
var running = false

var is_locked = false
var camera_rotation_y = 0.0
@export var sens_horizontal = 0.3
@export var sens_vertical = 0.3

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		camera_mount.rotate_x(deg_to_rad(-event.relative.y * sens_vertical))
		yaw_pivot.rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		var rotation_x = camera_mount.rotation.x
		rotation_x = clamp(rotation_x, deg_to_rad(-60), deg_to_rad(80)) # Example range
		camera_mount.rotation.x = rotation_x
	camera_rotation_y = yaw_pivot.global_transform.basis.get_euler().y
	
	if event.is_action_pressed("pickup_drop"):
		if held_ball != null:
			drop_ball()
		else:
			can_pickup = true
			
	if event.is_action_pressed("throw"):
		if held_ball != null:
			throw_ball()
			
func _physics_process(delta: float) -> void:
	# unlock when animation done
	if !animation_player.is_playing():
		is_locked = false
	
	# kick
	if Input.is_action_just_pressed("kick"):
		if animation_player.current_animation != "kick":
			animation_player.play("kick")
			is_locked = true
	
	# check for run
	if Input.is_action_pressed("run"):
		SPEED = running_speed
		running = true
	else:
		SPEED = walking_speed
		running = false
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var camera_basis = Transform3D().rotated(Vector3.UP, camera_rotation_y).basis
	var direction := (camera_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		if (!is_locked):
			var target_angle = atan2(-direction.x, -direction.z)
			visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, LERP)
		velocity.x = lerp(velocity.x, direction.x * SPEED, LERP)
		velocity.z = lerp(velocity.z, direction.z * SPEED, LERP)
	else:
		velocity.x = lerp(velocity.x, 0.0, LERP)
		velocity.z = lerp(velocity.z, 0.0, LERP)

	if (!is_locked):
		move_and_slide()
		anim_tree.set("parameters/BlendSpace1D/blend_position", velocity.length() / SPEED)
		anim_tree.set("parameters/TimeScale/scale", 1 + (velocity.length() / SPEED))

func drop_ball():
	if held_ball != null:
		# Disable the pickup area's monitoring and start the cooldown timer
		ball_pickup_area.monitoring = false
		pickup_cooldown_timer.start()
		
		# Reparent the ball to the main scene
		limb_mount.remove_child(held_ball)
		world.add_child(held_ball)
		
		# Position the ball at the hand's current global position
		held_ball.global_transform.origin = limb_mount.global_transform.origin
		
		# Enable physics simulation
		held_ball.freeze = false
		
		# Clear the held_ball variable
		held_ball = null
		

func throw_ball():
	if held_ball != null:
		# Disable the pickup area's monitoring and start the cooldown timer
		ball_pickup_area.monitoring = false
		pickup_cooldown_timer.start()
		
		# Reparent the ball to the main scene
		limb_mount.remove_child(held_ball)
		world.add_child(held_ball)
		
		# Position the ball at the hand's current global position
		held_ball.global_transform.origin = limb_mount.global_transform.origin
		
		# Enable physics simulation
		held_ball.freeze = false
		
		# Get the camera's forward direction
		var throw_direction = -camera_mount.global_transform.basis.z.normalized()
		
		# Apply an impulse to the ball
		var throw_speed = 10.0
		held_ball.apply_central_impulse(throw_direction * throw_speed)
		
		# Clear the held_ball variable
		held_ball = null

func _on_ball_pickup_area_body_entered(body: Node3D) -> void:
	# Exit if the player is already holding a ball
	if held_ball != null:
		return
	
	print(body.get_name())
	
	# Check if the body that entered the area is the basketball
	if body.is_in_group("basketballs") and Input.is_action_pressed("pickup_drop"):
		# Store a reference to the ball
		held_ball = body as RigidBody3D
		
		# Reparent the ball to the hand mount
		var original_parent = held_ball.get_parent()
		original_parent.remove_child(held_ball)
		limb_mount.add_child(held_ball)
		
		# Reset its local position and rotation relative to the hand mount
		held_ball.position = Vector3(2.361, 4.048, 12.794)
		held_ball.rotation = Vector3.ZERO
		held_ball.scale = limb_mount.global_transform.basis.get_scale().inverse()
		
		# Disable the ball's physics so it stays with the hand
		held_ball.freeze = true
		can_pickup = false

func _on_pickup_cooldown_timeout() -> void:
	ball_pickup_area.monitoring = true
