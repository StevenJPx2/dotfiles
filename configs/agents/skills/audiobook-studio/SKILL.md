---
name: audiobook-studio
description: Turn a book PDF into a chaptered .m4b audiobook via the local `abs` CLI (local LLM chapter detection + Kokoro TTS). Use when the user wants to convert a PDF/book to audio, an audiobook or .m4b, detect or edit chapters in a PDF, or mentions audiobook-studio, abs, Kokoro, or narration.
---

# Audiobook Studio (`abs` CLI)

Convert a book PDF into a chaptered `.m4b` audiobook, fully on-device:
PDF → local-LLM chapter detection → transcripts → Kokoro TTS → `.m4b`.

macOS / Apple Silicon only. Run `abs` from the repo root (or ensure the
binary, `libpdfium.dylib`, and `sidecar/` are alongside it).

## Quick start

```bash
abs doctor                                   # verify prerequisites first
abs detect --pdf book.pdf --json > ch.json   # detect chapters -> JSON
# (optionally edit ch.json — see "Editing chapters")
abs generate --pdf book.pdf --out ./out --chapters ch.json
# -> prints the .m4b path on stdout
```

Conventions: results print to **stdout** (plain, or JSON with `--json`);
progress prints to **stderr**; non-zero **exit code** on failure. Everything
is flag-driven and non-interactive.

## Workflow: doctor → detect → edit → generate

1. **`abs doctor`** — checks Ollama, the LLM model (`gemma4:e2b-mlx`), OCR
   model (`glm-ocr:q8_0`), ffmpeg, libpdfium, and the G2P sidecar. Fix any
   `FAIL` before continuing. Exits non-zero only if ffmpeg is missing.
2. **`abs detect --pdf <pdf> --json`** — prints chapters as JSON. Always
   detect first so you can review boundaries before spending TTS time.
3. **Edit the JSON** (optional) — see below.
4. **`abs generate --pdf <pdf> --out <dir> --chapters <ch.json>`** — renders
   the audiobook. Omit `--chapters` to auto-detect inside generate.

## Editing chapters

`detect --json` emits an array of chapters; edit the file, then pass it to
`generate --chapters`. Schema (pages are 1-indexed, inclusive):

```json
[{ "order": 1, "title": "Chapter One", "start_page": 3, "end_page": 8 }]
```

- **Rename**: change `title`.
- **Reorder**: reorder array elements (keep `start_page` increasing).
- **Repaginate**: change `start_page`; a chapter runs until the next one
  starts (the last ends at the final page).
- **Add / delete**: add or remove array elements.

Keep `start_page` strictly increasing across the array; overlapping ranges
produce wrong splits.

## `generate` flags

| Flag | Default | Notes |
|------|---------|-------|
| `--voice` | `bm_george` | Kokoro voice id (British male). |
| `--lang` | `b` | `b`=British, `a`=American. |
| `--speed` | `1.0` | Narration speed multiplier. |
| `--model` | `gemma4:e2b-mlx` | Ollama model for detect + polish. |
| `--title` | PDF stem | Book title metadata. |
| `--author` | `""` | Author metadata. |
| `--no-polish` | off | Disable the LLM transcript-polish pass. |

Output: only the final `.m4b` lands in `--out`. Intermediates (transcripts,
per-chapter audio, cover) go to `~/Library/Caches/audiobook-studio/<title>/`
and are reused on re-runs (resume).

## Troubleshooting

- **Ollama not reachable / no models** — start `ollama serve`; pull the model:
  `ollama pull gemma4:e2b-mlx`. Detection needs it.
- **Scanned PDF (few/no chapters, "no text layer")** — pages with no text are
  OCR'd automatically *if* `glm-ocr:q8_0` is pulled (`ollama pull glm-ocr:q8_0`).
  Without it, OCR is skipped silently.
- **Wrong chapters** — re-run `detect`, edit `ch.json`, then `generate
  --chapters ch.json`.
- **No cover in the .m4b** — needs `libpdfium.dylib` next to the binary
  (non-fatal; cover is best-effort).
- **ffmpeg missing** — required for audio; install it (`brew install ffmpeg`).
