extends Node2D

## ═══════════════════════════════════════════════════════════════════════════
##  Simon Says — Complete Overhaul
##
##  HOW TO WIRE UP YOUR UI
##  ─────────────────────────────────────────────────────────────────────────
##  Connect these signals to Labels/Panels in your scene:
##    score_changed(score: int)          → score label
##    high_score_changed(hs: int)        → high-score label
##    lives_changed(lives: int)          → hearts / life counter
##    round_changed(round: int)          → round label
##    streak_changed(streak: int)        → combo label
##    state_changed(state: State)        → status text / animation triggers
##    game_over_triggered(final: int)    → game-over screen
##
##  SOUNDS
##  ─────────────────────────────────────────────────────────────────────────
##  In _build_audio_players() assign AudioStream resources to the four
##  AudioStreamPlayer nodes, e.g.:
##    _sfx_correct.stream = preload("res://sfx/correct.ogg")
##
##  SCREEN SHAKE
##  ─────────────────────────────────────────────────────────────────────────
##  Requires a Camera2D in the scene tree.  Set shake_strength = 0 to disable.
## ═══════════════════════════════════════════════════════════════════════════


# ── State machine ─────────────────────────────────────────────────────────────
enum State { IDLE, SHOWING_PATTERN, AWAITING_INPUT, GAME_OVER }


# ── Signals ───────────────────────────────────────────────────────────────────
signal score_changed(score: int)
signal high_score_changed(high_score: int)
signal lives_changed(lives: int)
signal round_changed(round: int)
signal streak_changed(streak: int)
signal state_changed(new_state: State)
signal game_over_triggered(final_score: int)


# ── Exports — tune everything from the Inspector ──────────────────────────────
@export_group("Timing")
@export var base_flash_on    := 0.42  ## Seconds a button stays lit during pattern
@export var base_flash_off   := 0.18  ## Gap between flashes
@export var min_flash_on     := 0.12  ## Speed floor (never faster than this)
@export var speed_per_round  := 0.012 ## How much faster each round

@export_group("Gameplay")
@export var starting_lives   := 3
## If true: wrong press costs a life but replays the same pattern.
## If false: wrong press resets pattern from round 1.
@export var wrong_retry      := true
## Consecutive correct presses needed to activate the combo multiplier.
@export var streak_threshold := 5

@export_group("Scoring")
@export var points_per_step  := 10
@export var combo_multiplier := 2

@export_group("Visuals")
## How opaque buttons are at rest (0 = invisible, 1 = full colour).
@export var dim_alpha        := 0.22
@export var shake_strength   := 6.0
@export var shake_duration   := 0.35


# ── Colour palette — one distinct colour per button ───────────────────────────
const PALETTE: Array[Color] = [
	Color(0.97, 0.22, 0.22),  # 0 — crimson
	Color(0.12, 0.84, 0.12),  # 1 — lime
	Color(0.20, 0.48, 1.00),  # 2 — cobalt
	Color(1.00, 0.84, 0.00),  # 3 — amber
	Color(1.00, 0.42, 0.00),  # 4 — blaze
	Color(0.72, 0.14, 1.00),  # 5 — violet
	Color(0.00, 0.91, 0.91),  # 6 — cyan
	Color(1.00, 0.28, 0.72),  # 7 — rose
	Color(0.42, 1.00, 0.42),  # 8 — mint
]
const WRONG_COLOR := Color(1.00, 0.06, 0.06)


# ── Persistence ───────────────────────────────────────────────────────────────
const SAVE_PATH := "user://simon_high_score.dat"


# ── Runtime state ─────────────────────────────────────────────────────────────
var _state:          State         = State.IDLE
var _pattern:        Array[int]    = []
var _player_seq:     Array[int]    = []
var _buttons:        Array[Button] = []
var _score:          int           = 0
var _high_score:     int           = 0
var _lives:          int           = 0
var _round:          int           = 0
var _streak:         int           = 0   # consecutive correct presses
var _input_locked:   bool          = false

# Audio players (streams assigned in _build_audio_players)
var _sfx_flash:    AudioStreamPlayer
var _sfx_correct:  AudioStreamPlayer
var _sfx_wrong:    AudioStreamPlayer
var _sfx_gameover: AudioStreamPlayer


