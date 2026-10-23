---
name: apolotoons-pipeline
description: >-
  Run the Apolotoons comic production pipeline on request: scaffold episode folders, remove speech bubbles, upscale strips with Upscayl, cut strips into panels, and verify the cuts. Use when the user mentions Apolotoons, comic episodes or strips, panel cutting, upscaling slides, bubble removal, or the Generated/Cleaned/Upscaled/Panels folders.
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
├── script.md       ← the episode script (source for shot specs)
├── cast.json       ← characters/settings: description + reference images, style
└── Comic Strips/
    ├── Generated/  ← user drops raw AI-generated slides here; Generated/<slide>/ holds
    │               candidates, sketch.png, prompt.md (pages carry bubbles; clean empties them)
    ├── Cleaned/    ← auto: speech bubbles removed (imagegen `clean` task); fixes land here
    ├── Upscaled/   ← auto: 2x Upscayl output
    ├── Panels/     ← auto: individual cut panels (border-trimmed)
    ├── Specs/      ← shot specs <slide>.json and <slide>.sketch.png
    ├── Checks/     ← vision check reports and agent logs
    ├── Fixes/      ← per-fix folders with attempts and fix.json (status, cost)
    ├── .trash/     ← pruned candidates/fixes (never deleted)
    ├── Edited/     ← legacy manual edits (kept, unused by pipeline)
    └── Finished/   ← user's manual final composites (done by hand)
```

**Studio:** `studio/` is a Nuxt 4 site over all of this at https://toons.stjhn.xyz
(Cloudflare Tunnel `apolotoons-studio` + Access app "Apolotoons Studio"; add teammates
to the Access group "SAFT team"). Start it with `studio/serve` (`--local` for
127.0.0.1:3141 without Access). It runs the pipeline/blueprint scripts as jobs.

**Structured projects:** an episode may have `project.json` (people, settings,
slides, panels, dialogue, with stable IDs and a copy of the style template).
When it exists it is the authority: the studio rewrites `cast.json` (including
`style_refs`), `Comic Strips/Specs/<slide>.json` and, for created projects,
`script.md` from it on every save, and refuses direct cast/scene/spec edits.
Do not hand-edit those derived files in a project episode; change the project.
Editing `project.json` directly is fine, then run (from `studio/`)
`bun run project validate "<Episode>"` and `bun run project apply "<Episode>"`
to check it and rewrite the outputs. `bun run project next "<Episode>" --json`
lists each slide's next step (same rules as the storyboard). Every episode is a
project (older ones were converted, keeping their script, specs and style);
`bun run project convert "<Episode>"` (or `--all`) converts a folder that
appears without `project.json`. The studio has no Markdown script editor:
the script is the project's fields, edited in the episode's Write stage.
The style template is `pipeline/style-template.json`; `cast.py` and
`generate.py` send up to three `style_refs` (paths relative to the Apolotoons
folder) as drawing-style references, last.

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

CLI for ArtCraft's documented unified API (api.storyteller.ai).
Auth: `ARTCRAFT_API_KEY` / global `--api-key-file` when available; otherwise
the signed-in desktop app's cookie jar (`~/Library/Caches/ai.artcraft.app/.cookies`).
Old WebKit signed sessions remain a fallback. API keys are gated per account;
this account's `api_key` feature flag is currently absent, so keep session auth.
HTTP uses curl with desktop Origin/User-Agent headers. Secrets go through stdin,
not process arguments. Installed ArtCraft is 0.41.0.

```bash
python3 pipeline/artcraft_cli.py whoami
python3 pipeline/artcraft_cli.py models --json
python3 pipeline/artcraft_cli.py cost --model nano_banana_pro --resolution four_k
python3 pipeline/artcraft_cli.py jobs
python3 pipeline/artcraft_cli.py generate --prompt "..." --out out.png \
    --model nano_banana_2 --resolution two_k --aspect tall_three_by_four \
    --variants 1 --ref character.png --ref background.png
python3 pipeline/artcraft_cli.py edit --image in.png --prompt "..." --out out.png \
    --model nano_banana_pro --resolution two_k --aspect tall_three_by_four
python3 pipeline/artcraft_cli.py result jinf_TOKEN --out out.png
```

All models use `/v1/omni_gen/generate/image` (model is a field). Live catalogue
validation checks references, aspect, resolution, quality and batch count before
generation. Explicit batch count defaults to 1 (the server's NBP default is 4).
The CLI estimates cost before generation; output has a `.job.json` record
so `result` can resume without a second generation. Polls `/v1/jobs/job/TOKEN`
for session auth (Omni API job-status for keys); `attempt_failed` is retryable.
NBP 2K costs 15 credits / 15 US cents; 4K costs 30 / 30, at last check.
Models are user-selectable; follow the nano_banana_2 character SOP above by default.
Old aspect aliases (three_by_four, sixteen_by_nine) still map to unified values.
An explicit aspect reduces unwanted reframing; it doesn't guarantee exact dimensions.

## Upscayl CLI

```bash
/Applications/Upscayl.app/Contents/Resources/bin/upscayl-bin \
  -i in.png -o out.png -s 2 \
  -m /Applications/Upscayl.app/Contents/Resources/models \
  -n high-fidelity-4x -f png
