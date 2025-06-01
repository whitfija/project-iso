extends CharacterBody3D
@onready var animation_player: AnimationPlayer = $visuals/mixamo_base/AnimationPlayer
@onready var camera_mount: Node3D = $camera_mount
@onready var visuals: Node3D = $visuals


var SPEED = 2.8
const JUMP_VELOCITY = 4.5

var walking_speed = 2.8
var running_speed = 5.8
var running = false

var is_locked = false

@export var sens_horizontal = 0.3
@export var sens_vertical = 0.3

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		visuals.rotate_y(deg_to_rad(event.relative.x * sens_horizontal))
		camera_mount.rotate_x(deg_to_rad(-event.relative.y * sens_vertical))

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
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		if (!is_locked):
			if running:
				if animation_player.current_animation != "running":
					animation_player.play("running")
			else:	
				if animation_player.current_animation != "walking":
					animation_player.play("walking")

			visuals.look_at(position + direction)
			
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		if (!is_locked):
			if animation_player.current_animation != "idle":
				animation_player.play("idle")
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	if (!is_locked):
		move_and_slide()
