# Changelog Guidelines

## File structure (keep this exact order)
```
## [Upcoming]

### Added
### Enhanced
### Fixed

## [x.y.z]
### Added
### Enhanced
### Fixed
```
- Always keep **`[Upcoming]` at the top**. New entries go here first.
- **Newest versions first** (reverse chronological).

## Categorization rules
Use these sections **only** (project house style):
- **Added** — brand new capabilities, APIs, options, or surface area.
- **Enhanced** — improvements to existing behavior, ergonomics, performance, or DX (what many projects call “Changed”).
- **Fixed** — bug fixes and crash/stability corrections.

> If needed for a specific release, you may add extra headings below the three above (e.g., **Breaking Changes**, **Deprecated**, **Removed**, **Security**). Only include them when relevant.

## Entry formatting
- One bullet per change: `- **Concise Title**: Brief, clear explanation.`
- **Bold** a short title; then a **sentence** describing the change and impact.
- Use *inline code* for types, symbols, method names (e.g., `ModelSession`, `clearTranscript()`).
- If helpful, include a **small code block** and prefer a **Before/Now** mini-diff:
  ```swift
  // Before
  PromptTag("system", content: [instructions])

  // Now
  PromptTag("system", content: instructions)
  ```
- Keep bullets short; move rationales/details into a second paragraph only when it materially improves understanding.
- Avoid commit hashes, internal ticket IDs, and colloquialisms.

## Versioning & releases
- Keep all new bullets under **`[Upcoming]`** while developing.
- When releasing:
  1. Decide version **x.y.z** using **SemVer** rules (MAJOR: breaking; MINOR: backward‑compatible features; PATCH: backward‑compatible fixes).
  2. Create a new section `## [x.y.z]` **below** `[Upcoming]` and **move** the relevant bullets from `[Upcoming]` into it.
  3. Leave `[Upcoming]` in place (empty) for the next cycle.
  4. Optionally append a release date like `## [x.y.z] — 2025‑09‑22` if dates are desired for this repository.
- Never delete history; correct mistakes with follow‑up entries.

## Writing checklist (run for every change)
- [ ] Correct section (Added / Enhanced / Fixed).
- [ ] Clear bold title + one‑sentence explanation.
- [ ] APIs, types, and errors in `code` style; Swift samples compile or read plausibly.
- [ ] Include small example when it clarifies the change (esp. ergonomic/behavioral tweaks).
- [ ] No internal IDs or noisy detail; user‑facing impact is obvious.
- [ ] Placed under `[Upcoming]` (or moved to the new `## [x.y.z]` on release).
