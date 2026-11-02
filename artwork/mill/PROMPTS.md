# Registered ink-to-watercolor workflow

The single owner-approved red-mill watercolor illustration is the ONLY style reference.
The owner's mill photograph supplies architectural facts, visible viewpoint and actual
material colors. Do not use any other Mill, Greystone, postcard or historical artwork
as a style source.

## Stage 1 — Generate the uncolored composition, then define and freeze its layers

Copy this prompt and attach the sole approved style reference and subject photographs:

> Create an uncolored architectural pen-and-ink composition of [LANDMARK]. Use the
> attached approved watercolor illustration as the only drawing-style authority.
> Interpret the economical, nearly black architectural pen work visible inside it,
> without its paint. Use the photographs only for architecture, material identity,
> viewpoint and context. Ignore every other illustration as a style reference.
>
> Subject: [NAME]. Required viewpoint: [VIEW]. Essential identifying features:
> [LIST]. Context to include: [LIST]. Canvas: [EXACT WIDTH] by [EXACT HEIGHT] pixels.
>
> Preserve recognizable proportions, convincing perspective, roof geometry,
> openings, entrances, towers, chimneys and distinctive materials. Do not copy the
> style reference's building layout onto a different subject. Flag uncertain
> identifying features rather than inventing them.
>
> Use fine, nearly black architectural pen strokes with modest weight variation,
> occasional broken and doubled contours, stronger eaves and overlap edges, small
> concentrated dark recesses, and limited hatching. Keep broad light surfaces.
> Suggest foliage and water with economical, spontaneous marks. Do not compensate
> for removing color by adding dense crosshatching, stippling, graphite modeling,
> scratchboard or extra material texture. No cartoon/vector outlines or photo filter.
>
> Make the landmark dominant. Keep the entire intended vignette within the exact
> canvas, with comfortable surrounding margins. Do not auto-crop or rescale.
> Exterior background must be genuinely transparent. Keep intentional light subject
> details. No watercolor, gray wash, sepia, background sheet, sky rectangle, paper
> texture, circle, frame, lettering, signature, watermark, tools, glow or blurred halo.
>
> Generate one ink draft. Do not claim that the generator has produced independent
> editable layers, a verified mask, or exact registration. Those are processing steps.

After inspecting the draft, use non-generative image processing or a layer editor to:

1. Separate pen strokes into a transparent, full-canvas **INK_MASTER**.
2. Define the full-canvas **SUBJECT_BASE**, keeping white subject surfaces distinct
   from exterior transparency.
3. Preserve fine white subject details, especially window glazing bars, in a separate
   **WHITE_RESERVES** layer if color beneath the ink would otherwise tint them.
4. Define **ARTWORK_MASK**, including intended vegetation, water, light reserves and
   peripheral marks. The mask is the final alpha channel for BOTH composites.
5. Review the assembled uncolored composition. This is the point at which the
   canonical ink, reserves, mask, dimensions and placement become fixed. The raw AI
   draft is retained for provenance but is not confused with the separated master.
6. Save master pixel hashes. Do not alter, warp, resample or independently trim the
   approved master after this point.

For future landmark commissions, approve this master before generating paint. The owner subsequently approved the completed Mill pair as the authoritative
app artwork. Future commissions still require approval before replacing app assets.

## Stage 2 — Generate a paint-only proposal, then assemble beneath the fixed ink

Attach the original style reference, subject photographs and canonical ink preview.

> Produce ONLY a watercolor paint underlay for this fixed ink composition of
> [LANDMARK]. Canvas dimensions are [WIDTH] by [HEIGHT]. Match its subject scale,
> position, perspective and context. Do not change any architecture or add objects.
> This is an intermediate paint proposal, not the final registered illustration.
>
> The single approved red-mill watercolor is the only style authority. Subject
> photographs supply actual colors; the ink master supplies all composition and
> architecture. Do not copy the style reference's different building geometry.
>
> Generate loose watercolor masses, not a new ink drawing. No new black contours,
> hatching, pencil marks, window outlines or architectural linework. The original
> ink will be composited separately and must provide those details.
>
> Match luminous granular pigment, broken translucent coverage, irregular wash
> boundaries, dry-brush passages, localized pooling, broad light reserves, varied
> foliage dabs and directional water strokes. Do not fill every shape uniformly.
> Keep colors fresh and natural. Use warm reds, slate blue-grays, buff/ochre stone,
> yellow-green/olive/deep-green plants and clear blue-green water only as appropriate
> to the photographed subject. Do not make all future buildings red.
>
> No glossy rendering, smooth digital gradients, airbrushing, global sepia or green
> tint, opaque paint obscuring detail, photographic texture, paper sheet, frame,
> lettering, signature or watermark. Maintain a transparent exterior. Stay inside
> the approved artwork footprint; add no new external splashes. Do not trim or resize.

Required deterministic assembly — never skip this step:

- Inspect pigment placement against the ink. Correct PAINT placement when necessary;
  never move the ink or warp the approved drawing to fit generated color.
- Keep the same original INK_MASTER, WHITE_RESERVES and SUBJECT_BASE in both versions.
- Stack: original ink at top; white reserves below it; paint below the reserves;
  subject base at bottom. Apply the one shared ARTWORK_MASK to the final composition.
- Reveal only the watercolor layer during animation. Ink, reserves, base and final
  mask remain stationary. Avoid crossfading two separately generated full images.
- Export ink and watercolor composites without any independent crop, resize,
  translation or optimization. Use lossless PNG and consistent sRGB interpretation.
- Confirm equal canvas dimensions, zero differing alpha pixels and unchanged ink
  master data. Check 0%, 25%, 50%, 75% and 100% reveal states.
- Pixel registration verifies fixed linework and alpha. It does not prove perfect
  architecture, stylistic identity, or automatic alignment of every painted detail.
  Those still require visual review.
