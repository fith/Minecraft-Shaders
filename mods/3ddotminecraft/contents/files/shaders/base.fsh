/*
** Photoshop & misc math
** Blending modes, RGB/HSL/Contrast/Desaturate, levels control
**
** Romain Dura | Romz
** Blog: http://blog.mouaif.org
** Post: http://blog.mouaif.org/?p=94
*/


/*
** Desaturation
*/

vec4 Desaturate(vec3 color, float Desaturation)
{
	vec3 grayXfer = vec3(0.3, 0.59, 0.11);
	vec3 gray = vec3(dot(grayXfer, color));
	return vec4(mix(color, gray, Desaturation), 1.0);
}


/*
** Hue, saturation, luminance
*/

vec3 RGBToHSL(vec3 color)
{
	vec3 hsl; // init to 0 to avoid warnings ? (and reverse if + remove first part)
	
	float fmin = min(min(color.r, color.g), color.b);    //Min. value of RGB
	float fmax = max(max(color.r, color.g), color.b);    //Max. value of RGB
	float delta = fmax - fmin;             //Delta RGB value

	hsl.z = (fmax + fmin) / 2.0; // Luminance

	if (delta == 0.0)		//This is a gray, no chroma...
	{
		hsl.x = 0.0;	// Hue
		hsl.y = 0.0;	// Saturation
	}
	else                                    //Chromatic data...
	{
		if (hsl.z < 0.5)
			hsl.y = delta / (fmax + fmin); // Saturation
		else
			hsl.y = delta / (2.0 - fmax - fmin); // Saturation
		
		float deltaR = (((fmax - color.r) / 6.0) + (delta / 2.0)) / delta;
		float deltaG = (((fmax - color.g) / 6.0) + (delta / 2.0)) / delta;
		float deltaB = (((fmax - color.b) / 6.0) + (delta / 2.0)) / delta;

		if (color.r == fmax )
			hsl.x = deltaB - deltaG; // Hue
		else if (color.g == fmax)
			hsl.x = (1.0 / 3.0) + deltaR - deltaB; // Hue
		else if (color.b == fmax)
			hsl.x = (2.0 / 3.0) + deltaG - deltaR; // Hue

		if (hsl.x < 0.0)
			hsl.x += 1.0; // Hue
		else if (hsl.x > 1.0)
			hsl.x -= 1.0; // Hue
	}

	return hsl;
}

float HueToRGB(float f1, float f2, float hue)
{
	if (hue < 0.0)
		hue += 1.0;
	else if (hue > 1.0)
		hue -= 1.0;
	float res;
	if ((6.0 * hue) < 1.0)
		res = f1 + (f2 - f1) * 6.0 * hue;
	else if ((2.0 * hue) < 1.0)
		res = f2;
	else if ((3.0 * hue) < 2.0)
		res = f1 + (f2 - f1) * ((2.0 / 3.0) - hue) * 6.0;
	else
		res = f1;
	return res;
}

vec3 HSLToRGB(vec3 hsl)
{
	vec3 rgb;
	
	if (hsl.y == 0.0)
		rgb = vec3(hsl.z); // Luminance
	else
	{
		float f2;
		
		if (hsl.z < 0.5)
			f2 = hsl.z * (1.0 + hsl.y);
		else
			f2 = (hsl.z + hsl.y) - (hsl.y * hsl.z);
			
		float f1 = 2.0 * hsl.z - f2;
		
		rgb.r = HueToRGB(f1, f2, hsl.x + (1.0/3.0));
		rgb.g = HueToRGB(f1, f2, hsl.x);
		rgb.b= HueToRGB(f1, f2, hsl.x - (1.0/3.0));
	}
	
	return rgb;
}


/*
** Contrast, saturation, brightness
** Code of this function is from TGM's shader pack
** http://irrlicht.sourceforge.net/phpBB2/viewtopic.php?t=21057
*/

