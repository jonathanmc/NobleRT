/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 400 compatibility

varying vec2 texCoords;

#include "/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/fragment/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/color.glsl"
#include "/lib/util/worldTime.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/material.glsl"
#include "/lib/lighting/brdf.glsl"
#include "/lib/lighting/raytracer.glsl"
#include "/lib/lighting/ssr.glsl"

void main() {
    vec4 Result = texture2D(colortex0, texCoords);

    if(isSky()) {
        /*DRAWBUFFERS:05*/
        gl_FragData[0] = Result;
        #if BLOOM == 1
            gl_FragData[1] = luma(Result.rgb) > BLOOM_LUMA_THRESHOLD ? Result : vec4(0.0);
        #endif
        return;
    }

    #if SSR == 1
        vec3 viewPos = getViewPos();
        vec3 normal = normalize(decodeNormal(texture2D(colortex1, texCoords).xy));

        float NdotV = saturate(dot(normal, normalize(-viewPos)));
        float F0 = texture2D(colortex2, texCoords).g;

        vec3 specularColor = mix(vec3(F0), texture2D(colortex4, texCoords).rgb, float((F0 * 255.0) > 229.5));
        float roughness = hardCodedRoughness != 0.0 ? hardCodedRoughness : texture2D(colortex2, texCoords).r;

        vec3 reflections;
        #if SSR_TYPE == 1
            reflections = texture2D(colortex5, texCoords * ROUGH_REFLECT_RES).rgb;
        #else
            reflections = simpleReflections(viewPos, normal, NdotV, specularColor);
        #endif

        vec3 DFG = envBRDFApprox(specularColor, roughness, NdotV);
        Result.rgb += mix(Result.rgb, reflections, DFG);
    #endif

    vec3 brightSpots;
    #if BLOOM == 1
        brightSpots = luma(Result.rgb) > BLOOM_LUMA_THRESHOLD ? Result.rgb : vec3(0.0);
    #endif

    /*DRAWBUFFERS:05*/
    gl_FragData[0] = Result;
    gl_FragData[1] = vec4(brightSpots, 1.0);
}