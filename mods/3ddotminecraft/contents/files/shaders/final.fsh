/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 									Shader Modified From Martinsh's Blender GLSL 2D Filter Demo:							   //
//http://blenderartists.org/forum/showthread.php?156482-HDR-many-simple-GLSL-2D-Filters-v2.0&s=bbeb20ac111931da170fd6f8fea28d25//
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// If you want a higher quality blur, remove the forward slashes from the following line:
uniform sampler2D sampler0;
uniform sampler2D sampler1;
uniform sampler2D sampler2;

const float BRIGHT_PASS_THRESHOLD = 0.5;
const float BRIGHT_PASS_OFFSET = 0.5;
float contrast = 1.04;
float samples = 0.0;
vec2 space;
//Bloom
#define BLURCLAMP 0.002 
#define BIAS 0.01
#define KERNEL_SIZE  3.0

uniform float aspectRatio;
uniform float near;
uniform float far;

// HYPERFOCAL = (Focal Distance ^ 2)/(Circle of Confusion * F Stop) + Focal Distance
#define HYPERFOCAL_LEICA_M9_50mm_f16 5.26
#define HYPERFOCAL_LEICA_M9_50mm_f22 3.73
#define HYPERFOCAL_LEICA_M9_50mm_f32 2.65
#define HYPERFOCAL_50mm 5.20800
#define HYPERFOCAL_DEFAULT 3.132
// should be lower than hyperfocal
#define FOCAL_DEPTH 2.5 
const float HYPERFOCAL = HYPERFOCAL_DEFAULT;
const float PICONSTANT = 3.14159;

//shiny water
//#define SHINY_WATER
varying float texID;
int getTextureID(vec2 coord);

float getCursorDepth(vec2 coord);
float getDepth(vec2 coord);
vec4 getBloomColor(vec4 baseColor);
vec4 getDoFColor();
vec4 getSampleWithBoundsCheck(vec2 offset);
vec2 texcoord = vec2(gl_TexCoord[0]).st;
vec4 texcolor = texture2D(sampler0, gl_TexCoord[0].st);

vec4 bright(vec2 coo)
{
	vec4 color = texture2D(sampler0, coo);
	color = max(color - BRIGHT_PASS_THRESHOLD, 0.0);
	return color / (color + BRIGHT_PASS_OFFSET);	
}
//

//Cross Processing
vec4 gradient(vec4 coo)
{
	vec4 stripes = coo;
	stripes.r =  stripes.r*1.3+0.01;
	stripes.g = stripes.g*1.2;
	stripes.b = stripes.b*0.7+0.15;
	stripes.a = texcolor.a;
	return stripes;
}
//

void main(void)
{
	vec4 baseColor = texture2D(sampler0, gl_TexCoord[0].st);
	float depth = getDepth(gl_TexCoord[0].st);

	if (depth >= far) {
		// Skybox
		gl_FragColor = baseColor;		
		return;
	}

	float cursorDepth = getCursorDepth(vec2(0.5, 0.5));

	float hyperfocal = HYPERFOCAL;
    // foreground blur = 1/2 background blur. Blur should follow exponential pattern until cursor = hyperfocal -- Cursor before hyperfocal
    // Blur should go from 0 to 1/2 hyperfocal then clear to infinity -- Cursor @ hyperfocal.
    // hyperfocal to inifity is clear though dof extends from 1/2 hyper to hyper -- Cursor beyond hyperfocal
    float mixAmount = 0.0;
    
    if (depth < cursorDepth) {
    		mixAmount = clamp(2.0 * ((clamp(cursorDepth, 0.0, hyperfocal) - depth) / (clamp(cursorDepth, 0.0, hyperfocal))), 0.0, 1.0);
	} else if (cursorDepth == hyperfocal) {
		mixAmount = 0.0;
	} else {
		mixAmount =  1.0 - clamp((((cursorDepth * hyperfocal) / (hyperfocal - cursorDepth)) - (depth - cursorDepth)) / ((cursorDepth * hyperfocal) / (hyperfocal - cursorDepth)), 0.0, 1.0);
	}




	
    if (mixAmount != 0.0) {
		vec4 col = getDoFColor();
///		gl_FragColor = mix(baseColor, col, mixAmount);
		baseColor = mix(baseColor, col, mixAmount);
   	} else {
   		//gl_FragColor = baseColor;
   	}

	gl_FragColor = getBloomColor(baseColor);

}

float getDepth(vec2 coord) {
	float depth = texture2D(sampler1, coord).x;
	float depth2 = texture2D(sampler2, coord).x;
	if (depth2 < 1.0) {
		depth = depth2;
	}
	
    depth = 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
    
    return depth;
}

vec4 getBloomColor(vec4 baseColor) {
	vec4 bloomColor = vec4(0.0, 0.0, 0.0, 0.0);
	vec2 blur = vec2(clamp( BIAS, -BLURCLAMP, BLURCLAMP ));

	for ( float x = -KERNEL_SIZE + 1.0; x < KERNEL_SIZE; x += 1.0 )
	{
	for ( float y = -KERNEL_SIZE + 1.0; y < KERNEL_SIZE; y += 1.0 )
	{
		 bloomColor += bright( texcoord + vec2( blur.x * x, blur.y * y ) );
	}
	}
	bloomColor /= ((KERNEL_SIZE+KERNEL_SIZE)-1.0)*((KERNEL_SIZE+KERNEL_SIZE)-1.0);
			
	vec4 fin = bloomColor + gradient(baseColor);
	bloomColor = (fin - 0.5) * contrast + 0.5;

	return bloomColor;
}

