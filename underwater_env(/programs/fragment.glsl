#version 330
layout(location = 0) out vec4 fragColor;

uniform vec2 u_resolution;
uniform float u_time;

const float EPSILON = 0.001;
const float MAX_DIST = 1800.0;
const float STEPS = 580.0;
const float PI = acos(-1.0);
const int NUM_OCTAVES = 7;
uniform float TERRAIN_SIZE;

struct TrashObject {
    vec3 position; // The position of the trash object
    float size;    // The size of the trash object
    vec3 color;    // The color of the trash object
};

const int NUM_TRASH_OBJECTS = 50; // Adjust the number as needed
TrashObject trashObjects[NUM_TRASH_OBJECTS];

float noise(vec2 p) {
    return sin(p[0]) + sin(p[1]);
}

mat2 rot(float a) {
    float sa = sin(a);
    float ca = cos(a);
    return mat2(ca, -sa, sa, ca);
}

float rand(float seed) {
    seed = mod(seed * 1664525.0 + 1013904223.0, 4294967296.0);
    return seed / 4294967296.0;
}

float fbm(vec2 p) {
    float res = 0.0;
    float amp = 0.5;
    float freq = 1.95;
    for (int i = 0; i < NUM_OCTAVES; i++) {
        res += amp * noise(p);
        amp *= 0.5;
        p = p * freq * rot(PI / 4.0) - res * 0.4;
    }
    return res;
}


float getTerrain(vec3 p) {
    float d = 0;
    d -= 30.0 * noise(p.xz * 0.002);
    d += 30.0 * noise(p.xz * 0.01) + 30.0;
    d += 10.0 * fbm(p.xz * 0.1) * noise(p.xz * 0.01) + 10.0;
    d -= 2.0 * sin(0.6 * d);
    d += p.y + 2.0;
    return d * 0.1;
}



vec3 renderTrashObjects(vec3 p) {
    vec3 trashColor = vec3(0.2, 0.2, 0.2); // Trash color
    float minDistanceToTerrain = 2.0; // Minimum distance to terrain

    for (int i = 0; i < NUM_TRASH_OBJECTS; i++) {
        TrashObject trash = trashObjects[i];
        float trashDistance = distance(p.xz, trash.position.xz);

        // Calculate the distance to the terrain
        float terrainHeight = getTerrain(vec3(trash.position.x, p.y, trash.position.z));
        float distanceToTerrain = p.y - terrainHeight;

        // Only render the trash if it's not too close to the terrain
        if (trashDistance < trash.size && distanceToTerrain > minDistanceToTerrain) {
            // You can use the size and color information to render the trash
            float trashFactor = (trash.size - trashDistance) / trash.size;
            vec3 trashRenderColor = trashColor * trashFactor;
            return trashRenderColor;
        }
    }

    return vec3(0.0);
}


// fbm stands for fractal brownian motion


float getWater(vec3 p) {
    return 0.0;
}

float map(vec3 p) {
    float d = 0.0;
    d += getTerrain(p);
    return min(d, getWater(p) + d);
}

float rayMarch(vec3 ro, vec3 rd) {
    float dist = 0.0;
    for (int i = 0; i < STEPS; i++) {
        vec3 p = ro + dist * rd;
        float hit = map(p);
        if (abs(hit) < EPSILON) break;
        dist += hit;
        if (dist > MAX_DIST) break;
    }
    return dist;
}

vec3 getNormal(vec3 p) {
    vec2 e = vec2(EPSILON, 0.0);
    vec3 n = vec3(map(p)) - vec3(map(p - e.xyy), map(p - e.yxy), map(p - e.yyx));
    return normalize(n);
}

float getAmbientOcclusion(vec3 p, vec3 normal) {
    float occ = 0.0;
    float weight = 0.4;
    for (int i = 0; i < 8; i++) {
        float len = 0.01 + 0.02 * float(i * i);
        float dist = map(p + normal * len);
        occ += (len - dist) * weight;
        weight *= 0.85;
    }
    return 1.0 - clamp(0.6 * occ, 0.0, 1.0);
}

float getSoftShadow(vec3 p, vec3 lightPos) {
    float res = 1.0;
    float dist = 0.01;
    float lightSize = 0.03;
    for (int i = 0; i < 8; i++) {
        float hit = map(p + lightPos * dist);
        res = min(res, hit / (dist * lightSize));
        if (hit < EPSILON) break;
        dist += hit;
        if (dist > 30.0) break;
    }
    return clamp(res, 0.0, 1.0);
}

vec3 lightPos = vec3(250.0, 100.0, -300.0) * 4.0;

vec3 getLight(vec3 p, vec3 rd) {
    vec3 color = vec3(1);
    vec3 l = normalize(lightPos - p);
    vec3 normal = getNormal(p);
    vec3 v = -rd;
    vec3 r = reflect(-l, normal);

    float diff = 0.85 * max(dot(l, normal), 0.0);
    float specular = 0.4 * pow(clamp(dot(r, v), 0.0, 1.0), 10.0);
    float ambient = 0.2;

    float shadow = getSoftShadow(p, lightPos);
    float occ = getAmbientOcclusion(p, normal);
    return (ambient * occ + (specular * occ + diff) * shadow) * color;
}

mat3 getCam(vec3 ro, vec3 lookAt) {
    vec3 camF = normalize(vec3(lookAt - ro));
    vec3 camR = normalize(cross(vec3(0, 1, 0), camF));
    vec3 camU = cross(camF, camR);
    return mat3(camR, camU, camF);
}

vec3 getSky(vec3 p, vec3 rd) {
    vec3 col = vec3(0.0);
    col = vec3(0.0, 0.5, 1.0);

    float sun = 0.01 / (1.0 - dot(rd, normalize(lightPos)));
    col = mix(col, vec3(0.3), 2.0 * fbm(vec2(20.5 * length(rd.xz), rd.y)));
    col += sun * 0.1;
    return col;
}
vec3 renderTerrain(vec3 p) {
    // Scale the position to control the terrain features
    vec2 scaledPos = p.xz * 0.05;

    // Use Perlin noise to create a heightmap for the terrain
    float terrainHeight = 10.0 * noise(scaledPos);

    // Define the terrain color based on the height
    vec3 terrainColor;
    if (terrainHeight < 0.0) {
        terrainColor = vec3(0.0, 0.5, 0.0); // Green color for lower terrain
    } else {
        terrainColor = vec3(0.7, 0.7, 0.7); // Gray color for higher terrain
    }

    // Combine terrain height and color
    float terrainFactor = smoothstep(0.0, 0.1, terrainHeight);
    return mix(vec3(0.0), terrainColor, terrainFactor);
}

vec3 render(vec2 uv) {
    vec3 col = vec3(0);
    vec3 ro = vec3(220.0, 50.0 * sin(u_time * 0.5) + 50.0, 220.0);
    vec3 lookAt = vec3(0, 1, 0);
    vec3 rd = getCam(ro, lookAt) * normalize(vec3(uv, 2.0));
    float dist = rayMarch(ro, rd);
    vec3 p = ro + dist * rd;

    // Render the terrain color first
    col += renderTerrain(p);

    // Render the trash objects on top of the terrain
    vec3 trashColor = renderTrashObjects(p);
    col += trashColor;

    // Lighting and sky as before
    col = mix(getLight(p, rd), col, exp(-0.0000007 * dist * dist));
    return col;
}

void main() {
    vec2 uv = (2.0 * gl_FragCoord.xy - u_resolution.xy) / u_resolution.y;
    vec3 color = render(uv);
    color = mix(color, vec3(0.0, 0.3, 0.8), 0.5);

    fragColor = vec4(pow(color, vec3(1.5)), 1.0);
}
