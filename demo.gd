extends Spatial

const ROTATION_SPEED = 0.25

onready var pivot = $Position3D 

func _ready():
	pass # Replace with function body.

func _process(delta):
	pivot.rotate_y(ROTATION_SPEED * delta)
