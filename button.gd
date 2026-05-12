extends Button

@export var hover_scale := Vector2(1.1, 1.1)
@export var normal_scale := Vector2(1.0, 1.0)

var current_hover_intensity := 0.0

func _ready() -> void:
	# Set pivot to center so it scales smoothly from the middle
	pivot_offset = size / 2.0
	
	# Connect built-in signals to trigger animations
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)

func _process(delta: float) -> void:
	# Smoothly interpolate the shader glow intensity
	var target_glow = 1.0 if is_hovered() else 0.0
	current_hover_intensity = move_toward(current_hover_intensity, target_glow, delta * 4.0)
	material.set_shader_parameter("hover_intensity", current_hover_intensity)

func _on_mouse_entered() -> void:
	# Animate button size expanding
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", hover_scale, 0.2)

func _on_mouse_exited() -> void:
	# Animate button size shrinking back
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", normal_scale, 0.2)

func _on_pressed() -> void:
	# Put your scene transition logic here
	print("Start Game Pressed!")
	# get_tree().change_scene_to_file("res://game.tscn")
