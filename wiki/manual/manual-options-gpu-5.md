FILTER <LINEAR|NEAREST>

The min/magnification filter used when sampling from this texture.

BORDER <CLAMP|REPEAT|MIRROR>

The border wrapping mode used when sampling from this texture.

Following the metadata is a string of bytes in hexadecimal notation that
define the raw texture data, corresponding to the format specified by
<cite>FORMAT</cite>, on a single line with no extra whitespace.

A `HOOK` block can set the following options:

HOOK <name> (required)

The texture which to hook into. May occur multiple times within a
metadata block, up to a predetermined limit. See below for a list of
hookable textures.

DESC <title>

User-friendly description of the pass. This is the name used when
representing this shader in the list of passes for property
<cite>vo-passes</cite>.

BIND <name>

Loads a texture (either coming from mpv or from a `TEXTURE` block)
and makes it available to the pass. When binding textures from mpv,
this will also set up macros to facilitate accessing it properly. See
below for a list. By default, no textures are bound. The special name
HOOKED can be used to refer to the texture that triggered this pass.

SAVE <name>

Gives the name of the texture to save the result of this pass into. By
default, this is set to the special name HOOKED which has the effect of
overwriting the hooked texture.

WIDTH <szexpr>, HEIGHT <szexpr>

Specifies the size of the resulting texture for this pass. `szexpr`
refers to an expression in RPN (reverse polish notation), using the
operators + - * / > < !, floating point literals, and references to
sizes of existing texture (such as MAIN.width or CHROMA.height),
OUTPUT, or NATIVE_CROPPED (size of an input texture cropped after
pan-and-scan, video-align-x/y, video-pan-x/y, etc. and possibly
prescaled). By default, these are set to HOOKED.w and HOOKED.h,
espectively.

WHEN <szexpr>

Specifies a condition that needs to be true (non-zero) for the shader
stage to be evaluated. If it fails, it will silently be omitted. (Note
that a shader stage like this which has a dependency on an optional
hook point can still cause that hook point to be saved, which has some
minor overhead)

OFFSET <ox oy | ALIGN>

Indicates a pixel shift (offset) introduced by this pass. These pixel
offsets will be accumulated and corrected during the next scaling pass
(`cscale` or `scale`). The default values are 0 0 which correspond
to no shift. Note that offsets are ignored when not overwriting the
hooked texture.

A special value of `ALIGN` will attempt to fix existing offset of
HOOKED by align it with reference. It requires HOOKED to be resizable
(see below). It works transparently with fragment shader. For compute
shader, the predefined `texmap` macro is required to handle coordinate
mapping.

COMPONENTS <n>

Specifies how many components of this pass's output are relevant and
should be stored in the texture, up to 4 (rgba). By default, this value
is equal to the number of components in HOOKED.

COMPUTE <bw> <bh> [<tw> ]

Specifies that this shader should be treated as a compute shader, with
the block size bw and bh. The compute shader will be dispatched with
however many blocks are necessary to completely tile over the output.
Within each block, there will be tw*th threads, forming a single work
group. In other words: tw and th specify the work group size, which can
be different from the block size. So for example, a compute shader with
bw, bh = 32 and tw, th = 8 running on a 500x500 texture would dispatch
16x16 blocks (rounded up), each with 8x8 threads.

Compute shaders in mpv are treated a bit different from fragment
shaders. Instead of defining a `vec4 hook` that produces an output
sample, you directly define `void hook` which writes to a fixed
writeonly image unit named `out_image` (this is bound by mpv) using
<cite>imageStore</cite>. To help translate texture coordinates in the absence of
vertices, mpv provides a special function `NAME_map(id)` to map from
the texel space of the output image to the texture coordinates for all
bound textures. In particular, `NAME_pos` is equivalent to
`NAME_map(gl_GlobalInvocationID)`, although using this only really
makes sense if (tw,th) == (bw,bh).

Each bound mpv texture (via `BIND`) will make available the following
definitions to that shader pass, where NAME is the name of the bound
texture:

vec4 NAME_tex(vec2 pos)

The sampling function to use to access the texture at a certain spot
(in texture coordinate space, range [0,1]). This takes care of any
necessary normalization conversions.

vec4 NAME_texOff(vec2 offset)

Sample the texture at a certain offset in pixels. This works like
NAME_tex but additionally takes care of necessary rotations, so that
sampling at e.g. vec2(-1,0) is always one pixel to the left.

vec2 NAME_pos

The local texture coordinate of that texture, range [0,1].

vec2 NAME_size

The (rotated) size in pixels of the texture.

mat2 NAME_rot

The rotation matrix associated with this texture. (Rotates pixel space
to texture coordinates)

vec2 NAME_pt

The (unrotated) size of a single pixel, range [0,1].

float NAME_mul

The coefficient that needs to be multiplied into the texture contents
in order to normalize it to the range [0,1].

sampler NAME_raw

The raw bound texture itself. The use of this should be avoided unless
absolutely necessary.

Normally, users should use either NAME_tex or NAME_texOff to read from the
texture. For some shaders however , it can be better for performance to do
custom sampling from NAME_raw, in which case care needs to be taken to
respect NAME_mul and NAME_rot.

In addition to these parameters, the following uniforms are also globally
available:

float random

A random number in the range [0-1], different per frame.

int frame

A simple count of frames rendered, increases by one per frame and never
resets (regardless of seeks).

vec2 input_size

The size in pixels of the input image (possibly cropped and prescaled).

vec2 target_size

The size in pixels of the visible part of the scaled (and possibly
cropped) image.

vec2 tex_offset

Texture offset introduced by user shaders or options like panscan, video-align-x/y, video-pan-x/y.

Internally, vo_gpu may generate any number of the following textures.
Whenever a texture is rendered and saved by vo_gpu, all of the passes
that have hooked into it will run, in the order they were added by the
user. This is a list of the legal hook points:

RGB, LUMA, CHROMA, ALPHA, XYZ (resizable)

Source planes (raw). Which of these fire depends on the image format of
the source.

CHROMA_SCALED, ALPHA_SCALED (fixed)

Source planes (upscaled). These only fire on subsampled content.

NATIVE (resizable)

The combined image, in the source colorspace, before conversion to RGB.

MAINPRESUB (resizable)

The image, after conversion to RGB, but before
