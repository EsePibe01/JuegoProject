extends Area2D

const SPEED = 500
var direction = 1 

func _process(delta):
	# Mover la bala hacia adelante
	position.x += SPEED * direction * delta

# Esta es la función que acabas de conectar:
func _on_body_entered(body):
	# Si choca con el jugador
	if body.is_in_group("player"):
		if body.has_method("recibir_danio"):
			body.recibir_danio(1) # Le quita 1 de vida
		queue_free() # La bala desaparece
	
	# Si choca con paredes (y no es el jefe)
	elif not body.is_in_group("enemy"):
		queue_free()
