//#define CURVATURE
#define WAVING_WHEAT
#define WAVING_PLANTS
#define WAVING_LEAVES
#define WAVING_WATER
const float Wave_pitch = 16.0; //Change this value to change wave effect
const float Water_level = -0.1;

#ifdef CURVATURE
const float FLAT_RADIUS          = 84.0;
const float WORLD_RADIUS         = 212.0;
const float WORLD_RADIUS_SQUARED = WORLD_RADIUS*WORLD_RADIUS;
#endif

const float PI = 3.1415926535897932384626433832795;
const float PI2 = 6.283185307179586476925286766559;

uniform float sunVector;
uniform float moonVector;
uniform int worldTime;
uniform int renderType;

varying float distance;

varying float texID;
varying float contrast;

int getTextureID(vec2 coord);

void main() {
    vec4 position = gl_Vertex;
	int tex = getTextureID(gl_MultiTexCoord0.st);
#ifdef WAVING_WHEAT
    if (87 < tex && tex < 96 && renderType != 0) {
        float t = mod(float(worldTime), 200.0)/200.0;
        vec2 pos = position.xz/16.0;
        if (floor((16.0*gl_MultiTexCoord0.t)+0.5) <= floor(16.0*gl_MultiTexCoord0.t)) {
            position.x += (sin(PI2*(2.0*pos.x + pos.y - 3.0*t)) + 0.6)/20.0;
        }
    }
//    position = gl_ModelViewMatrix * position;
#endif
#ifdef CURVATURE
    if (gl_Color.a != 0.8) {
        // Not a cloud.

        float dist = (length(position) - FLAT_RADIUS)/WORLD_RADIUS;

        if (dist > 0.0) {
            dist *= dist;
            position.y -= WORLD_RADIUS - sqrt(max(1.0 - dist, 0.0)) * WORLD_RADIUS;
        }

    }
#endif
#ifdef WAVING_PLANTS
if ((tex == 12 || tex == 13  || tex == 15)&& renderType == 1)  {
        float t = mod(float(worldTime), 500.0)/500.0;
        vec2 pos = position.xz/16.0;
        if ( floor((16.0*gl_MultiTexCoord0.t)+0.5) <= floor(16.0*gl_MultiTexCoord0.t) ) {
            position.x -= (sin(PI2*(2.0*pos.x + pos.y - 3.0*t)) + 0.6)/8.0;
        }
    }
#endif
#ifdef WAVING_LEAVES
if ((tex == 52 || tex == 53 || tex == 132 || tex == 133)&& renderType == 1)  {
        float t = mod(float(worldTime), 800.0)/800.0;
        vec2 pos = position.xz/16.0;
        if (floor(8.0*gl_MultiTexCoord0.t+0.5) <= floor(16.32*gl_MultiTexCoord0.t)) {
            position.x -= (sin(PI2*(2.0*pos.x + pos.y - 3.0*t)) + 0.6)/24.0;
            position.y -= (sin(PI2*(3.0*pos.x + pos.y - 4.0*t)) + 1.2)/32.0;
            position.z -= (sin(PI2*(1.0*pos.x + pos.y - 1.5*t)) + 0.3)/8.0;
        }
    }
#endif
#ifdef WAVING_WATER
	if ( ((tex >= 204 && tex <= 207) || (tex >= 221 && tex <= 223)) && renderType == 0) {
        float t = mod(float(worldTime), 1000.0)/400.0;
        vec2 pos = position.xz/16.0;
        position.y += (Water_level + cos((PI2)*(2.0 * (pos.x + pos.y) + PI * t)))/(Wave_pitch);
		
    }
	if ( ((tex >= 204 && tex <= 207) || (tex >= 221 && tex <= 223)) && renderType == 0) {
        float t = mod(float(worldTime), 1000.0)/200.0;
        vec2 pos = position.xz/16.0;
        position.y += ((Water_level*0.5) + sin((PI2)*(5.0 * (pos.x + pos.y) + PI * t)))/(Wave_pitch*0.7);
		
    }
	contrast = position.y;
#endif

#if defined(CURVATURE) || defined(WAVING_WHEAT) || defined(WAVING_LEAVES) || defined(WAVING_PLANTS) || defined(WAVING_WATER)
    position = gl_ModelViewMatrix * position;
    gl_Position = gl_ProjectionMatrix * position;

#else
    gl_Position = ftransform();
#endif
distance = sqrt(position.x * position.x + position.y * position.y + position.z * position.z);
/*
    if (renderType != 0) {
        texID = float(getTextureID(gl_MultiTexCoord0.st));
    }
    else {
        texID = -1.0;
    }
*/
	texID = float(getTextureID(gl_MultiTexCoord0.st));
    gl_FrontColor = gl_BackColor = gl_Color;
    gl_TexCoord[0] = gl_MultiTexCoord0;;
    gl_FogFragCoord = gl_Position.z;

	
	
}

int getTextureID(vec2 coord) {
    int i = int(floor(16.0*coord.s));
    int j = int(floor(16.0*coord.t));
    return i + 16*j;
}