```

## Shot specs, sketches and verification (artifact control)

The user's biggest time sink is AI artifacts: wrong facing/placement, extra or
detached limbs, hands, consistency, garbled props. Control them with specs.

- **Spec:** `Comic Strips/Specs/<slide>.json`: per panel `box` (page fraction),
  `camera`, `characters[{name, box (panel fraction), facing, looking_at, pose, limbs?}]`,
  `props[{name, box, detail}]`, `must_not[]`. Facing is screen-relative:
  `screen-left | screen-right | toward-viewer | away`. When the script doesn't say
  who stands where, omit `box`/`facing` and set `"continuity": "same left-to-right order as panel N"`.
  Never invent placement. Script lives at `<Episode>/script.md`.
- **Sketch:** `python3 pipeline/blueprint/sketch.py Specs/slide1.json -o out.png [--panel N]`:
  code-drawn stick figures with facing arrows and sight-lines. Use for approval
  and as a layout reference when generating.
- **Automated check:** `pipeline/blueprint/agent.py check <spec> <page>` (vision model via
  `observe.py`: overview + 4 zoomed tiles + crop confirmation; Gemini free tier is ~20
  requests/model/day, ~6 per panel). `agent.py autofix ... --budget 0.5` fixes located
  defects with `fix.py`, proposes flips, queues the rest; never promotes.
- **Manual verify (fallback):** `verify.py crops <spec> <page.png> --out crops/`, then look at each crop
  (zoom in: small anatomy defects are invisible at page size) and write facts only
  to an observations JSON (`characters[{name, box, facing, looking_at, limbs, hands_ok}]`,
  `props[]`, `unexpected[]`, `artifacts[]`). `verify.py check <spec> <observations>`
  decides pass/fail by code (facing, order, mirrored, continuity, limbs, missing/extra).
  Tests: `python3 -m unittest discover -s pipeline/blueprint`.
- **Fix:** crop the problem area, draw red guide marks on it, make a mask (white =
  change), then `python3 pipeline/imagegen.py edit --task fix --image crop.png
  --mask mask.png --prompt "..." --out fixed.png --max-usd 0.20`. Paste back with a
  feathered edge and re-verify. **Text-only prompts fail for geometry; red guide
  marks work** (where a bone/limb should go, circle the defect; ask the model to
  remove all red marks). Max 2 attempts, then the user.
- **Providers:** `imagegen.py` covers ArtCraft, Google, OpenAI, Ideogram 4.5, FLUX 3
  and ImageRouter, with fallback chains and tasks in `pipeline/models.json` and
  every spend in `pipeline/spend.jsonl`. `fix` prefers Ideogram 4.5 precise edit
  (keeps exact pixels and crop edges, least drift over repeated edits). Check
  `imagegen.py providers` for which keys are set.
- Test budget is light (~$1); production spends what it needs, logged.

## Finishing (lettering in Affinity, via its MCP)

Affinity runs a local MCP server (localhost:6767); the `affinity` toolset reaches it.
The agent builds the episode `.af`, the user fine-tunes positions by hand.

- **Spec:** `Comic Strips/Finished/<slug>.lettering.json`: `size`, `background`,
  `logo {path, rect}`, `slides[{name, panels[{path, rect}], dialogue[{text, rect,
  size, tail: [x0,y0,x1,y1,bulge]}]}]`, `save`. Paths relative to the spec; rects
  in px on a 1080x1440 slide. Write it from the script + panel aspect ratios.
- **Affinity can only touch Desktop files** (real path checked; symlinks fail). Episode
  folders are Google Drive sync roots by path, so never move them. Instead:
  1. `pipeline/affinity/stage "<Episode>"`: APFS-clones Panels, Assets, spec and
     `build_episode.js` into `~/Desktop/Apolotoons Staging/<Episode>/` (instant, no space).
  2. Build over MCP (`eval` is blocked; `require` of a Desktop file works):
     `affinity_execute_script` with
     `globalThis.SPEC_PATH='<staging>/<slug>.lettering.json'; require('<staging>/build_episode.js');`
     Export a preview with `affinity_export`, check it, then close the doc.
  3. `pipeline/affinity/stage "<Episode>" --collect`: moves `.af`/exports into
     `Finished/` (older copies renamed `(prev <date>)`), removes staging.
- Builder: `pipeline/affinity/build_episode.js` (house style constants in `STYLE`).
  Library entry for the user: Scripts panel > "Apolotoons: Build Episode (staged)".
- Never touch other open documents; target ours via `Document.enumerateAll` + `sessionUuid`.

## Troubleshooting

- Bubble clean failed → confirm logged into the ArtCraft desktop app (`artcraft_cli.py whoami`)
- Errors: check `pipeline/pipeline.log`
- Keep `cut_panels.py` ONLY in `pipeline/` — never copy it into episode folders
