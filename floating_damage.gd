extends Marker2D

@onready var label: Label = $Label

# Variable temporal para guardar el valor hasta que el nodo esté listo
var damage_amount: int = 0 

func _ready():
	# Ahora que el nodo ya cargó (_ready), sí podemos tocar el Label
	if label:
		label.text = str(damage_amount)
		
		# Lógica de color: Rojo si es crítico (Black Flash), Blanco si es normal
		if damage_amount > 1:
			label.modulate = Color(1, 0, 0) # Rojo
			scale = Vector2(1.5, 1.5) # Grande
			label.z_index = 10
		else:
			label.modulate = Color(1, 1, 1) # Blanco
			scale = Vector2(1.0, 1.0)

	# --- Animación de flotar ---
	var tween = create_tween()
	
	# Mover hacia arriba aleatoriamente
	var random_x = randf_range(-20, 20)
	var target_pos = position + Vector2(random_x, -80)
	
	tween.tween_property(self, "position", target_pos, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Desvanecer
	var tween_alpha = create_tween()
	tween_alpha.tween_property(self, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN).set_delay(0.2)
	
	# Borrar al terminar
	tween.tween_callback(queue_free)

func setup(valor: int):
	# Solo guardamos el número en la variable. 
	# NO tocamos el label aquí para evitar el error "Nil".
	damage_amount = valor
