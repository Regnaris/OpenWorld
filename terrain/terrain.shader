shader_type spatial;
render_mode depth_draw_alpha_prepass;

uniform sampler2D dirt_texture: hint_albedo;
uniform sampler2D rock_texture: hint_albedo;
uniform sampler2D grass_texture: hint_albedo;
uniform sampler2D heightfield;
uniform bool use_triplanar = false;
uniform bool runtime_normals = true;
uniform vec2 offset;
uniform int cells_per_texel = 2;// How much cells to use for one heightmap
								// texel at max detail level. If >1 then data
								// will be interpolated using bicubic spline.
uniform float meters_per_texel = 1.0; // Size of one heightmap texel in units
uniform float HMTexelsPerMeter = 1.0;
uniform float tex_smoothing : hint_range(0.001, 0.2) = 0.1;
uniform float grass_level : hint_range(0.01, 1.0) = 0.8;
uniform float dirt_level : hint_range(0.01, 1.0) = 0.7;
uniform float height_scale = 100.0;

varying vec3 ws_vertex;


// Return value rounded to some increment/step
vec2 roundToIncrement(vec2 value, float increment) {
    return floor(value / increment) * increment;
}

// Convert two 8-bit float values to 16-bit float
float conv_2x8bit_to_float(vec2 val) {
	// vec2(255 / 256, 256 / (256 * 256))
	return dot(val, vec2(0.99609375, 0.00390625));
}

// Returns height at int position (cell height)
float get_cell_height(ivec2 pos) {
	ivec2 hf_size = textureSize(heightfield, 0);
	ivec2 coords = pos / int(meters_per_texel) + hf_size / 2;
	if (coords.x > 0 && coords.x < hf_size.x && coords.y > 0 && coords.y < hf_size.y) {
		return conv_2x8bit_to_float(texelFetch(heightfield, coords, 0).ba);
	} else {
		return 0.0;
	}
}

// Returns height at any position using bilinear interpolation
float get_height_bilinear(vec2 pos) {
	vec2 cell_offset = pos - floor(pos);
	ivec2 cell_pos = ivec2(floor(pos));
	float nwh = get_cell_height(cell_pos);
	float neh = get_cell_height(cell_pos + ivec2(1,0));
	float swh = get_cell_height(cell_pos + ivec2(0,1));
	float seh = get_cell_height(cell_pos + ivec2(1,1));
	return (
		nwh * (1.0 - cell_offset.x) * (1.0 - cell_offset.y) +
		neh * cell_offset.x * (1.0 - cell_offset.y) +
		swh * (1.0 - cell_offset.x) * cell_offset.y +
		seh * cell_offset.x * cell_offset.y
	);
}

float b_spline(float x)
{
	float f = x;
	if( f < 0.0 )
	{
		f = -f;
	}
	if( f >= 0.0 && f <= 1.0 )
	{
		return ( 2.0 / 3.0 ) + ( 0.5 ) * ( f* f * f ) - (f*f);
	}
	else if( f > 1.0 && f <= 2.0 )
	{
		return 1.0 / 6.0 * pow( ( 2.0 - f  ), 3.0 );
	}
	return 1.0;
}  

// Returns height at any position using bicubic interpolation
float get_height_bicubic(vec2 pos) {
	vec2 cell_offset = pos - floor(pos);
	ivec2 cell_pos = ivec2(floor(pos));
	float sum = 0.0;
	float denom = 0.0;
	for (int m = -1; m <= 2; m++) {
		for (int n = -1; n <= 2; n++) {
			float h = get_cell_height(cell_pos + ivec2(m, n));
			float fx = b_spline(float(m) - cell_offset.x);
			float fy = b_spline(float(n) - cell_offset.y);
			sum += h * fx * fy;
			denom += fx * fy;
		}
	}
	return sum / denom;
}


// Return UVs for triplanar texture mapping
vec3 triplanar(sampler2D tex, vec3 pos, vec3 normal) {
	vec3 albedo_x = texture(tex, pos.zy + vec2(0.0, 0.5)).rgb;
	vec3 albedo_y = texture(tex, pos.zx).rgb;
	vec3 albedo_z = texture(tex, pos.xy + vec2(0.5, 0.0)).rgb;
	vec3 abs_norm = abs(normal.xyz);
	vec3 tri_w = abs_norm / (abs_norm.x + abs_norm.y + abs_norm.z);
	return albedo_x * tri_w.x + albedo_y * tri_w.y + albedo_z * tri_w.z;
}