# ═══════════════════════════════════════════════════════════════════════════════
#  INITIALISATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_load_high_score()
	_build_buttons()
	_build_audio_players()
	_dim_all()
	start_game()


func _build_buttons() -> void:
	# Rounded white stylebox — modulate tints it cleanly with any colour.
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color.WHITE
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		sbox.set("corner_radius_" + corner, 10)
	var empty := StyleBoxEmpty.new()

	for i in range(9):
		var node_name := "Button" if i == 0 else "Button%d" % (i + 1)
		var btn := get_node(node_name) as Button

		btn.flat = false
		for sname in ["normal", "hover", "pressed"]:
			btn.add_theme_stylebox_override(sname, sbox.duplicate())
		btn.add_theme_stylebox_override("focus", empty)

		_buttons.append(btn)
		btn.pressed.connect(_on_button_pressed.bind(i))


func _build_audio_players() -> void:
	var names := ["_sfx_flash", "_sfx_correct", "_sfx_wrong", "_sfx_gameover"]
	for var_name in names:
		var player := AudioStreamPlayer.new()
		add_child(player)
		set(var_name, player)
	# ── Assign your streams here ──────────────────────────────────────────
	# _sfx_correct.stream  = preload("res://sfx/correct.ogg")
	# _sfx_wrong.stream    = preload("res://sfx/wrong.ogg")
	# _sfx_gameover.stream = preload("res://sfx/gameover.ogg")
	# _sfx_flash.stream    = preload("res://sfx/tick.ogg")


# ═══════════════════════════════════════════════════════════════════════════════
#  PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Call this to fully restart the game (e.g. from a "Play Again" button).
func start_game() -> void:
	_score   = 0
	_lives   = starting_lives
	_round   = 0
	_streak  = 0
	_pattern.clear()
	score_changed.emit(_score)
	lives_changed.emit(_lives)
	streak_changed.emit(_streak)
	_start_next_round()


# ═══════════════════════════════════════════════════════════════════════════════
#  ROUND FLOW
# ═══════════════════════════════════════════════════════════════════════════════

func _start_next_round() -> void:
	_set_state(State.IDLE)
	_player_seq.clear()
	_input_locked = false
	_round += 1
	_pattern.append(randi() % 9)
	round_changed.emit(_round)

	await get_tree().create_timer(0.65).timeout
	await _play_pattern()
	_set_state(State.AWAITING_INPUT)


func _play_pattern() -> void:
	_set_state(State.SHOWING_PATTERN)

	# Speed increases each round, clamped to the configured floor.
	var on_t  := maxf(min_flash_on, base_flash_on  - _round * speed_per_round)
	var off_t := maxf(0.07,         base_flash_off - _round * speed_per_round * 0.5)

	for idx in _pattern:
		var btn := _buttons[idx]
		var col := PALETTE[idx]

		_play_sfx(_sfx_flash)

		# Snap to full colour.
		var tw_on := create_tween()
		tw_on.tween_property(btn, "modulate", col, 0.05)
		await get_tree().create_timer(0.05 + on_t).timeout

		# Fade back to dim.
		var tw_off := create_tween()
		tw_off.tween_property(btn, "modulate", _dim(idx), 0.10)
		await get_tree().create_timer(0.10 + off_t).timeout


# ═══════════════════════════════════════════════════════════════════════════════
#  INPUT HANDLING
# ═══════════════════════════════════════════════════════════════════════════════

func _on_button_pressed(id: int) -> void:
	if _state != State.AWAITING_INPUT or _input_locked:
		return
	_input_locked = true  # block further presses until this step resolves

	# Immediate visual + audio feedback.
	_buttons[id].modulate = PALETTE[id]
	_play_sfx(_sfx_flash)
	var tw := create_tween()
	tw.tween_property(_buttons[id], "modulate", _dim(id), 0.22)

	_player_seq.append(id)
	var step := _player_seq.size() - 1

	if _player_seq[step] != _pattern[step]:
		await _handle_wrong(step)
	elif _player_seq.size() == _pattern.size():
		await _handle_round_clear()
	else:
		_input_locked = false  # more presses remain — unlock immediately


