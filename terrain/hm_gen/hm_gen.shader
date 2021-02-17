shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// Generates heightmap where RG used to store height, and BA to store normal

uniform float frequency = 20.0;
uniform int octaves : hint_range(1, 15) = 2;
uniform float persistence : hint_range(0.0, 1.0) = 0.5;
uniform float lacunarity : hint_range(1.0, 5.0) = 2.0;
uniform bool mountain = false;
uniform float scale = 0.125;

// Simplex 2D noise
//
vec3 permute(vec3 x) { return mod(((x*34.0)+1.0)*x, 289.0); }

float snoise(vec2 v){
  const vec4 C = vec4(0.211324865405187, 0.366025403784439,
           -0.577350269189626, 0.024390243902439);
  vec2 i  = floor(v + dot(v, C.yy) );
  vec2 x0 = v -   i + dot(i, C.xx);
  vec2 i1;
  i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;
  i = mod(i, 289.0);
  vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
  + i.x + vec3(0.0, i1.x, 1.0 ));
  vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy),
    dot(x12.zw,x12.zw)), 0.0);
  m = m*m ;
  m = m*m ;
  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;
  m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
  vec3 g;
  g.x  = a0.x  * x0.x  + h.x  * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

// FBM with derivatives
float fbm(vec2 pos) {
	float noise = snoise(pos);
	float fq = frequency;
	float st = 1.0;
	float sum = 1.0;
	for (int oct = 1; oct < octaves; oct++) {
		fq *= lacunarity;
		st *= persistence;
		sum += st;
		noise += snoise(pos * fq) * st;
	}
	noise = ((noise / sum) + 1.0) / 2.0;
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
	float noise = fbm(point);
	
	COLOR.ba = conv_16bit_to_2x8bit(noise);
}