// For all settings: 1.0 = 100% 0.5=50% 1.5 = 150%
vec3 ContrastSaturationBrightness(vec3 color, float brt, float sat, float con)
{
	// Increase or decrease theese values to adjust r, g and b color channels seperately
	const float AvgLumR = 0.5;
	const float AvgLumG = 0.5;
	const float AvgLumB = 0.5;
	
	const vec3 LumCoeff = vec3(0.2125, 0.7154, 0.0721);
	
	vec3 AvgLumin = vec3(AvgLumR, AvgLumG, AvgLumB);
	vec3 brtColor = color * brt;
	vec3 intensity = vec3(dot(brtColor, LumCoeff));
	vec3 satColor = mix(intensity, brtColor, sat);
	vec3 conColor = mix(AvgLumin, satColor, con);
	return conColor;
}


/*
** Float blending modes
** Adapted from here: http://www.nathanm.com/photoshop-blending-math/
** But I modified the HardMix (wrong condition), Overlay, SoftLight, ColorDodge, ColorBurn, VividLight, PinLight (inverted layers) ones to have correct results
*/

#define BlendLinearDodgef 			BlendAddf
#define BlendLinearBurnf 			BlendSubstractf
#define BlendAddf(base, blend) 		min(base + blend, 1.0)
#define BlendSubstractf(base, blend) 	max(base + blend - 1.0, 0.0)
#define BlendLightenf(base, blend) 		max(blend, base)
#define BlendDarkenf(base, blend) 		min(blend, base)
#define BlendLinearLightf(base, blend) 	(blend < 0.5 ? BlendLinearBurnf(base, (2.0 * blend)) : BlendLinearDodgef(base, (2.0 * (blend - 0.5))))
#define BlendScreenf(base, blend) 		(1.0 - ((1.0 - base) * (1.0 - blend)))
#define BlendOverlayf(base, blend) 	(base < 0.5 ? (2.0 * base * blend) : (1.0 - 2.0 * (1.0 - base) * (1.0 - blend)))
#define BlendSoftLightf(base, blend) 	((blend < 0.5) ? (2.0 * base * blend + base * base * (1.0 - 2.0 * blend)) : (sqrt(base) * (2.0 * blend - 1.0) + 2.0 * base * (1.0 - blend)))
#define BlendColorDodgef(base, blend) 	((blend == 1.0) ? blend : min(base / (1.0 - blend), 1.0))
#define BlendColorBurnf(base, blend) 	((blend == 0.0) ? blend : max((1.0 - ((1.0 - base) / blend)), 0.0))
#define BlendVividLightf(base, blend) 	((blend < 0.5) ? BlendColorBurnf(base, (2.0 * blend)) : BlendColorDodgef(base, (2.0 * (blend - 0.5))))
#define BlendPinLightf(base, blend) 	((blend < 0.5) ? BlendDarkenf(base, (2.0 * blend)) : BlendLightenf(base, (2.0 *(blend - 0.5))))
#define BlendHardMixf(base, blend) 	((BlendVividLightf(base, blend) < 0.5) ? 0.0 : 1.0)
#define BlendReflectf(base, blend) 		((blend == 1.0) ? blend : min(base * base / (1.0 - blend), 1.0))


/*
** Vector3 blending modes
*/

// Component wise blending
#define Blend(base, blend, funcf) 		vec3(funcf(base.r, blend.r), funcf(base.g, blend.g), funcf(base.b, blend.b))

