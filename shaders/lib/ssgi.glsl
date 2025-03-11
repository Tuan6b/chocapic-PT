#ifndef SSGI_INCLUDED
#define SSGI_INCLUDED

// Screen Space Global Illumination implementation
// Enhanced version with better quality controls and temporal stability

// Helper function to create a tangent space from a normal
mat3 createTBN(vec3 normal) {
    vec3 tangent = normalize(cross(abs(normal.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0), normal));
    vec3 bitangent = normalize(cross(normal, tangent));
    return mat3(tangent, bitangent, normal);
}

// Function to generate random rotation for the hemisphere samples
mat2 getRotationMatrix(vec2 coord) {
    float angle = texture2D(noisetex, coord * 10.0 + frameTimeCounter * 0.01).r * 6.28318;
    return mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
}

// Temporal jitter function to reduce noise between frames
vec2 temporalJitter(vec2 coord) {
    vec2 jitter = vec2(0.0);
    jitter.x = fract(52.9829189 * fract(0.06711056 * frameCounter + 0.00583715 * coord.x));
    jitter.y = fract(52.9829189 * fract(0.00583715 * frameCounter + 0.06711056 * coord.y));
    return jitter;
}

// Enhanced Screen Space Global Illumination function
vec3 calculateSSGI(
    vec3 viewPos,         // View-space position
    vec3 normal,          // World-space normal
    vec3 albedo,          // Surface color
    float roughness,      // Surface roughness (0-1)
    vec3 directLighting,  // Direct lighting component
    sampler2D depthTex,   // Depth texture for ray tracing
    sampler2D colorTex,   // Color texture for sampling indirect light
    sampler2D normalTex,  // Normal texture
    vec2 texCoord,        // Current pixel coordinates
    float giStrength      // Strength of the GI effect
) {
    // Early exit if GI is disabled
    #if SSGI == 0
        return vec3(0.0);
    #endif

    // Skip enhanced algorithm if ADVANCED_GI is disabled
    #if ADVANCED_GI == 0
        // Call to the original implementation would go here if needed
        // For now, we'll use a simplified version
        int nrays = RAY_COUNT;
        vec3 indirectLighting = vec3(0.0);
        
        // Simplified hemisphere sampling
        for (int i = 0; i < nrays; i++) {
            float angle = float(i) * 6.28318 / float(nrays);
            vec3 sampleDir = vec3(cos(angle) * 0.7, 0.5, sin(angle) * 0.7);
            sampleDir = normalize(TangentToWorld(normal, sampleDir));
            
            // Simple ambient approximation
            indirectLighting += directLighting * 0.2;
        }
        
        indirectLighting /= float(nrays);
        indirectLighting *= giStrength;
        indirectLighting *= albedo;
        
        return indirectLighting;
    #endif

    // Convert view-space position to world-space
    vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
    
    // Initialize accumulated indirect lighting
    vec3 indirectLighting = vec3(0.0);
    
    // Create TBN matrix for hemisphere sampling
    mat3 tbn = createTBN(normal);
    
    // Get rotation matrix for hemisphere samples
    mat2 rotation = getRotationMatrix(texCoord);
    
    // Get temporal jitter for noise reduction between frames
    vec2 jitter = temporalJitter(texCoord);
    
    // Number of rays to shoot for GI - using the defined RAY_COUNT
    const int numRays = RAY_COUNT;
    
    // Quality multiplier - affects step size and precision
    float qualityMult = GI_QUALITY;
    
    // For each ray
    for (int i = 0; i < numRays; i++) {
        // Use golden ratio for better sample distribution
        float phi = 2.4 * float(i) + jitter.x * 6.28318;
        
        // Use low-discrepancy sequence for better sampling
        float r1 = fract(phi * 0.618033988749895);
        float r2 = fract(float(i) / float(numRays) + jitter.y);
        
        // Create cosine-weighted hemisphere sample
        float cos_theta = sqrt(1.0 - r2);
        float sin_theta = sqrt(r2);
        float cos_phi = cos(phi);
        float sin_phi = sin(phi);
        
        // Sample direction in tangent space
        vec3 sampleDir = vec3(
            sin_theta * cos_phi,
            sin_theta * sin_phi,
            cos_theta
        );
        
        // Transform sample direction to world space
        vec3 rayDir = tbn * sampleDir;
        
        // Convert ray direction to view space for ray marching
        vec3 viewRayDir = mat3(gbufferModelView) * rayDir;
        
        // Ray marching parameters - adjusted by quality settings
        float rayLength = STEP_LENGTH * (0.5 + roughness * 0.5) * qualityMult;
        int maxSteps = int(STEPS * qualityMult);
        float stepSize = rayLength / float(maxSteps);
        
        // Initial position with small offset to avoid self-intersection
        vec3 currentPos = worldPos + normal * 0.05;
        
        // Ray marching to find intersection
        bool hit = false;
        vec3 hitPos = vec3(0.0);
        vec3 hitNormal = vec3(0.0);
        vec3 hitColor = vec3(0.0);
        float hitDistance = 0.0;
        
        for (int step = 0; step < maxSteps; step++) {
            // Move along ray
            currentPos += rayDir * stepSize;
            
            // Convert to screen space
            vec4 projectedPos = gbufferProjection * gbufferModelView * vec4(currentPos, 1.0);
            projectedPos.xyz /= projectedPos.w;
            
            // Check if we're still in screen space
            if (abs(projectedPos.x) > 1.0 || abs(projectedPos.y) > 1.0 || projectedPos.z < 0.0) {
                break;
            }
            
            // Convert to texture coordinates
            vec2 screenCoord = projectedPos.xy * 0.5 + 0.5;
            
            // Sample depth at this position
            float sampledDepth = texture2D(depthTex, screenCoord).r;
            
            // Convert sample depth to view space
            vec3 sampledViewPos = toScreenSpace(vec3(screenCoord, sampledDepth));
            float sampleDist = length(sampledViewPos);
            
            // Compute ray depth at current position
            float rayDepth = -projectedPos.z;
            
            // Enhanced intersection test with thickness consideration
            if (rayDepth > sampleDist && abs(rayDepth - sampleDist) < 0.5 * stepSize) {
                hit = true;
                hitPos = currentPos;
                hitDistance = length(hitPos - worldPos);
                
                // Sample color and normal at intersection
                hitColor = texture2D(colorTex, screenCoord).rgb;
                hitNormal = texture2D(normalTex, screenCoord).rgb * 2.0 - 1.0;
                
                break;
            }
        }
        
        // If we hit something, add its contribution to indirect lighting
        if (hit) {
            // Improved normal-based attenuation (surfaces facing away contribute less)
            float normalFactor = max(0.0, dot(normal, normalize(hitNormal)));
            
            // Enhanced distance attenuation with physically-based falloff
            float distAtten = 1.0 / (1.0 + hitDistance * hitDistance * 0.1);
            
            // Apply color bleeding factor - controls how much color is picked up from surfaces
            // Using the COLOR_BLEEDING parameter
            vec3 indirectColor = min(hitColor, vec3(1.0)) * distAtten * normalFactor * COLOR_BLEEDING;
            
            // Roughness affects indirect bounces - rougher surfaces scatter more diffusely
            indirectColor *= mix(1.0, 0.5, roughness);
            
            indirectLighting += indirectColor;
        }
        else {
            // If ray didn't hit anything, contribute ambient sky light based on ray direction
            vec3 skyColor = vec3(0.0);
            
            // Get sky contribution based on ray direction
            // Higher for upward rays, lower for downward rays
            float skyFactor = max(0.0, rayDir.y * 0.5 + 0.5);
            
            // Use SKY_CONTRIBUTION parameter to control sky light intensity
            skyColor = directLighting * skyFactor * SKY_CONTRIBUTION;
            
            indirectLighting += skyColor;
        }
    }
    
    // Average results from all rays
    indirectLighting /= float(numRays);
    
    // Apply GI strength with energy conservation
    indirectLighting *= giStrength;
    
    // Energy conservation - indirect lighting picks up color from the surface
    // This creates the color bleeding effect but prevents energy gain
    indirectLighting *= albedo;
    
    // Final indirect lighting contribution
    return indirectLighting;
}

#endif // SSGI_INCLUDED 