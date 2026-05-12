extends ColorRect

func _process(_delta: float) -> void:
	# Get mouse position in local 0.0 to 1.0 coordinate space
	var mouse_pos = get_local_mouse_position() / size
	
	# Pass the vector directly to the shader uniform
	material.set_shader_parameter("mouse_position", mouse_pos)