#define BlendNormal(base, blend) 		(blend)
#define BlendLighten				BlendLightenf
#define BlendDarken				BlendDarkenf
#define BlendMultiply(base, blend) 		(base * blend)
#define BlendAverage(base, blend) 		((base + blend) / 2.0)
#define BlendAdd(base, blend) 		min(base + blend, vec3(1.0))
#define BlendSubstract(base, blend) 	max(base + blend - vec3(1.0), vec3(0.0))
#define BlendDifference(base, blend) 	abs(base - blend)
#define BlendNegation(base, blend) 	(vec3(1.0) - abs(vec3(1.0) - base - blend))
#define BlendExclusion(base, blend) 	(base + blend - 2.0 * base * blend)
#define BlendScreen(base, blend) 		Blend(base, blend, BlendScreenf)
#define BlendOverlay(base, blend) 		Blend(base, blend, BlendOverlayf)
#define BlendSoftLight(base, blend) 	Blend(base, blend, BlendSoftLightf)
#define BlendHardLight(base, blend) 	BlendOverlay(blend, base)
#define BlendColorDodge(base, blend) 	Blend(base, blend, BlendColorDodgef)
#define BlendColorBurn(base, blend) 	Blend(base, blend, BlendColorBurnf)
#define BlendLinearDodge			BlendAdd
#define BlendLinearBurn			BlendSubstract
// Linear Light is another contrast-increasing mode
// If the blend color is darker than midgray, Linear Light darkens the image by decreasing the brightness. If the blend color is lighter than midgray, the result is a brighter image due to increased brightness.
#define BlendLinearLight(base, blend) 	Blend(base, blend, BlendLinearLightf)
#define BlendVividLight(base, blend) 	Blend(base, blend, BlendVividLightf)
#define BlendPinLight(base, blend) 		Blend(base, blend, BlendPinLightf)
#define BlendHardMix(base, blend) 		Blend(base, blend, BlendHardMixf)
#define BlendReflect(base, blend) 		Blend(base, blend, BlendReflectf)
#define BlendGlow(base, blend) 		BlendReflect(blend, base)
#define BlendPhoenix(base, blend) 		(min(base, blend) - max(base, blend) + vec3(1.0))
#define BlendOpacity(base, blend, F, O) 	(F(base, blend) * O + blend * (1.0 - O))


// Hue Blend mode creates the result color by combining the luminance and saturation of the base color with the hue of the blend color.
vec3 BlendHue(vec3 base, vec3 blend)
{
	vec3 baseHSL = RGBToHSL(base);
	return HSLToRGB(vec3(RGBToHSL(blend).r, baseHSL.g, baseHSL.b));
}

// Saturation Blend mode creates the result color by combining the luminance and hue of the base color with the saturation of the blend color.
vec3 BlendSaturation(vec3 base, vec3 blend)
{
	vec3 baseHSL = RGBToHSL(base);
	return HSLToRGB(vec3(baseHSL.r, RGBToHSL(blend).g, baseHSL.b));
}

// Color Mode keeps the brightness of the base color and applies both the hue and saturation of the blend color.
vec3 BlendColor(vec3 base, vec3 blend)
{
	vec3 blendHSL = RGBToHSL(blend);
	return HSLToRGB(vec3(blendHSL.r, blendHSL.g, RGBToHSL(base).b));
}

// Luminosity Blend mode creates the result color by combining the hue and saturation of the base color with the luminance of the blend color.
vec3 BlendLuminosity(vec3 base, vec3 blend)
{
	vec3 baseHSL = RGBToHSL(base);
	return HSLToRGB(vec3(baseHSL.r, baseHSL.g, RGBToHSL(blend).b));
}


/*
** Gamma correction
** Details: http://blog.mouaif.org/2009/01/22/photoshop-gamma-correction-shader/
*/

#define GammaCorrection(color, gamma)								pow(color, 1.0 / gamma)

/*
** Levels control (input (+gamma), output)
** Details: http://blog.mouaif.org/2009/01/28/levels-control-shader/
*/

#define LevelsControlInputRange(color, minInput, maxInput)				min(max(color - vec3(minInput), vec3(0.0)) / (vec3(maxInput) - vec3(minInput)), vec3(1.0))
#define LevelsControlInput(color, minInput, gamma, maxInput)				GammaCorrection(LevelsControlInputRange(color, minInput, maxInput), gamma)
#define LevelsControlOutputRange(color, minOutput, maxOutput) 			mix(vec3(minOutput), vec3(maxOutput), color)
#define LevelsControl(color, minInput, gamma, maxInput, minOutput, maxOutput) 	LevelsControlOutputRange(LevelsControlInput(color, minInput, gamma, maxInput), minOutput, maxOutput)




