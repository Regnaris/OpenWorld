extends Viewport

signal heightmap_ready

onready var canvas = $ColorRect

func queue_hm_gen(hm_size:Vector2):
	size = hm_size
	render_target_update_mode = Viewport.UPDATE_ONCE
	VisualServer.connect("frame_post_draw", self, "hm_ready", [], CONNECT_ONESHOT)


func hm_ready():
	var tx = get_texture()
	emit_signal("heightmap_ready", tx)
