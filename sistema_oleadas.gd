extends Node2D

# --- ARRASTRAR EN EL INSPECTOR ---
@export var hongo_scene: PackedScene
@export var puntos_de_spawn: Array[Marker2D]
@export var pantalla_victoria: Control

# --- CONFIGURACIÓN DE LAS 6 OLEADAS ---
# Aquí decides cuántos enemigos salen en cada ronda.
# Ronda 1: 2 enemigos
# Ronda 2: 4 enemigos
# ...
# Ronda 6: 15 enemigos (¡El caos final!)
var oleadas: Array[int] = [2, 4, 6, 8, 10, 15]

# --- VARIABLES INTERNAS ---
var oleada_actual_index: int = 0
var oleada_activa: bool = false
var esperando_siguiente_oleada: bool = false

func _ready():
	# 1. Preparar la pantalla de victoria (ocultarla)
	if pantalla_victoria:
		pantalla_victoria.visible = false
		var video = pantalla_victoria.get_node_or_null("VideoStreamPlayer")
		if video: video.stop()

	# 2. Esperar 3 segundos antes de que empiece la locura
	print("El juego comenzará en 3 segundos...")
	await get_tree().create_timer(3.0).timeout
	iniciar_oleada()

func _process(_delta):
	# Si estamos en descanso o no ha empezado, no hacemos nada
	if not oleada_activa or esperando_siguiente_oleada:
		return

	# 3. Verificar si quedan enemigos vivos
	# (Recuerda: Tus hongos deben estar en el grupo "enemigos")
	var enemigos_vivos = get_tree().get_nodes_in_group("enemigos").size()

	if enemigos_vivos == 0:
		terminar_oleada()

func iniciar_oleada():
	# 4. Verificar si ya ganamos (se acabaron las 6 rondas)
	if oleada_actual_index >= oleadas.size():
		victoria()
		return

	print("\n--- INICIANDO OLEADA ", oleada_actual_index + 1, " ---")
	
	var cantidad = oleadas[oleada_actual_index]
	spawnear_enemigos(cantidad)

	oleada_activa = true
	esperando_siguiente_oleada = false

func spawnear_enemigos(cantidad: int):
	if puntos_de_spawn.is_empty() or not hongo_scene:
		print("ERROR CRÍTICO: ¡Te falta asignar los Spawns o el Hongo en el Inspector!")
		return

	for i in range(cantidad):
		var nuevo_enemigo = hongo_scene.instantiate()

		# Elegir un spawn al azar de la lista
		var spawn_random = puntos_de_spawn.pick_random()
		nuevo_enemigo.global_position = spawn_random.global_position

		get_parent().call_deferred("add_child", nuevo_enemigo)

		# Pequeña pausa entre enemigos para que no salgan todos pegados
		await get_tree().create_timer(randf_range(0.8, 1.5)).timeout

func terminar_oleada():
	print("¡Oleada ", oleada_actual_index + 1, " completada!")
	oleada_activa = false
	esperando_siguiente_oleada = true
	oleada_actual_index += 1

	# 5. Descanso de 5 segundos para que el jugador respire
	print("Descanso de 5 segundos...")
	await get_tree().create_timer(5.0).timeout
	iniciar_oleada()

func victoria():
	print("¡JUEGO COMPLETADO! ERES EL JEFE.")
	oleada_activa = false
	
	if pantalla_victoria:
		# 1. Hacemos visible la capa (que ahora está en el CanvasLayer)
		pantalla_victoria.visible = true
		
		# 2. Buscamos el video y le damos Play
		var video = pantalla_victoria.get_node_or_null("VideoStreamPlayer")
		if video:
			video.play()
