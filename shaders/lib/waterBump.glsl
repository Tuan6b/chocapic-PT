// Function to calculate water heightmap for bump mapping effects
float getWaterHeightmap(vec2 posxz, float waveM, float waveZ, float iswater) {
  vec2 pos = posxz*3.0; // Scale the position for more detailed waves
  float moving = clamp(iswater*2.-1.0,0.0,1.0); // Determine if the water should be moving (0 for static, 1 for moving)
	vec2 movement = vec2(-0.0133*frameTimeCounter*moving); // Create time-based movement vector for waves
	float caustic = 0.0; // Initialize caustic light effect value
	float weightSum = 0.0; // Initialize weight sum for normalization
	float radiance =  2.39996; // Rotation angle in radians (approx 137.5 degrees)
	
	// Create a 2D rotation matrix for transforming wave coordinates
	mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));
	
	// Loop to create waves at different frequencies and amplitudes (fractal noise)
	for (int i = 0; i < 4; i++){
		// Sample noise texture and convert from [0,1] to [-1,1] range for displacement
		vec2 displ = texture2D(noisetex, pos/32.0/1.74/1.74 + movement).bb*2.0-1.0;
		pos = rotationMatrix * pos; // Rotate the position for varied wave directions
		
		// Calculate wave height using sin function with exponentially increasing frequency
		// and decreasing amplitude for each iteration (fractal-like pattern)
		caustic += sin(dot((pos+vec2(moving*frameTimeCounter))/1.74/1.74 * exp2(0.8*i) + displ*2.0,vec2(0.5)))*exp2(-0.8*i);
		weightSum += exp2(-i); // Increase weight sum for later normalization
	}
	
	// Return the normalized height value, scaled appropriately
	// Extra scaling when underwater (isEyeInWater = 1) for stronger effect
	return caustic * weightSum / 300. * 2.5  *(1.0+isEyeInWater*2.);
}

// Function to calculate the normal vector based on the water heightmap
// Uses finite difference method to approximate the surface gradient
vec3 getWaveHeight(vec2 posxz, float iswater){

	vec2 coord = posxz; // Input position coordinates

	// Spatial offset for sampling neighboring points to calculate derivatives
	float deltaPos = 0.25;

	// Adjust wave parameters based on water type
	float waveZ = mix(20.0,0.25,iswater); // Controls wave frequency
	float waveM = mix(0.0,4.0,iswater); // Controls wave amplitude

	// Sample heightmap at the center point and two offset points
	float h0 = getWaterHeightmap(coord, waveM, waveZ, iswater); // Center
	float h1 = getWaterHeightmap(coord + vec2(deltaPos,0.0), waveM, waveZ, iswater); // Right
	float h3 = getWaterHeightmap(coord + vec2(0.0,deltaPos), waveM, waveZ, iswater); // Up

	// Calculate approximate derivatives (slope) in X and Y directions
	float xDelta = ((h1-h0))/deltaPos*2.;
	float yDelta = ((h3-h0))/deltaPos*2.;

	// Create a normalized normal vector from the gradient
	// The Z component is adjusted to maintain proper normalization and surface appearance
	vec3 wave = normalize(vec3(xDelta,yDelta,1.0-pow(abs(xDelta+yDelta),2.0)));

	return wave; // Return the normal vector for the water surface
}
