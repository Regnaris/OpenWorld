extends Node

func _ready():
	pass

# Loads pre-generated clipmesh or generates new
func get_clip_mesh(lod_size:int, lod_levels:int) -> ArrayMesh:
	var fl = File.new()
	var fl_name:String = "clipmap_{0}_{1}.res".format([lod_size, lod_levels])
	var path = "user://cache/" + fl_name
	if fl.file_exists(path):
		var mesh = load(path)
		if mesh is ArrayMesh:
			print("Mesh loaded")
			return mesh
		else:
			print("Loading mesh error (loaded file not ArrayMesh)")
			return null
	else:
		var mesh = gen_clip_mesh(lod_size, lod_levels)
		ResourceSaver.save(path, mesh)
		print("Mesh generated and cached")
		return mesh

# Generates mesh for a clipmap
func gen_clip_mesh(lod_size, lod_levels) -> ArrayMesh:
	var mesh:ArrayMesh = ArrayMesh.new()
	var st = SurfaceTool.new()
	var n:int = pow(2, lod_size) + 1
	var m:int = (n + 1) / 4
	
	# Center square
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(n - 1):
		for y in range(n - 1):
			var p = Vector2(x - n / 2, y - n / 2)
			# First triangle
			st.add_vertex(Vector3(p.x, 0, p.y))
			st.add_vertex(Vector3(p.x + 1, 0, p.y))
			st.add_vertex(Vector3(p.x + 1, 0, p.y + 1))
			# Second triangle
			st.add_vertex(Vector3(p.x, 0, p.y))
			st.add_vertex(Vector3(p.x + 1, 0, p.y + 1))
			st.add_vertex(Vector3(p.x, 0, p.y + 1))
	st.index()
	var patch_array = st.commit_to_arrays()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, patch_array)
	
	for level in range(1, lod_levels):
		var lvl_scale = pow(2, level)
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var se = lod_verts(lod_size, level)
		for x in range(-se / 2.0, se / 2.0):
			for y in range(-se / 2.0, se / 2.0):
				var border = lod_verts(lod_size, level - 1) / 4.0
				var p = Vector2(x, y) * lvl_scale
				if (x <= -border or x > border) or (y <= -border or y > border):
					# First triangle
					st.add_vertex(Vector3(p.x, level, p.y))
					st.add_vertex(Vector3(p.x + lvl_scale, level, p.y))
					st.add_vertex(Vector3(p.x + lvl_scale, level, p.y + lvl_scale))
					# Second triangle
					st.add_vertex(Vector3(p.x, level, p.y))
					st.add_vertex(Vector3(p.x + lvl_scale, level, p.y + lvl_scale))
					st.add_vertex(Vector3(p.x, level, p.y + lvl_scale))
		st.index()
		patch_array = st.commit_to_arrays()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, patch_array)
		
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var si = lod_verts(lod_size, level - 1)
		for x in range(-si / 4, si / 4 + 1):
			var sc = lvl_scale
			var tst = (-(si - 1) / 2) * sc / 2
			# First X- triangle
			st.add_vertex(Vector3(x * sc, level, tst))
			st.add_vertex(Vector3(x * sc + sc, level, tst))
			st.add_vertex(Vector3(x * sc, level - 1, tst))
			# Second X- triangle
			if x < si / 4 - 1:
				st.add_vertex(Vector3(x * sc + sc, level, tst))
				st.add_vertex(Vector3(x * sc + sc, level - 1, tst))
				st.add_vertex(Vector3(x * sc, level - 1, tst))
				# Third X- triangle (seam)
				st.add_vertex(Vector3(x * sc + sc / 2.0, level - 1, tst))
				st.add_vertex(Vector3(x * sc, level - 1, tst))
				st.add_vertex(Vector3(x * sc + sc, level - 1, tst))
			# First Y- triangle
			st.add_vertex(Vector3(tst, level, x * sc))
			st.add_vertex(Vector3(tst, level - 1, x * sc))
			st.add_vertex(Vector3(tst, level, x * sc + sc))
			# Second Y- triangle
			if x < si / 4 - 1:
				st.add_vertex(Vector3(tst, level, x * sc + sc))
				st.add_vertex(Vector3(tst, level - 1, x * sc))
				st.add_vertex(Vector3(tst, level - 1, x * sc + sc))
				# Third Y- triangle (seam)
				st.add_vertex(Vector3(tst, level - 1, x * sc + sc / 2.0))
				st.add_vertex(Vector3(tst, level - 1, x * sc + sc))
				st.add_vertex(Vector3(tst, level - 1, x * sc))
			# First X+ triangle
			st.add_vertex(Vector3(-x * sc, level, -tst + sc))
			st.add_vertex(Vector3(-x * sc, level - 1, -tst))
			st.add_vertex(Vector3(-x * sc + sc, level, -tst + sc))
			# Second X+ triangle
			if x < si / 4 - 1:
				st.add_vertex(Vector3(-x * sc, level, -tst + sc))
				st.add_vertex(Vector3(-x * sc - sc, level - 1, -tst))
				st.add_vertex(Vector3(-x * sc, level - 1, -tst))
				# Third X+ triangle (seam)
				st.add_vertex(Vector3(-x * sc, level - 1, -tst))
				st.add_vertex(Vector3(-x * sc - sc, level - 1, -tst))
				st.add_vertex(Vector3(-x * sc - sc / 2.0, level - 1, -tst))
			# First Y+ triangle
			st.add_vertex(Vector3(-tst + sc, level, -x * sc))
			st.add_vertex(Vector3(-tst + sc, level, -x * sc + sc))
			st.add_vertex(Vector3(-tst, level - 1, -x * sc))
			# Second Y+ triangle
			if x < si / 4 - 1:
				st.add_vertex(Vector3(-tst + sc, level, -x * sc))
				st.add_vertex(Vector3(-tst, level - 1, -x * sc))
				st.add_vertex(Vector3(-tst, level - 1, -x * sc - sc))
				# Third Y+ triangle (seam)
				st.add_vertex(Vector3(-tst, level - 1, -x * sc))
				st.add_vertex(Vector3(-tst, level - 1, -x * sc - sc / 2.0))
				st.add_vertex(Vector3(-tst, level - 1, -x * sc - sc))
			
		st.index()
		patch_array = st.commit_to_arrays()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, patch_array)
	return mesh

func lod_verts(lod_size:int, level:int) -> float:
	return pow(2, lod_size) + 1#* pow(2, level) + 1