func _handle_round_clear() -> void:
	_streak += _pattern.size()
	streak_changed.emit(_streak)

	# Combo bonus when streak is high.
	var multiplier := combo_multiplier if _streak >= streak_threshold else 1
	var gained     := points_per_step * _pattern.size() * multiplier
	_score += gained
	score_changed.emit(_score)

	if _score > _high_score:
		_high_score = _score
		_save_high_score()
		high_score_changed.emit(_high_score)

	_play_sfx(_sfx_correct)

	# Flash all buttons their own colour briefly as a "well done" flourish.
	var tw := create_tween().set_parallel(true)
	for i in range(9):
		tw.tween_property(_buttons[i], "modulate", PALETTE[i], 0.07)
	await get_tree().create_timer(0.30).timeout
	_dim_all_tweened(0.18)
	await get_tree().create_timer(0.40).timeout

	_start_next_round()


func _handle_wrong(step: int) -> void:
	_lives -= 1
	_streak = 0
	lives_changed.emit(_lives)
	streak_changed.emit(_streak)
	_play_sfx(_sfx_wrong)
	_screen_shake()

	var wrong_id := _player_seq[step]
	var right_id := _pattern[step]

	# Flash the incorrect button red.
	_buttons[wrong_id].modulate = WRONG_COLOR
	await get_tree().create_timer(0.28).timeout

	# Reveal the correct button so the player can learn.
	if wrong_id != right_id:
		_buttons[wrong_id].modulate = _dim(wrong_id)
		_buttons[right_id].modulate = PALETTE[right_id]
		await get_tree().create_timer(0.45).timeout

	_dim_all()

	if _lives <= 0:
		await _do_game_over()
		return

	await get_tree().create_timer(0.5).timeout

	if wrong_retry:
		# Replay the same pattern — player keeps their lives and tries again.
		_player_seq.clear()
		await _play_pattern()
		_set_state(State.AWAITING_INPUT)
		_input_locked = false
	else:
		# Hard mode: reset and start from scratch.
		_pattern.clear()
		_start_next_round()


func _do_game_over() -> void:
	_set_state(State.GAME_OVER)
	_play_sfx(_sfx_gameover)
	game_over_triggered.emit(_score)

	# Ripple all buttons red one by one.
	for i in range(9):
		_buttons[i].modulate = WRONG_COLOR
		await get_tree().create_timer(0.05).timeout

	await get_tree().create_timer(0.50).timeout

	# Fade everything back to dim together.
	_dim_all_tweened(0.80)
	await get_tree().create_timer(1.20).timeout

	_pattern.clear()
	await get_tree().create_timer(0.60).timeout
	start_game()


# ═══════════════════════════════════════════════════════════════════════════════
#  HELPERS — visuals
# ═══════════════════════════════════════════════════════════════════════════════

func _set_state(new_state: State) -> void:
	_state = new_state
	state_changed.emit(new_state)


## Returns the button's resting (dim) colour.
func _dim(index: int) -> Color:
	# Darken the palette colour rather than making it transparent.
	# This keeps each button visually distinct even when unlit.
	var c := PALETTE[index]
	return Color(c.r * dim_alpha, c.g * dim_alpha, c.b * dim_alpha, 1.0)


func _dim_all() -> void:
	for i in range(9):
		_buttons[i].modulate = _dim(i)


func _dim_all_tweened(duration: float) -> void:
	var tw := create_tween().set_parallel(true)
	for i in range(9):
		tw.tween_property(_buttons[i], "modulate", _dim(i), duration)


func _screen_shake() -> void:
	if shake_strength <= 0.0:
		return
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var origin := cam.offset
	var steps  := 8
	var tw     := create_tween()
	for i in range(steps):
		var t   := shake_duration / steps
		var mag := shake_strength * (1.0 - float(i) / steps)
		var off := Vector2(randf_range(-mag, mag), randf_range(-mag, mag))
		tw.tween_property(cam, "offset", origin + off, t)
	tw.tween_property(cam, "offset", origin, 0.05)


# ═══════════════════════════════════════════════════════════════════════════════
#  HELPERS — audio
# ═══════════════════════════════════════════════════════════════════════════════

func _play_sfx(player: AudioStreamPlayer) -> void:
	if player and player.stream:
		player.play()


# ═══════════════════════════════════════════════════════════════════════════════
#  PERSISTENCE
# ═══════════════════════════════════════════════════════════════════════════════

func _save_high_score() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_var(_high_score)


func _load_high_score() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f:
		_high_score = f.get_var()
		high_score_changed.emit(_high_score)
