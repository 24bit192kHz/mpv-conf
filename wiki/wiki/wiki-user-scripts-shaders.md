## User Shaders

A guide for how to write user shaders [can be found here](https://libplacebo.org/custom-shaders/).

* **[A-Pack](https://github.com/butterw/bShaders/tree/master/A-pack)** — Shaders pack for quick adjustment of web video: brightness/contrast curves (tooDark, tooBright, bShadows, bDim, etc.) and color (vibrance, skintones, Black&White). Runs on integrated graphics.
* **[Anime4K](https://github.com/bloc97/Anime4K)** — Series of shaders for scaling/enhancing anime: line sharpening, artefact removal, denoising, upscaling.
* **[LumaSharpenHook](https://gist.github.com/voltmtr/8b4404b4e23129b226b9e64863d3e28b)** — Sharpen filter similar to Unsharp Mask from SweetFX.
* **[SSimDownscaler, SSimSuperRes, Krig, Adaptive Sharpen](https://gist.github.com/igv)** — Perceptually based downscaler; corrections to image upscaled by built-in scaler; luma-informed chroma scaler.
* **[Noise](https://github.com/haasn/gentoo-conf)** — Uniform white noise filter.
* **[Film Grain v1](https://raw.githubusercontent.com/haasn/gentoo-conf/xor/home/nand/.mpv/shaders/filmgrain.glsl) & [v2](https://raw.githubusercontent.com/haasn/gentoo-conf/xor/home/nand/.mpv/shaders/filmgrain-smooth.glsl)** — Gaussian-weighted white noise film grain.
* **[Antiringing](https://github.com/haasn/gentoo-conf)** — Clamp-based antiringing that works with polar/EWA filters.
* **[nnedi3 and ravu](https://github.com/bjin/mpv-prescalers)** — User shaders for prescaling.
* **[FSRCNN](https://github.com/igv/FSRCNN-TensorFlow/releases)** — Prescaler based on layered convolutional networks.
* **[un360](https://gist.github.com/tesu/196db5421559de3e9555d4f9da9d847d)** — Convert equirectangular 360° video to fixed perspective.
* **[acme-0.5x](https://gist.github.com/bjin/15f307e7a1bdb55842bbb663ee1950ed)** — 0.5x downscaler for 4K on FHD screens with iGPU.
* **[Nonlinear stretch](https://gist.github.com/sarahzrf/c9909aee70e3656895820f20ac395956)** — Nonlinear stretch scaling. Use with `--no-keepaspect`.
* **[lensfix](https://gist.github.com/bjin/33ffbc0fbdbc00aefa21b2e44bbd27cd)** — Fix radial distortion from wide angle action cameras.
* **[hyperview](https://gist.github.com/bjin/399cb23818ad210941725ef768893499)** — Dynamic stretching filter like GoPro SuperView.
* **[NLS-Next](https://github.com/NotMithical/MPV-NLS-Next)** — Nonlinear stretch shader with bidirectional stretching.
* **[FidelityFX CAS](https://gist.github.com/agyild/bbb4e58298b2f86aa24da3032a0d2ee6)** — AMD Contrast Adaptive Sharpening.
* **[FidelityFX FSR](https://gist.github.com/agyild/82219c545228d70c5604f865ce0b0ce5)** — AMD FidelityFX Super Resolution spatial upscaler.
* **[NVIDIA Image Scaling](https://gist.github.com/agyild/7e8951915b2bf24526a9343d951db214)** — NVIDIA spatial scaling and sharpening.
* **[Post upscale unsharp masking](https://github.com/garamond13/unsharp_masking.glsl)** — mpv's original sharpening ported to shader (works after upscaling).
* **[nlmeans, hdeband, & more](https://github.com/AN3223/dotfiles)** — Non-local Means denoising + adaptive sharpening; debanding.
* **[Alt Scale](https://github.com/garamond13/alt-scale)** — Alternative to built-in scaling, slightly faster.
* **[Unsharp mask and Gaussian blur](https://github.com/garamond13/Unsharp-mask-and-Gaussian-blur)** — 2-pass implementations.
* **[2D Image Resampling](https://github.com/garamond13/2D-Image-Resampling)** — General resampling for testing.
* **[Jinc](https://github.com/garamond13/Jinc)** — Jinc-based image scaling (similar to mpv's ewa/polar).
* **[Pixel Clipper](https://github.com/Artoriuz/glsl-pixel-clipper)** — Simple antiringing via pixel clipping.
* **[JointBilateral & FastBilateral](https://github.com/Artoriuz/glsl-joint-bilateral)** — Luma-guided chroma upsamplers.
* **[Chroma from Luma Prediction](https://github.com/Artoriuz/glsl-chroma-from-luma-prediction)** — Chroma upsamplers via least-squares linear regression.
* **[ArtCNN](https://github.com/Artoriuz/ArtCNN)** — Luma doublers trained on Manga109.
* **[CuNNy](https://github.com/funnyplanter/CuNNy)** — CNN-based upscaler optimized for anime.
* **[AniSD ArtCNN](https://github.com/Sirosky/Upscale-Hub/releases/tag/AniSD-ArtCNN)** — For standard definition anime.
* **[Ani4K v2 ArtCNN](https://github.com/Sirosky/Upscale-Hub/releases/tag/Ani4k-v2-ArtCNN)** — Targets modern anime for upscaling to 2K or 4K.
* **[Snapdragon GSR v1](https://gist.github.com/agyild/7715b6b1f38427839d58f80884902cab)** — Single-pass spatial upscaling from Qualcomm.
* **[Fast Catmull-Rom](https://github.com/garamond13/Fast-Catmull-Rom)** — 5-sample Catmull-Rom approximation.
