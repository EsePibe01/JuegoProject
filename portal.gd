extends Area2D

# --- CAMBIO IMPORTANTE ---
# En lugar de una constante fija, usamos una variable exportada.
# Esto te permite elegir el mapa de destino desde el Inspector de Godot.
@export_file("*.tscn") var next_scene_path: String = "" 

@export var float_height: float = 10.0
@export var float_speed: float = 2.0

var player_in_area := false
var start_y := 0.0
var t := 0.0
var fading := false

var interact_label: Label
var audio_player: AudioStreamPlayer
var particle_node: CPUParticles2D

func _ready():
	start_y = position.y

	# Animación del portal si existe
	if $AnimatedSprite2D.sprite_frames.has_animation("portal"):
		$AnimatedSprite2D.play("portal")

	# -------------------------------
	# CREAR TEXTO "Presiona Z"
	# -------------------------------
	interact_label = Label.new()
	interact_label.text = "Presiona Z"
	interact_label.visible = false
	interact_label.modulate = Color(0.9, 0.3, 0.6, 0.95) # rosado oscuro
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(interact_label)

	# Posicionar sobre el portal
	interact_label.position = Vector2(0, -60)

	# -------------------------------
	# CREAR AUDIO
	# -------------------------------
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)

	# -------------------------------
	# CREAR PARTÍCULAS
	# -------------------------------
	particle_node = CPUParticles2D.new()
	particle_node.amount = 40
	particle_node.lifetime = 1.5
	particle_node.emitting = true
	add_child(particle_node)

	# -------------------------------
	# SEÑALES
	# -------------------------------
	# Aseguramos que no estén conectadas previamente para evitar errores
	if not is_connected("body_entered", Callable(self, "_on_enter")):
		connect("body_entered", Callable(self, "_on_enter"))
	if not is_connected("body_exited", Callable(self, "_on_exit")):
		connect("body_exited", Callable(self, "_on_exit"))

func _process(delta):
	if fading:
		return

	t += delta
	position.y = start_y + sin(t * float_speed) * float_height

	if player_in_area and Input.is_action_just_pressed("interactuar"):
		activate_portal()

func activate_portal():
	if next_scene_path == "":
		print("⚠️ ERROR: No has seleccionado ninguna escena en el Inspector del Portal")
		return

	fading = true
	interact_label.visible = false

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.7)

	await tween.finished

	# Cambiar a la escena seleccionada en la variable
	get_tree().change_scene_to_file(next_scene_path)

func _on_enter(body):
	if body.is_in_group("player"):
		player_in_area = true
		interact_label.visible = true

func _on_exit(body):
	if body.is_in_group("player"):
		player_in_area = false
		interact_label.visible = false
