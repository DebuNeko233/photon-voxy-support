#if !defined INCLUDE_MISC_LOD_MOD_SUPPORT
#define INCLUDE_MISC_LOD_MOD_SUPPORT

/*
 * Utility include for LoD mod support (Distant Horizons and Voxy).
 *
 * Native Vulkan Voxy under Vitrail does not pass through Iris' Voxy patcher, so
 * the usual VOXY engine define and vxDepthTex/vxProj uniforms do not exist.
 * This dedicated Photon fork therefore has a third LoD transport: Voxy writes
 * forward depth into colortex17.r and its classic vxRenderDistance-equivalent
 * value into colortex17.g.  A cleared bridge is (1, 0), which behaves as no LoD
 * terrain until the native renderer has opened the frame.
 */
#if !defined DISTANT_HORIZONS && !defined VOXY
#define VOXY_NATIVE_VULKAN_VITRAIL
#ifndef LOD_MOD_ACTIVE
#define LOD_MOD_ACTIVE
#endif
#endif

#if defined DISTANT_HORIZONS
// --------------------
//   Distant Horizons
// --------------------

uniform sampler2D colortex15;

uniform sampler2D dhDepthTex;
uniform sampler2D dhDepthTex1;
uniform mat4 dhProjection;
uniform mat4 dhProjectionInverse;
uniform mat4 dhPreviousProjection;
uniform mat4 dhModelView;
uniform mat4 dhModelViewInverse;
uniform float dhNearPlane;
uniform float dhFarPlane;
uniform int dhRenderDistance;

uniform float combined_near;
uniform float combined_far;

uniform vec4 combined_projection_matrix_0;
uniform vec4 combined_projection_matrix_1;
uniform vec4 combined_projection_matrix_2;
uniform vec4 combined_projection_matrix_3;

uniform vec4 combined_projection_matrix_inverse_0;
uniform vec4 combined_projection_matrix_inverse_1;
uniform vec4 combined_projection_matrix_inverse_2;
uniform vec4 combined_projection_matrix_inverse_3;

#define combined_depth_tex colortex15
#define lod_depth_tex dhDepthTex
#define lod_depth_tex_solid dhDepthTex1
#define lod_depth_tex_shading lod_depth_tex
#define lod_depth_tex_scale taau_render_scale
#define lod_projection_matrix dhProjection
#define lod_projection_matrix_inverse dhProjectionInverse
#define lod_previous_projection_matrix dhPreviousProjection
#define lod_render_distance dhRenderDistance
#define combined_projection_matrix \
    mat4( \
        combined_projection_matrix_0, \
        combined_projection_matrix_1, \
        combined_projection_matrix_2, \
        combined_projection_matrix_3 \
    )
#define combined_projection_matrix_inverse \
    mat4( \
        combined_projection_matrix_inverse_0, \
        combined_projection_matrix_inverse_1, \
        combined_projection_matrix_inverse_2, \
        combined_projection_matrix_inverse_3 \
    )
#elif defined VOXY
// -----------------------
//   Voxy (Iris / classic)
// -----------------------

uniform sampler2D colortex15;

uniform sampler2D vxDepthTexOpaque;
uniform sampler2D vxDepthTexTrans;
uniform mat4 vxProj;
uniform mat4 vxProjInv;
uniform mat4 vxProjPrev;
uniform int vxRenderDistance;

float combined_near = near;
float combined_far = float(16 * vxRenderDistance);

mat4 combined_projection_matrix = mat4(
    vec4(gbufferProjection[0][0], 0.0, 0.0, 0.0),
    vec4(0.0, gbufferProjection[1][1], 0.0, 0.0),
    vec4(
        gbufferProjection[2][0],
        gbufferProjection[2][1],
        (combined_far + combined_near) / (combined_near - combined_far),
        -1.0
    ),
    vec4(
        0.0,
        0.0,
        (2.0 * combined_far * combined_near) / (combined_near - combined_far),
        0.0
    )
);

mat4 combined_projection_matrix_inverse = mat4(
    vec4(gbufferProjectionInverse[0][0], 0.0, 0.0, 0.0),
    vec4(0.0, gbufferProjectionInverse[1][1], 0.0, 0.0),
    vec4(
        0.0,
        0.0,
        0.0,
        -(combined_far - combined_near) / (2.0 * combined_far * combined_near)
    ),
    vec4(
        gbufferProjectionInverse[3][0],
        gbufferProjectionInverse[3][1],
        -1.0,
        (combined_far + combined_near) / (2.0 * combined_far * combined_near)
    )
);

