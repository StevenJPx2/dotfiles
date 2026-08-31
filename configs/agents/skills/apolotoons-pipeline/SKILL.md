---
name: apolotoons-pipeline
description: Manage the Apolotoons comic production pipeline — scaffold new episode folders, remove speech bubbles, upscale generated comic strips with Upscayl, and cut strips into panels. Runs manually on request (no background watcher); the agent runs the pipeline and verifies the panel cuts. Use when the user mentions Apolotoons, comic episodes, comic strips, panel cutting, upscaling slides, bubble removal, or the Generated/Cleaned/Upscaled/Panels folders.
---

# Apolotoons Pipeline

All paths are under `~/Documents/SAFT/Apolotoons/`. Tooling lives in `pipeline/`.
The pipeline is **manual and agent-driven**: the user drops generated slides into
`Generated/` and asks you to run the pipeline. You run it, then **inspect the cut
panels** and re-cut or fix any that came out wrong before handing back.

## Architecture

```
<Episode>/
├── Characters/     ← approved character reference sheets (artcraft_*.png), flat on the folder
│   └── candidates/ ← scratch: unapproved generation candidates (delete after promoting)
├── Backgrounds/    ← (some episodes) approved wide background reference sheets
└── Comic Strips/
    ├── Generated/  ← user drops raw AI-generated slides here
    ├── Cleaned/    ← auto: speech bubbles removed via ArtCraft Nano Banana Pro
    ├── Upscaled/   ← auto: 2x Upscayl output
    ├── Panels/     ← auto: individual cut panels (border-trimmed)
    ├── Edited/     ← legacy manual edits (kept, unused by pipeline)
    └── Finished/   ← user's manual final composites (done by hand)
```

Match this layout exactly against existing episodes (Slavery Pt. 1/2, Fine Tuning
are the canonical references). Approved character sheets sit directly in
`Characters/`; generation candidates go in `Characters/candidates/` and are deleted
once the approved one is promoted up.
<Episode>/
├── Characters/
└── Comic Strips/
    ├── Generated/   ← user drops raw AI-generated slides here
    ├── Cleaned/     ← auto: speech bubbles removed via ArtCraft Nano Banana Pro
    ├── Upscaled/    ← auto: 2x Upscayl output
    ├── Panels/      ← auto: individual cut panels (border-trimmed)
    └── Finished/    ← user's manual final composites (done by hand)
