# Archivo: zona_muerte.gd
extends Area2D

# Función conectada a la señal 'body_entered'
func _on_body_entered(body: Node2D) -> void: 
	
	# 1. Chequea si el cuerpo es el jugador (debe estar en el grupo "player")
	if body.is_in_group("player"):
		# 2. Llama a la función die() del jugador 
		if body.has_method("die"):
			body.die()
		
	# 3. Opcional: Eliminar otros objetos 
	elif body is CharacterBody2D or body is RigidBody2D: 
		body.queue_free()
