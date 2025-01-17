/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float computeSSAO(vec3 viewPos, vec3 normal) {
	float occlusion = 1.0;
	vec3 sampleOrigin = viewPos + normal * EPS;
    mat3 TBN = getTBN(normal);

	for(int i = 0; i < SSAO_SAMPLES; i++) {
		vec3 sampleDir = TBN * randomHemisphereDirection(uniformNoise(i, blueNoise));

		vec3 samplePos = viewPos + sampleDir * SSAO_RADIUS;
		float sampleDepth = getViewPos(viewToScreen(samplePos).xy).z;

		// https://learnopengl.com/Advanced-Lighting/SSAO
		float rangeCheck = quintic(0.0, 1.0, SSAO_RADIUS / abs(viewPos.z - sampleDepth));
        occlusion += (sampleDepth >= samplePos.z + EPS ? 1.0 : 0.0) * rangeCheck;
	}
	occlusion = 1.0 - (occlusion / SSAO_SAMPLES);
	return saturate(pow(occlusion, SSAO_STRENGTH));
}

float computeRTAO(vec3 viewPos, vec3 normal) {
	float occlusion = 0.0;
	vec3 samplePos = viewPos + normal * EPS;

	mat3 TBN = getTBN(normal);
	vec3 hitPos;

	for(int i = 0; i < RTAO_SAMPLES; i++) {
		vec2 noise = TAA == 1 ? uniformAnimatedNoise(hash22(gl_FragCoord.xy + frameTimeCounter)) : uniformNoise(i, blueNoise);
		vec3 sampleDir = TBN * randomHemisphereDirection(noise);
		if(!raytrace(samplePos, sampleDir, RTAO_STEPS, noise.x, hitPos)) continue;

		float delta = (samplePos.z + EPS) - screenToView(hitPos).z;
    	float dist = pow(max(0.0, exp(-(delta*delta) * 5.0)), 5.0);
		occlusion += dist;
	}
	occlusion = 1.0 - (occlusion / RTAO_SAMPLES);
	return saturate(pow(occlusion, 8.0));
}