```

No launchd watcher, no lettering/compose scripts — those were removed. Processing
happens only when you run `pipeline.py`.
removed. Processing happens only when you run `pipeline.py`.

Pipeline stages (`pipeline/pipeline.py`):
**Generated → (bubble removal) → Cleaned → (Upscayl 2x, high-fidelity-4x) →
Upscaled → (cut_panels.py, border-trimmed) → Panels**

Bubble removal runs by default for every episode; disable per-episode with a
`Comic Strips/.no-clean` marker file (the archived episodes Slavery Pt. 1/2 and
Easter Week have one). Requires being logged into the ArtCraft desktop app.

Do NOT switch to 4x upscale or the digital-art model — tested and rejected
(strong AI-upscale tell in paintings/detail); high-fidelity-4x at 2x supersamples cleanly.

## Generating a new comic (SOP, before the pipeline)

Order: **characters first → get approval → backgrounds → slides.** Generate into
`Characters/candidates/`, never straight into an approved location.

1. **Character reference sheet.** Both recurring characters side-by-side, full body,
   plain white background, neutral pose. Use **`nano_banana_2`** (NOT GPT Image 2 —
   tested, its semi-realistic/anime bias will not flatten to the house style even
   with references). Pass the previous episodes' flat-cartoon sheets as `--ref`
   (repeatable) so the style carries over. Prompt must explicitly demand a flat-color
   2D cartoon with bold uniform outlines and forbid painterly/realistic/anime looks.
2. **Approval.** Show candidates; the user picks. Promote the winner to
   `Characters/<name>.png` and delete the `candidates/` scratch.
3. **Backgrounds.** Wide background references per the script's fixed locations,
   using the approved character sheet as an image ref for continuity (Nano Banana Pro).
   When a later slide moves to a NEW area of the same location (e.g. cardio → free
   weights), generate a fresh background from a DIFFERENT vantage point — change the
   camera angle, the walls/architecture in view, and the floor treatment so it reads
   as a different room, not the same shot with equipment swapped. Pass the
   establishing background as `--ref` so art style, palette, ceiling/lighting stay
   identical. Get the background approved before rendering slides on it.
4. **Split the script per slide first.** Break the episode markdown into
   `Generated/slideN/md.txt` (one section per `**SLIDE N**`) plus a shared
   `_script/characters.txt` (the character-consistency + gym-master header). Each
   slide becomes self-contained: read its `md.txt`, then write a
   `Generated/slideN/prompt.txt` from it. Keep both files in the slide folder.
5. **Slides.** Generate each slide from scratch with **GPT Image 2** at medium
   quality, **`--variants 1`** (a single image — GPT Image 2 variants come out nearly
   identical, so extra variants just burn credits). Ref order that works:
   `--ref <background> --ref <character sheet> --ref <previous approved slide>`.
   The prompt must LOCK the background layout to the approved plate — name its specific
   fixtures (square lifting platform, power rack, chalk stand, archway, etc.) and say
   "reproduce exactly, do not redesign"; GPT Image 2 treats a loose brief as mere
   inspiration and invents a different layout. State the panel grid explicitly
   (2 stacked / 2x2), demand rendered speech bubbles with the EXACT dialogue text, and
   forbid extra bubbles/captions. Do NOT tell it "flat, no shading, no bubbles" — the
   house style is soft cartoon shading WITH baked-in bubbles matching prior slides.
   Do not ask it to repair a broken slide image; regenerate from the refs and brief.
   Before accepting, inspect physical staging (feet on equipment, object contact,
   panel count) and that the background matches the approved plate.
   For treadmill scenes where foot placement is not story-critical, prefer a torso-up
   crop: keep the separate treadmill consoles and handrails visible in both panels,
   and omit feet/legs rather than accepting broken equipment contact.

Cost note: `nano_banana_2` is ~8 credits at `one_k`, ~12 at `two_k`, and does NOT
batch through this endpoint (returns one image per call — loop for variants). Use
`one_k` for cheap style tests. GPT Image 2 slides use medium quality and
`--variants 1` by default; high quality is not a correctness upgrade. Nano Banana
**Pro** is expensive — never use it for throwaway character candidates or slides.

```bash
python3 pipeline/artcraft_cli.py generate \
    --prompt Characters/prompt.txt --out Characters/candidates/chars.png \
    --model nano_banana_2 --resolution two_k --aspect sixteen_by_nine \
    --ref path/to/prev-episode-sheet.png [--ref ...]
```
## Running the pipeline (the normal request)

```bash
python3 pipeline/pipeline.py --episode "Name"      # one episode
python3 pipeline/pipeline.py                       # everything pending
python3 pipeline/pipeline.py --dry-run             # preview
```

Idempotent: skips outputs that already exist and are newer than their source.
To force re-processing, delete the outputs in `Cleaned/`/`Upscaled/`/`Panels/`.

**After running, always verify the panel cuts:** read the images in `Panels/`,
count panels against the actual slide layout, and if any are wrong (bad split,
missing split, border not trimmed, dark-art panel mangled) re-cut that slide with
tuned flags or fix it, then report what you found and fixed.

## New episode

```bash
cd ~/Documents/SAFT/Apolotoons/pipeline
./new-episode "Episode Name"        # scaffold folders only
./new-episode "Episode Name" --dry-run
```

## Panel cutting (cut_panels.py)

Splits a page into panels. Detection, in order:
1. **White gutters** — a row/col is a gutter only if ~99% of its pixels are ≥
   `--white` (default 205), measured at full resolution (thin 2px gutters survive).
2. **Dark seam fallback** — when no white gutter splits the page, a thin (≤1.5% of
   dimension) full-width/height near-black band that has **lit art on both sides**
   is treated as a panel border. The both-sides-lit check stops dark artwork (night
   skies, the drifting-void slide) from being falsely split.
3. **Border trim** (`--trim-border`) — after cropping, shave the black border ring
   from each panel: only fires on a thin dark run that returns to lit art before an
   8%/side cap. If the dark run reaches the cap (whole edge dark = it's the art, not
   a frame), nothing is trimmed. This keeps full-bleed/dark panels whole.

```bash
python3 pipeline/cut_panels.py /abs/path/slide.png --outdir /abs/path/Panels \
    --single-copy --trim-border