void vertex() {
	vec3 ws_camera;
	ws_camera = (CAMERA_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float grid_level = VERTEX.y;
	
	// Based on the grid, used for snapping the grid
	float lod_cells_per_texel = exp2(grid_level) / float(cells_per_texel);
	
	// Translation of the grid at this vertex
	vec2 objectToWorld = roundToIncrement(ws_camera.xz, lod_cells_per_texel * 2.0);
	
	ws_vertex = vec3(
		VERTEX.x / float(cells_per_texel) + objectToWorld.x,
		0.0,
		VERTEX.z / float(cells_per_texel) + objectToWorld.y
	);
	
	// ws_vertex.y = get_height_bicubic(ws_vertex.xz) * height_scale;
	// No visible difference between interpolated and non-interpolated at 
	// low detail levels. Can help only to interpolate heightmap data when
	// using multiple cells per one heighmap texel.
	if (exp2(ws_vertex.y) / float(cells_per_texel) < 1.0) {
		//ws_vertex.y = get_cell_height(ivec2(ws_vertex.xz)) * height_scale;
		ws_vertex.y = get_height_bicubic(ws_vertex.xz) * height_scale;
	} else {
		ws_vertex.y = get_cell_height(ivec2(ws_vertex.xz)) * height_scale;
	}
	
	VERTEX.xyz = ws_vertex.xyz;
}

void fragment() {
	// Discard fragments out of terrain bounds
	float map_size = float(textureSize(heightfield, 0).x);
	vec2 coords = ws_vertex.xz / meters_per_texel + map_size / 2.0;
	if (!(coords.x > 1.0 && coords.x < map_size - 1.0 &&
		coords.y > 1.0 && coords.y < map_size - 1.0)) {
		discard;
	}
	
	
	vec3 os_normal;
	if (runtime_normals) {
		// Calculate normals using finite difference method
		vec3 off = vec3(1.0, 1.0, 0.0);
		float hL = get_height_bicubic(ws_vertex.xz - off.xz);
		float hR = get_height_bicubic(ws_vertex.xz + off.xz);
		float hD = get_height_bicubic(ws_vertex.xz - off.zy);
		float hU = get_height_bicubic(ws_vertex.xz + off.zy);
		os_normal = normalize(vec3(
			hL - hR,
			hD - hU,
			2.0 / height_scale
		));
	} else {
		// Get normal data from heightmap and calculate normal in worldspace and view space
		vec2 hf_size = vec2(textureSize(heightfield, 0));
		vec2 norm_data = texture(heightfield, ((ws_vertex.xz / meters_per_texel) / hf_size) + vec2(0.5), 0).rg;
		norm_data = norm_data * 2.0 - 1.0;
		os_normal = normalize(vec3(
			norm_data.x,
			-norm_data.y,
			sqrt(max(0.0, 1.0 - dot(norm_data.xy, norm_data.xy)))
		));
	}
	NORMAL = (INV_CAMERA_MATRIX * vec4(os_normal, 0.0)).xyz;
	
	vec3 dirt_albedo;
	vec3 rock_albedo;
	vec3 grass_albedo;
	if (use_triplanar) { // TODO: Sample only necessary data from textures
		dirt_albedo = triplanar(dirt_texture, ws_vertex / 4.0, os_normal.xyz);
		rock_albedo = triplanar(rock_texture, ws_vertex / 4.0, os_normal.xyz);
		grass_albedo = triplanar(grass_texture, ws_vertex / 4.0, os_normal.xyz);
	} else {
		dirt_albedo = texture(dirt_texture, ws_vertex.xz / 4.0).rgb;
		rock_albedo = texture(rock_texture, ws_vertex.xz / 4.0).rgb;
		grass_albedo = texture(grass_texture, ws_vertex.xz / 4.0).rgb;
	}

	// Texture splatting
	float steepness = 1.0 - os_normal.y;
	if (steepness > dirt_level) {
		ALBEDO = rock_albedo;
	} else if (steepness > grass_level) {
		float weight = (dirt_level - steepness) / tex_smoothing;
		if (weight > 1.0) {weight = 1.0;}
		ALBEDO = mix(rock_albedo, dirt_albedo, weight);
	} else {
		float weight = (grass_level - steepness) / tex_smoothing;
		if (weight > 1.0) {weight = 1.0;}
		ALBEDO = mix(dirt_albedo, grass_albedo, weight);
	}
}