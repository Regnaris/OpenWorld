class_name Terrain
extends Spatial

onready var mesh_instance = $MeshInstance
onready var terrain_material:ShaderMaterial = $MeshInstance.material_override

func _ready():
	var cm = ClipmapGen.get_clip_mesh(6,6)
	mesh_instance.mesh = cm
	HM_Gen.queue_hm_gen(Vector2(512, 512))
	HM_Gen.connect("heightmap_ready", self, "recieve_hm", [], CONNECT_ONESHOT)


func recieve_hm(heightmap:ViewportTexture):
	var img = heightmap.get_data()
	img.save_png("user://last_heightmap.png")
	var hm_tex:ImageTexture = ImageTexture.new()
	hm_tex.create_from_image(img, Texture.FLAG_MIPMAPS)
	terrain_material.set_shader_param("heightfield", hm_tex)
	print("HM recieved")
