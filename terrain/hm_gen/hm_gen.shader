shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// Generates heightmap where RG used to store height, and BA to store normal

uniform float frequency = 20.0;
uniform int octaves : hint_range(1, 15) = 2;
uniform float persistence : hint_range(0.0, 1.0) = 0.5;
uniform float lacunarity : hint_range(1.0, 5.0) = 2.0;
uniform bool mountain = false;
uniform float scale = 0.125;

// SimplexPerlin 2D with derivatives
void FAST32_hash_2D( vec2 gridcell, out vec4 hash_0, out vec4 hash_1 )	//	generates 2 random numbers for each of the 4 cell corners
{
    //    gridcell is assumed to be an integer coordinate
    const vec2 OFFSET = vec2( 26.0, 161.0 );
    const float DOMAIN = 71.0;
    const vec2 SOMELARGEFLOATS = vec2( 951.135664, 642.949883 );
    vec4 P = vec4( gridcell.xy, gridcell.xy + 1.0 );
    P = P - floor(P * ( 1.0 / DOMAIN )) * DOMAIN;
    P += OFFSET.xyxy;
    P *= P;
    P = P.xzxz * P.yyww;
    hash_0 = fract( P * ( 1.0 / SOMELARGEFLOATS.x ) );
    hash_1 = fract( P * ( 1.0 / SOMELARGEFLOATS.y ) );
}

vec3 SimplexPerlin2D_Deriv( vec2 P )
{
    //	simplex math constants
    const float SKEWFACTOR = 0.36602540378443864676372317075294;			// 0.5*(sqrt(3.0)-1.0)
    const float UNSKEWFACTOR = 0.21132486540518711774542560974902;			// (3.0-sqrt(3.0))/6.0
    const float SIMPLEX_TRI_HEIGHT = 0.70710678118654752440084436210485;	// sqrt( 0.5 )	height of simplex triangle
    const vec3 SIMPLEX_POINTS = vec3( 1.0-UNSKEWFACTOR, -UNSKEWFACTOR, 1.0-2.0*UNSKEWFACTOR );		//	vertex info for simplex triangle

    //	establish our grid cell.
    P *= SIMPLEX_TRI_HEIGHT;		// scale space so we can have an approx feature size of 1.0  ( optional )
    vec2 Pi = floor( P + dot( P, vec2( SKEWFACTOR ) ) );

    //	calculate the hash.
    //	( various hashing methods listed in order of speed )
    vec4 hash_x, hash_y;
    FAST32_hash_2D( Pi, hash_x, hash_y );
    //SGPP_hash_2D( Pi, hash_x, hash_y );

    //	establish vectors to the 3 corners of our simplex triangle
    vec2 v0 = Pi - dot( Pi, vec2( UNSKEWFACTOR ) ) - P;
    vec4 v1pos_v1hash = (v0.x < v0.y) ? vec4(SIMPLEX_POINTS.xy, hash_x.y, hash_y.y) : vec4(SIMPLEX_POINTS.yx, hash_x.z, hash_y.z);
    vec4 v12 = vec4( v1pos_v1hash.xy, SIMPLEX_POINTS.zz ) + v0.xyxy;

    //	calculate the dotproduct of our 3 corner vectors with 3 random normalized vectors
    vec3 grad_x = vec3( hash_x.x, v1pos_v1hash.z, hash_x.w ) - 0.49999;
    vec3 grad_y = vec3( hash_y.x, v1pos_v1hash.w, hash_y.w ) - 0.49999;
    vec3 norm = inversesqrt( grad_x * grad_x + grad_y * grad_y );
    grad_x *= norm;
    grad_y *= norm;
    vec3 grad_results = grad_x * vec3( v0.x, v12.xz ) + grad_y * vec3( v0.y, v12.yw );

    //	evaluate the surflet
    vec3 m = vec3( v0.x, v12.xz ) * vec3( v0.x, v12.xz ) + vec3( v0.y, v12.yw ) * vec3( v0.y, v12.yw );
    m = max(0.5 - m, 0.0);		//	The 0.5 here is SIMPLEX_TRI_HEIGHT^2
    vec3 m2 = m*m;
    vec3 m4 = m2*m2;

    //	calc the deriv
    vec3 temp = 8.0 * m2 * m * grad_results;
    float xderiv = dot( temp, vec3( v0.x, v12.xz ) ) - dot( m4, grad_x );
    float yderiv = dot( temp, vec3( v0.y, v12.yw ) ) - dot( m4, grad_y );

    const float FINAL_NORMALIZATION = 99.204334582718712976990005025589;	//	scales the final result to a strict 1.0->-1.0 range

    //	sum the surflets and return all results combined in a vec3
    return vec3( dot( m4, grad_results ), xderiv, yderiv ) * FINAL_NORMALIZATION;
}

// FBM with derivatives
vec3 fbm(vec2 pos) {
	vec3 noise = SimplexPerlin2D_Deriv(pos);
	float fq = frequency;
	float st = 1.0;
	float sum = 1.0;
	for (int oct = 1; oct < octaves; oct++) {
		fq *= lacunarity;
		st *= persistence;
		sum += st;
		noise += SimplexPerlin2D_Deriv(pos * fq) * st;
	}
	noise.x = ((noise.x / sum) + 1.0) / 2.0;
	return noise;
}

vec2 conv_16bit_to_2x8bit(float value) {
	int int_value = int(value * 65536.0);
	return vec2(
		float(int_value / 256) / 255.0,
		float(int_value % 256) / 255.0
	);
}

vec3 conv_24bit_to_3x8bit(float value) {
	int int_value = int(value * 16777216.0);
	return vec3(
		float(int_value / 65536) / 255.0,
		float((int_value / 256) % 256) / 255.0,
		float(int_value % 65536) / 255.0
	);
}

void fragment() {
	vec2 point = UV - vec2(0.5);
	vec3 noise = fbm(point);
	
	COLOR.ba = conv_16bit_to_2x8bit(noise.x);
}