#version 120
#extension GL_EXT_gpu_shader4 : enable

#define WHITE_WORLD 0 //[0 1] Makes the world white to check ambient lighting and shading
#define DISABLE_VANILLA_LIGHTING 0 //[0 1] Disables vanilla lighting system, uses only shader lighting

varying vec4 lmtexcoord;
varying vec4 color;

uniform sampler2D texture;
uniform sampler2D gaux1;
uniform vec4 lightCol;
uniform vec3 sunVec;

uniform vec2 texelSize;
uniform float skyIntensityNight;
uniform float skyIntensity;
uniform float rainStrength;

uniform mat4 gbufferProjectionInverse;

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}


vec3 toScreenSpaceVector(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return normalize(fragposition.xyz);
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

// Add this function or modify the existing one
//encode normal in two channels (xy),torch(z) and sky lightmap (w)
vec4 encode (vec3 n)
{
    #if DISABLE_VANILLA_LIGHTING == 1
        // Replace vanilla lighting with full brightness when disabled
        return vec4(n.xy*inversesqrt(n.z*8.0+8.0) + 0.5, vec2(1.0, 1.0));
    #else
        return vec4(n.xy*inversesqrt(n.z*8.0+8.0) + 0.5, vec2(lmtexcoord.z, lmtexcoord.w));
    #endif
}

void main() {
/* DRAWBUFFERS:2 */
	gl_FragData[0] = texture2D(texture, lmtexcoord.xy)*color;
		gl_FragData[0].a = clamp(gl_FragData[0].a -0.1,0.0,1.0)*0.5;
		vec3 albedo = toLinear(gl_FragData[0].rgb*color.rgb);

		#if DISABLE_VANILLA_LIGHTING == 1
			// Use a constant ambient light instead of vanilla lightmap
			vec3 ambient = vec3(0.5);
		#else
			vec3 ambient = texture2D(gaux1,(lmtexcoord.zw*15.+0.5)*texelSize).rgb;
		#endif

		gl_FragData[0].rgb = dot(albedo,vec3(1.0))*ambient*10./3.0/150.*0.1;



}
