#version 120 // GLSL version declaration
#extension GL_EXT_gpu_shader4 : enable // Enables advanced GPU shader features

#define WHITE_WORLD 0 //[0 1] Makes the world white to check ambient lighting and shading
#define DISABLE_VANILLA_LIGHTING 0 //[0 1] Disables vanilla lighting system, uses only shader lighting

// Variables passed from the vertex shader
varying vec4 lmtexcoord; // Lightmap coordinates and texture coordinates
varying vec4 color; // Vertex color
varying vec4 normalMat; // Normal data in material format
varying vec3 binormal; // Binormal vector for normal mapping
varying vec3 tangent; // Tangent vector for normal mapping
varying vec3 viewVector; // Vector from vertex to camera
varying float dist; // Distance from camera to vertex

#include "/lib/res_params.glsl" // Resolution parameters

// Screen Space Reflection settings
#define SCREENSPACE_REFLECTIONS	//can be really expensive at high resolutions/render quality, especially on ice
#define SSR_STEPS 50 //[10 15 20 25 30 35 40 45 50 100 200 400] // Number of steps for raymarching, higher gives more accurate reflections but costs performance
#define SUN_MICROFACET_SPECULAR // If enabled will use realistic rough microfacet model, else will just reflect the sun. No performance impact.
#define USE_QUARTER_RES_DEPTH // Uses a quarter resolution depth buffer to raymarch screen space reflections, improves performance but may introduce artifacts

#define saturate(x) clamp(x,0.0,1.0) // Helper macro to clamp values between 0 and 1

// Texture samplers
uniform sampler2D texture; // Main texture
uniform sampler2D noisetex; // Noise texture for randomization
uniform sampler2DShadow shadow; // Shadow map
uniform sampler2D gaux2; // Auxiliary texture 2
uniform sampler2D gaux1; // Auxiliary texture 1
uniform sampler2D depthtex1; // Depth texture

// Uniform variables provided by the game/engine
uniform vec4 lightCol; // Light color
uniform vec3 sunVec; // Direction to sun
uniform float frameTimeCounter; // Time counter for animations
uniform float lightSign; // Sign of the light (positive for sun, negative for moon)
uniform float near; // Near clipping plane distance
uniform float far; // Far clipping plane distance
uniform float moonIntensity; // Intensity of moonlight
uniform float sunIntensity; // Intensity of sunlight
uniform vec3 sunColor; // Sun color
uniform vec3 nsunColor; // Night sun (moon) color
uniform vec3 upVec; // Up vector
uniform float sunElevation; // Sun height in the sky
uniform float fogAmount; // Fog density
uniform vec2 texelSize; // Size of one pixel
uniform float rainStrength; // How heavily it's raining (0.0-1.0)
uniform float skyIntensityNight; // Sky brightness at night
uniform float skyIntensity; // Sky brightness during day
uniform mat4 gbufferPreviousModelView; // Previous frame model view matrix
uniform vec3 previousCameraPosition; // Camera position in previous frame
uniform int framemod8; // Frame number modulo 8
uniform int frameCounter; // Global frame counter
uniform int isEyeInWater; // 1 if player's camera is underwater, 0 otherwise

// Include utility libraries
#include "lib/Shadow_Params.glsl" // Shadow calculation parameters
#include "lib/color_transforms.glsl" // Color space conversion functions
#include "lib/projections.glsl" // Projection transformation functions
#include "lib/sky_gradient.glsl" // Sky color gradient generation
#include "lib/waterBump.glsl" // Water bump/normal mapping
#include "lib/clouds.glsl" // Cloud generation
#include "lib/stars.glsl" // Star rendering

// Array of 8 offset positions for sampling, used for dithering and anti-aliasing
const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
                            vec2(-1.,3.)/8.,
                            vec2(5.0,1.)/8.,
                            vec2(-3,-5.)/8.,
                            vec2(-5.,5.)/8.,
                            vec2(-7.,-1.)/8.,
                            vec2(3,7.)/8.,
                            vec2(7.,-7.)/8.);

// Generates interleaved gradient noise for temporal effects
float interleaved_gradientNoise(float temporal){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y)+temporal);
	return noise; // Returns a value between 0 and 1
}

// Generates blue noise for high-quality randomization
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}

// Converts linear depth to non-linear depth
float invLinZ (float lindepth){
	return -((2.0*near/lindepth)-far-near)/(far-near);
}

// Converts distance to linear depth
float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

// Normalizes a vec4 by dividing by w component (perspective division)
vec3 nvec3(vec4 pos){
    return pos.xyz/pos.w;
}

// Creates a vec4 with w=1.0 from a vec3
vec4 nvec4(vec3 pos){
    return vec4(pos.xyz, 1.0);
}

// Screen Space Reflection ray tracing function
vec3 rayTrace(vec3 dir, vec3 position, float dither, float fresnel){

    // Adjust quality based on fresnel (more steps for highly reflective angles)
    float quality = mix(15, SSR_STEPS, fresnel);
    
    // Convert position to clip space
    vec3 clipPosition = toClipSpace3(position);
    
    // Calculate maximum ray length, ensuring we don't go behind the near plane
	float rayLength = ((position.z + dir.z * far*sqrt(3.)) > -near) ?
       (-near - position.z) / dir.z : far*sqrt(3.);
       
    // Direction in clip space   
    vec3 direction = normalize(toClipSpace3(position+dir*rayLength)-clipPosition);
    direction.xy = normalize(direction.xy);

    // Calculate at which length the ray would exit the screen
    vec3 maxLengths = (step(0., direction) - clipPosition) / direction;
    float mult = min(min(maxLengths.x, maxLengths.y), maxLengths.z);

    // Calculate step size for raymarching
    vec3 stepv = direction * mult / quality * vec3(RENDER_SCALE, 1.0);

    // ... existing code ...
