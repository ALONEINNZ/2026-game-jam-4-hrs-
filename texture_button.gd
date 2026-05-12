extends TextureButton

@export var hover_scale := Vector2(1.1, 1.1)
@export var normal_scale := Vector2(1.0, 1.0)

@export var h_frames: int = 2
@export var v_frames: int = 1

var current_frame: int = 0
var current_hover_intensity := 0.0
var atlas_tex: AtlasTexture

func _ready() -> void:
	# Explicitly ensure pivot offset centers perfectly on a 32x24 pixel region
	pivot_offset = Vector2(16, 12)
	
	# Fetch the normal texture using self referencing to force context evaluation
	var base_texture = self.texture_normal
	
	if base_texture:
		atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = base_texture
		self.texture_normal = atlas_tex
		_update_sprite_frame()
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)

func _process(delta: float) -> void:
	var target_glow = 1.0 if is_hovered() else 0.0
	current_hover_intensity = move_toward(current_hover_intensity, target_glow, delta * 4.0)
	
	if material:
		material.set_shader_parameter("hover_intensity", current_hover_intensity)

func _on_mouse_entered() -> void:
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", hover_scale, 0.2)

func _on_mouse_exited() -> void:
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", normal_scale, 0.2)

func _on_pressed() -> void:
	var total_frames = h_frames * v_frames
	
	if total_frames > 1 and atlas_tex:
		current_frame = (current_frame + 1) % total_frames
		_update_sprite_frame()
	
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_file("res://node_2d.tscn")

func _update_sprite_frame() -> void:
	if not atlas_tex or not atlas_tex.atlas:
		return
		
	var tex_size = atlas_tex.atlas.get_size()
	var frame_w = tex_size.x / h_frames
	var frame_h = tex_size.y / v_frames
	
	var col = current_frame % h_frames
	var row = current_frame / h_frames
	
	atlas_tex.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