#define combined_depth_tex colortex15
#define lod_depth_tex vxDepthTexTrans
#define lod_depth_tex_solid vxDepthTexOpaque
#define lod_depth_tex_shading lod_depth_tex_solid
#define lod_depth_tex_scale 1.0
#define lod_projection_matrix vxProj
#define lod_projection_matrix_inverse vxProjInv
#define lod_previous_projection_matrix vxProjPrev
#define lod_render_distance (vxRenderDistance * 16)
#elif defined VOXY_NATIVE_VULKAN_VITRAIL
// ----------------------------------
//   Voxy (native Vulkan + Vitrail)
// ----------------------------------

uniform sampler2D colortex15;
uniform sampler2D colortex17;

// Matches VoxyUniforms' classic Iris contract: vxRenderDistance is
// round(sectionRenderDistance * 32), and Photon turns it into blocks by *16.
float voxy_native_render_distance_chunks() {
    return max(texelFetch(colortex17, ivec2(0), 0).g, 0.0);
}

float voxy_native_render_distance_blocks() {
    float chunks = voxy_native_render_distance_chunks();
    return chunks > 0.0 ? chunks * 16.0 : far;
}

// VkRenderCore uses the same projection policy as the classic renderer: a 16
// block near plane (8 only at the pathological two-chunk vanilla distance) and
// a fixed 3000-chunk projection far plane.  colortex17 stores a forward 0..1
// depth even when Minecraft/Voxy rasterise reverse-Z, so Photon can keep using
// its ordinary OpenGL-style screen-depth reconstruction.
float voxy_native_projection_near() {
    return far <= 32.0 ? 8.0 : 16.0;
}

const float voxy_native_projection_far = 16.0 * 3000.0;

mat4 voxy_native_projection(float projection_near, float projection_far) {
    return mat4(
        vec4(gbufferProjection[0][0], 0.0, 0.0, 0.0),
        vec4(0.0, gbufferProjection[1][1], 0.0, 0.0),
        vec4(
            gbufferProjection[2][0],
            gbufferProjection[2][1],
            (projection_far + projection_near) / (projection_near - projection_far),
            -1.0
        ),
        vec4(
            0.0,
            0.0,
            (2.0 * projection_far * projection_near) / (projection_near - projection_far),
            0.0
        )
    );
}

mat4 voxy_native_projection_inverse(float projection_near, float projection_far) {
    return mat4(
        vec4(gbufferProjectionInverse[0][0], 0.0, 0.0, 0.0),
        vec4(0.0, gbufferProjectionInverse[1][1], 0.0, 0.0),
        vec4(
            0.0,
            0.0,
            0.0,
            -(projection_far - projection_near)
                / (2.0 * projection_far * projection_near)
        ),
        vec4(
            gbufferProjectionInverse[3][0],
            gbufferProjectionInverse[3][1],
            -1.0,
            (projection_far + projection_near)
                / (2.0 * projection_far * projection_near)
        )
    );
}

#define combined_near near
#define combined_far voxy_native_render_distance_blocks()
#define combined_depth_tex colortex15
#define lod_depth_tex colortex17
#define lod_depth_tex_solid colortex17
#define lod_depth_tex_shading colortex17
#define lod_depth_tex_scale 1.0
#define lod_projection_matrix \
    voxy_native_projection(voxy_native_projection_near(), voxy_native_projection_far)
#define lod_projection_matrix_inverse \
    voxy_native_projection_inverse(voxy_native_projection_near(), voxy_native_projection_far)
// Vitrail already carries previous camera/model-view state. Projection changes
// are rare; use the current Voxy projection until a native previous-projection
// transport is added.
#define lod_previous_projection_matrix lod_projection_matrix
#define lod_render_distance voxy_native_render_distance_blocks()
#define combined_projection_matrix \
    voxy_native_projection(combined_near, combined_far)
#define combined_projection_matrix_inverse \
    voxy_native_projection_inverse(combined_near, combined_far)
#else
#define combined_near near
#define combined_far far
#define combined_projection_matrix gbufferProjection
#define combined_projection_matrix_inverse gbufferProjectionInverse
#define combined_depth_tex depthtex1

#define sample_depth_texture texture
#endif

bool is_lod_terrain(float depth, float depth_lod) {
    return depth >= 1.0 && depth_lod < 1.0;
}

#endif // INCLUDE_MISC_LOD_MOD_SUPPORT