vec4 getDoFColor() {
	vec4 blurredColor = vec4(0.0);
	float depth = getDepth(gl_TexCoord[0].xy);
	vec2 aspectCorrection = vec2(1.0, aspectRatio) * 0.005;

	vec2 ac0_4 = 0.4 * aspectCorrection;	// 0.
	vec2 ac0_29 = 0.29 * aspectCorrection;	// 0.29
	vec2 ac0_15 = 0.15 * aspectCorrection;	// 0.15
	vec2 ac0_37 = 0.37 * aspectCorrection;	// 0.37
	vec2 lowSpace = gl_TexCoord[0].st;
	vec2 highSpace = 1.0 - lowSpace;
	space = vec2(min(lowSpace.s, highSpace.s), min(lowSpace.t, highSpace.t));
		
	if (space.s >= ac0_4.s && space.t >= ac0_4.t) {

		blurredColor += texture2D(sampler0, gl_TexCoord[0].st + vec2(0.0, ac0_4.t));
		blurredColor += texture2D(sampler0, gl_TexCoord[0].st + vec2(ac0_4.s, 0.0));   
		blurredColor += texture2D(sampler0, gl_TexCoord[0].st + vec2(0.0, -ac0_4.t)); 
		blurredColor += texture2D(sampler0, gl_TexCoord[0].st + vec2(-ac0_4.s, 0.0)); 
		
		blurredColor += texture2D(sampler0, gl_TexCoord[0].st + vec2(ac0_29.s, -ac0_29.t));
		blurredColor += texture2D(sampler0, gl_TexCoord[0].st + vec2(ac0_29.s, ac0_29.t));
		blurredColor += texture2D(sampler0, gl_TexCoord[0].st + vec2(-ac0_29.s, ac0_29.t));
		blurredColor += texture2D(sampler0, gl_TexCoord[0].st + vec2(-ac0_29.s, -ac0_29.t));
		
		blurredColor += texture2D(sampler0, gl_TexCoord[0].st + vec2(ac0_15.s, ac0_37.t));
		blurredColor += texture2D(sampler0, gl_TexCoord[0].st + vec2(-ac0_37.s, ac0_15.t));
		blurredColor += texture2D(sampler0, gl_TexCoord[0].st + vec2(ac0_37.s, -ac0_15.t));
		blurredColor += texture2D(sampler0, gl_TexCoord[0].st + vec2(-ac0_15.s, -ac0_37.t));
		blurredColor += texture2D(sampler0, gl_TexCoord[0].st + vec2(-ac0_15.s, ac0_37.t));
		blurredColor += texture2D(sampler0, gl_TexCoord[0].st + vec2(ac0_37.s, ac0_15.t)); 
		blurredColor += texture2D(sampler0, gl_TexCoord[0].st + vec2(-ac0_37.s, -ac0_15.t));
		blurredColor += texture2D(sampler0, gl_TexCoord[0].st + vec2(ac0_15.s, -ac0_37.t));

	    blurredColor /= 16.0;

	    
	} else {
		
		blurredColor += getSampleWithBoundsCheck(vec2(0.0, ac0_4.t));
		blurredColor += getSampleWithBoundsCheck(vec2(ac0_4.s, 0.0));   
		blurredColor += getSampleWithBoundsCheck(vec2(0.0, -ac0_4.t)); 
		blurredColor += getSampleWithBoundsCheck(vec2(-ac0_4.s, 0.0)); 
		
		blurredColor += getSampleWithBoundsCheck(vec2(ac0_29.s, -ac0_29.t));
		blurredColor += getSampleWithBoundsCheck(vec2(ac0_29.s, ac0_29.t));
		blurredColor += getSampleWithBoundsCheck(vec2(-ac0_29.s, ac0_29.t));
		blurredColor += getSampleWithBoundsCheck(vec2(-ac0_29.s, -ac0_29.t));
				
		blurredColor += getSampleWithBoundsCheck(vec2(ac0_15.s, ac0_37.t));
		blurredColor += getSampleWithBoundsCheck(vec2(-ac0_37.s, ac0_15.t));
		blurredColor += getSampleWithBoundsCheck(vec2(ac0_37.s, -ac0_15.t));
		blurredColor += getSampleWithBoundsCheck(vec2(-ac0_15.s, -ac0_37.t));
		blurredColor += getSampleWithBoundsCheck(vec2(-ac0_15.s, ac0_37.t));
		blurredColor += getSampleWithBoundsCheck(vec2(ac0_37.s, ac0_15.t)); 
		blurredColor += getSampleWithBoundsCheck(vec2(-ac0_37.s, -ac0_15.t));
		blurredColor += getSampleWithBoundsCheck(vec2(ac0_15.s, -ac0_37.t));
	
	    blurredColor /= samples;
	    
	}

    return blurredColor;
}

vec4 getSampleWithBoundsCheck(vec2 offset) {
	vec2 coord = gl_TexCoord[0].st + offset;
	if (coord.s <= 1.0 && coord.s >= 0.0 && coord.t <= 1.0 && coord.t >= 0.0) {
		samples += 1.0;
		return texture2D(sampler0, coord);
	} else {
		return vec4(0.0);
	}
}

int getTextureID(vec2 coord) {
    int i = int(floor(16.0*coord.s));
    int j = int(floor(16.0*coord.t));
    return i + 16*j;
}

float getCursorDepth(vec2 coord) {
    return 2.0 * near * far / (far + near - (2.0 * texture2D(sampler1, coord).x - 1.0) * (far - near));
}