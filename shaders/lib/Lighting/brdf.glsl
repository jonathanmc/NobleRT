/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

float Blinn_Phong(float NdotH, float F0) {
    return pow(NdotH, F0);
}

float Trowbridge_Reitz_GGX(float NdotH, float alpha) {
    // GGXTR(N,H,α) = α² / π*((N*H)²*(α² + 1)-1)²
    float denom = ((NdotH * NdotH) * (alpha - 1.0) + 1.0);
    return alpha / (PI * denom * denom);
}

float Geometry_Schlick_Beckmann(float cosTheta, float roughness) {
    // SchlickGGX(N,V,k) = N*V/(N*V)*(1 - k) + k
    float denom = cosTheta * (1.0 - roughness) + roughness;
    return cosTheta / denom;
}

float Geometry_Smith(float NdotV, float NdotL, float roughness) {
    float r = roughness + 1.0;
    roughness = (r * r) / 8.0;

    float ggxV = Geometry_Schlick_Beckmann(NdotV, roughness);
    float ggxL = Geometry_Schlick_Beckmann(NdotL, roughness);
    return (ggxV * ggxL) / max(4.0 * NdotL * NdotV, EPS);
}

float Geometry_Schlick_GGX(float NdotV, float alpha) {
    float a2 = alpha * alpha;
    return (2.0 * NdotV) / (NdotV + sqrt(a2 + (1.0 - a2) * (NdotV + NdotV)));
}

float Geometry_Cook_Torrance(float NdotH, float NdotV, float VdotH, float NdotL) {
    float NdotH2 = 2.0 * NdotH;
    float g1 = (NdotH2 * NdotV) / VdotH;
    float g2 = (NdotH2 * NdotL) / VdotH;
    return min(1.0, min(g1, g2));
}

vec3 Fresnel_Schlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 Spherical_Gaussian_Fresnel(float HdotL, vec3 F0){
    float fresnel = exp2(((-5.55473 * HdotL) - 6.98316) * HdotL);
    return fresnel * (1.0 - F0) + F0;
}

/*
    Thanks to LVutner for sharing resources 
    and helping me learn more about Physically 
    Based Rendering.

    https://github.com/LVutner
    https://gist.github.com/LVutner/c07a3cc4fec338e8fe3fa5e598787e47
*/

vec3 Cook_Torrance(vec3 N, vec3 V, vec3 L, material data, vec3 lightmap, vec3 shadowmap, vec3 GlobalIllumination) {
    bool isMetal = (data.F0 * 255.0) > 229.5;
    float alpha = data.roughness * data.roughness;

    vec3 specularColor = isMetal ? data.albedo : vec3(data.F0);
    vec3 dayTimeColor = getDayTimeColor();

    vec3 H = normalize(V + L);
    float NdotL = max(dot(N, L), EPS);
    float NdotV = max(dot(N, V), EPS);
    float NdotH = max(dot(N, H), EPS);
    float VdotH = max(dot(V, H), EPS);
    float HdotL = max(dot(H, L), EPS);

    vec3 SpecularLighting;
    #if SPECULAR == 1

        float D = Trowbridge_Reitz_GGX(NdotH, alpha);
        vec3 F = Spherical_Gaussian_Fresnel(HdotL, specularColor);
        float G = Geometry_Smith(NdotV, NdotL, data.roughness);
        // float G = Geometry_Schlick_GGX(NdotV, alpha);
        // float G = Geometry_Smith(NdotV, NdotL, data.roughness);
        // float G = Geometry_Cook_Torrance(NdotH, NdotV, VdotH, NdotL);
        
        SpecularLighting = (D * F * G) * shadowmap * dayTimeColor;
    #endif

    vec3 DiffuseLighting  = GlobalIllumination * data.albedo;
    vec3 E0 = lightmap + NdotL * shadowmap + AMBIENT;
    vec3 Albedo = data.albedo * dayTimeColor;

    if(!isMetal) {
        /* LAMBERTIAN MODEL */
        //DiffuseLighting += Albedo * E0;
        
        /* OREN-NAYAR MODEL - QUALITATIVE */
        float aNdotL = acos(NdotL);
        float aNdotV = acos(NdotV);

        float A = 1.0 - 0.5 * (alpha / (alpha + 0.4));
        float B = 0.45 * (alpha / (alpha + 0.09));
        DiffuseLighting += Albedo * (A + (B * max(0.0, cos(aNdotV - aNdotL)))) * E0;
    }

    vec3 Lighting = DiffuseLighting + SpecularLighting;
    Lighting += data.albedo * data.emission;

    return Lighting * data.ao;
}