```

**Note:** file args resolve relative to the script's directory — pass absolute paths.

Tuning when cuts look wrong:
- Missed gutter → lower `--white` (e.g. 195)
- False splits in bright art → raise `--white` (e.g. 215)
- Slivers kept → raise `--min-panel` (default 40)
- Verify with `--debug` (prints detected box coords) and check counts against the art

Regression baseline: Slavery Pt. 2 → slide1=1, slide5=3, others=2.
Fine Tuning reference: slide1=4, slide6=3, slide5=1 (dark void, whole), slide12=1, others=2.

## ArtCraft CLI (pipeline/artcraft_cli.py)

Reverse-engineered CLI for the ArtCraft app's backend (api.storyteller.ai).
Auth: reads the signed-session JWT from the ArtCraft app's WebKit localStorage
(`~/Library/WebKit/ai.artcraft.app/.../localstorage.sqlite3`, key
`artcraft_signed_session`) — user must be logged into the desktop app.
HTTP goes through curl (Cloudflare blocks Python urllib's TLS signature).

```bash
python3 pipeline/artcraft_cli.py whoami
python3 pipeline/artcraft_cli.py jobs
python3 pipeline/artcraft_cli.py generate --prompt "..." --out out.png \
    [--model gpt_image_2|nano_banana_2|nano_banana_pro] \
    [--resolution one_k|two_k|four_k] [--aspect sixteen_by_nine|...] \
    [--quality low|medium|high] [--variants 1-4] [--ref img.png ...]
python3 pipeline/artcraft_cli.py edit --image in.png --prompt "..." --out out.png \
    [--model nano_banana_pro|nano_banana|nano_banana_2] \
    [--resolution one_k|two_k|four_k] [--aspect three_by_four|...]
```

`generate` = text-to-image (optionally with `--ref` style/character references).
`gpt_image_2` routes through the omni-gen endpoint and honours `--quality`/`--variants`
(batches into `out-1.png`, `out-2.png`, …); `nano_banana_*` route through the
multi_function endpoint (one image per call, `--quality`/`--variants` ignored). Use
`nano_banana_2` for characters (see generation SOP above) — GPT Image 2 will not
match the flat-cartoon house style.
python3 pipeline/artcraft_cli.py whoami
python3 pipeline/artcraft_cli.py jobs
python3 pipeline/artcraft_cli.py edit --image in.png --prompt "..." --out out.png \
    [--model nano_banana_pro|nano_banana|nano_banana_2] \
    [--resolution one_k|two_k|four_k] [--aspect three_by_four|...]
```

Flow: upload → `/v1/generate/image/multi_function/nano_banana_pro` →
poll `/v1/jobs/session` → download CDN result. Pass `--aspect three_by_four` for
one-off edits to keep the 3:4 slide ratio (ArtCraft's UI edits can return a
stretched ratio; the CLI with an explicit aspect fixes that). Used for one-off
fixes like removing an element (slide 2 woman) or fixing art (slide 11 extra arm).

## Upscayl CLI

```bash
/Applications/Upscayl.app/Contents/Resources/bin/upscayl-bin \
  -i in.png -o out.png -s 2 \
  -m /Applications/Upscayl.app/Contents/Resources/models \
  -n high-fidelity-4x -f png
```

## Finishing

Final lettering/composition is done **by hand** by the user (in Affinity or
wherever) into `Comic Strips/Finished/`. There is no automated lettering step in
this pipeline anymore.

## Troubleshooting

- Bubble clean failed → confirm logged into the ArtCraft desktop app (`artcraft_cli.py whoami`)
- Errors: check `pipeline/pipeline.log`
- Keep `cut_panels.py` ONLY in `pipeline/` — never copy it into episode folders
