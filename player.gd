extends CharacterBody2D

@export var max_speed := 300.0
@export var acceleration := 1500.0
@export var friction := 1200.0

func _physics_process(delta: float) -> void:
	# Fetch input direction vector based on project settings keys
	var input_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_direction != Vector2.ZERO:
		# Accelerate smoothly toward the input direction
		velocity = velocity.move_toward(input_direction * max_speed, acceleration * delta)
	else:
		# Apply friction to bring the player to a smooth stop
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	# Execute movement and handle collisions automatically
	move_and_slide()
