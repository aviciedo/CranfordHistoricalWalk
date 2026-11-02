> Historical review notes: the owner subsequently approved all final proposals and requested integration/publication. Build 127 contains these exact final layers. The draft-only statements below describe the review stage.

# Watercolor review: Mill, Greystone and First Baptist Church

Status: review drafts only, as requested. No app assets, code, Xcode project, branches or published builds were changed for this review.

## What the sole approved reference actually does

The reference combines precise selective dark accents with freely painted color. Pigment strength varies within a surface; dry-brush white interruptions and unpainted highlights provide much of its light. Roof and water alternate cool blue/slate passages with clean white. Foliage groups golden yellow, olive and deep green in irregular masses. The stone foundation has warm/cool variation and only selected dark stones. Its energy comes from that uneven distribution of pigment and detail, rather than an identical rough texture applied everywhere.

The aim is to borrow this handling while retaining each subject's actual materials. Greystone should remain gray/buff stone with a red-brown roof; the church should remain white. Neither should inherit the mill's red walls, river, viewpoint or invented features. Existing transparent artwork footprints are retained, so the proposals deliberately do not copy the reference's exterior paint splatters.

## Droescher’s Mill

**Before:** The current app watercolor is relatively evenly filled: the red wall's continuous horizontal siding texture, tightly modeled foundation, and broad reflective river create a more finished, illustrative appearance than the reference. It also still uses the earlier dense ink, while Home/Stops already use the newly approved refined ink. Removed roof equipment and walkway fixtures are still visible in that older watercolor.

**Recommended and implemented in the draft:** Use the newly approved cleaned ink composition. Break up the coral/russet wall and blue-slate roof with irregular dry-brush reserves. Vary pigment within broad passages rather than painting every board. Open up white channels between turquoise/blue-green river strokes; reduce the continuous reflective carpet. Keep the waterfall predominantly white. Group golden/olive/dark-green foliage and warm buff/cool-gray rocks with selected stronger accents.

**Why:** This brings the strongest color and water handling closer to the reference while allowing the pen drawing and white reserves to remain visible. It also carries the approved fixture removals into watercolor.

**Comparison caveat:** Mill's before is the actual current app watercolor, not an artificially recolored version. Its after also includes the already approved ink revision, so this is not a paint-only A/B comparison. The Mill's new ink was separated into fixed full-canvas layers before generating paint. No stroke positions were moved; the flattened source is retained for provenance. The new fixed-layer pair, rather than the older app pair, is the registered reveal candidate.

## Greystone

**Before:** The repeated gray/buff stone patches distribute texture nearly equally over the facade. The cream timber and masonry can read as a neatly filled mosaic, with limited distinction between connected light planes and selected dark accents.

**Recommended and implemented in the draft:** Use broader connected transparent slate/buff washes, pick out fewer individual stones, and retain warm light interruptions. Lighten the cream timber/porch. Keep selective red-violet roof variation, granulation and dry-brush highlights. Group foliage into less uniform yellow/olive/deep-green masses.

**Why:** Connected washes reduce the stone-by-stone coloring effect and give the frozen ink more of the descriptive work. The result is a quieter interpretation of the reference, appropriate to a predominantly gray building. A first attempt with repeated large white gaps was rejected as too patchy; the final proposal is more restrained. The flag/pole, arch window, bushes and previous fixture removals remain.

## First Baptist Church

**Before:** The existing watercolor is already airy and reasonably close to the target. Its principal weakness is a repeated pattern of pale cool marks across the white walls, plus relatively even color in doors and steps. It needs a smaller change than the other two.

**Recommended and implemented in the draft:** Protect broad white wall planes and reduce facade pigment strength. Concentrate stronger granular blue-gray in the roof, broken reddish-brown in doors, and terracotta/cool accents in the steps. Retain the approved blue-violet stained glass palette, admitting a restrained amount of new pigment variation rather than redesigning its colors. Keep the small plantings within the fixed footprint.

**Why:** The reference's luminous handling depends on unpainted light; adding stronger wash to every white wall would move this subject away from its real appearance. The more restrained change keeps the church white while making the colored materials less uniformly filled.

**Assembly choice:** An additional generated refinement was rejected because it redrew pen lines. The final uses the paint-only proposal, deterministic attenuation of facade paint, and 75% retention of the prior approved glazing color in selected glass regions. These operations affect only paint; the ink, base, white reserves and final alpha remain byte-identical to their frozen originals. The assembly script records the exact operations.

## Deliverables and verification

Each stop folder contains `before.png` copied directly from the current app, `after.png` as a transparent lossless sRGB draft, `before-after.jpg` as an explicitly white-background comparison, `ink.png`, the four frozen source layers, the revised watercolor underlay and five reveal checkpoints. The new canvas sizes remain 1536 × 1024 for Mill/Greystone and 1024 × 1536 for Church.

`verification.json` confirms all fixed layer file hashes remain unchanged after painting; each new ink/watercolor pair has zero differing alpha pixels; and 0%, 25%, 50%, 75%, 100% reveal frames share the mask. Greystone and Church retain exactly the same ink in their before and after versions. Original masters are not cropped, rescaled, rotated or warped. The comparison images use identical full-canvas scaling within each pair; their white presentation surface is not baked into the transparent exports.

Pixel registration guarantees stationary ink and transparency, not perfect placement of every generated pigment edge. These remain proposals for owner visual approval. No native app testing is claimed for this artwork-only review.