/////////////////////////////////
#define SQUIRM
#define SHINY_WATER
const float PI = 3.1415926535897932384626433832795;
const float PI2 = 6.283185307179586476925286766559;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

uniform sampler2D sampler0;
uniform sampler2D sampler1;

uniform float near;
uniform float far;

uniform int fogMode;

uniform int worldTime;
uniform int renderType;

uniform float aspectRatio;
uniform float displayHeight;
uniform float displayWidth;

#define SQUIRM_DISTANCE 10.0
#define MAX_DISTANCE 100.0
varying vec3 normal;

varying float distance;
varying float contrast;

varying float texID;
int getTextureID(vec2 coord);

//vec3 ContrastSaturationBrightness(vec3 color, float brt, float sat, float con);



void main() {
    //texID = float(getTextureID(gl_TexCoord[0].st));
	
//distance = sqrt(position.x * position.x + position.y * position.y + position.z * position.z);
//	if (distance <= MAX_DISTANCE && viewVector.z < 0.0) {

vec3 coord = vec3(gl_TexCoord[0].st, 1.0) ;
int tex = getTextureID(gl_TexCoord[0].st);
#ifdef SQUIRM
//    		if ((texID >= 204.0 && tex <= 207) || (tex >= 221 && tex <= 223) && distance < SQUIRM_DISTANCE) {
    		if ((tex >= 204 && tex <= 207) || (tex >= 221 && tex <= 223)) {
/*
			float t = mod(float(worldTime), 2000.0)/2000.0;
			vec3 offset, base;
			base = mod(coord, 1.0);
			coord = coord - base;
	//		coord = vec3(modf(16.0*coord, base));

			offset = vec3(cos(PI2*coord.s)*cos(PI2*(coord.t + 2.0*t))*cos(PI2*t)/40.0,
                     -cos(PI2*(coord.s + t))*sin(2.0*PI2*coord.t)/40.0,0);

			coord = mod(coord + offset, vec3(1.0)) + base;
		
			//coord = coord;
		//	gl_FragColor = texture2D(sampler0, coord.st/16.0) * vertColor;
	*/	


		vec4 baseColor = texture2D(sampler0, coord.st) * gl_Color;
		#ifdef SHINY_WATER
			if ((tex >= 204 && tex <= 207) || (tex >= 221 && tex <= 223)) {
				float averageRGB = ((baseColor.r+baseColor.g+baseColor.b)/3.0);
				float averageRG = ((baseColor.r+baseColor.g)*0.5);
				float brightness = ((0.299*baseColor.r) + (0.587*baseColor.g) + (0.114*baseColor.b));

//baseColor.a = 1.0;
//				float acontrast = 2.0;
				//baseColor = (baseColor - 0.5) * acontrast + 0.5;
//baseColor *= 1.5;				
//baseColor.a = baseColor.b;

/*
baseColor.a = baseColor.a*(1.0-brightness);
baseColor = vec4( ContrastSaturationBrightness( vec3(baseColor), brightness*5.0, brightness*1.0, brightness*5.0), baseColor.a);
*/
 brightness = ((0.299*baseColor.r) + (0.587*baseColor.g) + (0.114*baseColor.b));
vec4 col = vec4(ContrastSaturationBrightness( vec3(baseColor), brightness*5.0, brightness, brightness*5.0), baseColor.a);


// Luminosity
vec3 pass1 = mix(vec3(baseColor), BlendLuminosity(vec3(baseColor), vec3(col) + vec3(0.08)), 0.5);

// Linear light at 40%
vec3 pass2 = mix(pass1, BlendScreen(pass1, vec3(col)), 0.4);
// Final
baseColor = vec4(pass2, 1.0);

baseColor.a = baseColor.a*(1.0-brightness)-0.2;



	//	 float brightness2 = ((0.299*baseColor.r) + (0.587*baseColor.g) + (0.114*baseColor.b));
//baseColor.a = 1.0-brightness2;
// averageRG = ((baseColor.r+baseColor.g)*0.5);
//				if(baseColor.b > 1.0){ baseColor.b = 1.0;}
//				if(baseColor.b < 0.0){ baseColor.b = 0.0;}
//baseColor.a = 1.0-brightness;//* (brightness)) ;//+ (baseColor.b * brightness);

//baseColor.a = ((baseColor.b) * (((0.299*baseColor.r) + (0.587*baseColor.g) + (0.114*baseColor.b))));
//baseColor.a = (((0.299*baseColor.r) + (0.587*baseColor.g) + (0.114*baseColor.b)));
//baseColor.a +=  (1.0-((baseColor.r+baseColor.g)*0.5));

//((baseColor.r+baseColor.g)*0.5)*
			//	baseColor.a = (1.0-baseColor.b); //* ((0.299*baseColor.r) + (0.587*baseColor.g) + (0.114*baseColor.b));
				
			//	if(baseColor.b > 1.0){ baseColor.b = 1.0;}
//baseColor.a += (1.0-(baseColor.b));



				//baseColor *= 1.0+((baseColor.r+baseColor.g+baseColor.b)/3.0);
			//	float averageRGB = ((baseColor.r+baseColor.g+baseColor.b)*0.33);
		//		float averageRG = ((baseColor.r+baseColor.g)*0.5);
	//			float brightness = ((0.299*baseColor.r) + (0.587*baseColor.g) + (0.114*baseColor.b));
				//baseColor.a = 1.0-brightness;
//				baseColor = (baseColor - 0.5) * ((contrast) + 0.5);
				//baseColor *= 1.5;
			//	float acontrast = 4.0;
				//baseColor = (baseColor - 0.5) * acontrast + 0.5;
				//baseColor.a = ((0.299*baseColor.r) + (0.587*baseColor.g) + (0.114*baseColor.b));
				//baseColor.a -= 1.0-((baseColor.r+baseColor.g+baseColor.b)/3.0);
			//	baseColor.a = 1.0-baseColor.b;
//baseColor.r = (baseColor.r - 0.5) * acontrast + 0.5;
//baseColor.b = (baseColor.b - 0.5) * acontrast + 0.5;
//baseColor.g = (baseColor.g - 0.5) * acontrast + 0.5;
//			//	baseColor.b = baseColor.b * ((baseColor.r+baseColor.g)*0.5); 
			//	clamp(baseColor.a, 0.1, 0.9);

			}
		#endif
		gl_FragColor = baseColor * gl_Color;        
    } else {
#endif

    gl_FragColor = texture2D(sampler0, gl_TexCoord[0].st) * gl_Color;        

#ifdef SQUIRM
	}
#endif



    if (abs(gl_FragColor.a) > 0.005) {
		if (fogMode == GL_EXP) {
			gl_FragColor = mix(gl_FragColor, gl_Fog.color, 1.0 - clamp(exp(-gl_Fog.density * gl_FogFragCoord), 0.0, 1.0));
		} else if (fogMode == GL_LINEAR) {
			gl_FragColor = mix(gl_FragColor, gl_Fog.color, clamp((gl_FogFragCoord - gl_Fog.start) * gl_Fog.scale, 0.0, 1.0));
		}
	}

}

int getTextureID(vec2 coord) {
    int i = int(floor(16.0*coord.s));
    int j = int(floor(16.0*coord.t));
    return i + 16*j;
}

// For all settings: 1.0 = 100% 0.5=50% 1.5 = 150%
/*
vec3 ContrastSaturationBrightness(vec3 color, float brt, float sat, float con)
{
	// Increase or decrease theese values to adjust r, g and b color channels seperately
	const float AvgLumR = 0.5;
	const float AvgLumG = 0.5;
	const float AvgLumB = 0.5;
	
	const vec3 LumCoeff = vec3(0.2125, 0.7154, 0.0721);
	
	vec3 AvgLumin = vec3(AvgLumR, AvgLumG, AvgLumB);
	vec3 brtColor = color * brt;
	vec3 intensity = vec3(dot(brtColor, LumCoeff));
	vec3 satColor = mix(intensity, brtColor, sat);
	vec3 conColor = mix(AvgLumin, satColor, con);
	return conColor;
}
*/
