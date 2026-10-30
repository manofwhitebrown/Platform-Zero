# Platform Zero

[![build](https://github.com/manofwhitebrown/Platform-Zero/actions/workflows/build.yml/badge.svg)](https://github.com/manofwhitebrown/Platform-Zero/actions/workflows/build.yml)

*You run the lost-and-found office of a magical train station.* Strange objects arrive while you're away. Each one carries hidden clues. Quirky regulars come looking for what they lost, describing it vaguely ("it was *sort of* blue?"), and you work out who owns what. Nothing expires, nobody gets angry, and a wrong guess just sends the item to the Dusty Shelf until the owner returns.

An idle, cozy, narrative-deduction game for Android. Built with Godot 4.3 (GDScript) and packaged by GitHub Actions.

## How it plays
1. **Things arrive while you're away.** About one object per 20 minutes, up to 12 waiting.
2. **Inspect.** Each tap on an object reveals another clue.
3. **An owner walks in** and describes what they lost, usually badly.
4. **Match object to owner.** A correct match gives a story and reputation. A wrong one has no penalty.
5. **Come back daily** for the Daily Mystery, the same for everyone, with a spoiler-free share card.
6. **Grow the station.** Reputation unlocks new wings and tiers. The Catalog and Gallery track every object and regular you've found.

## Get the APK
Open **Actions → build**, pick the latest green run, and download the **platform-zero-apk** artifact. Unzip it and install the `.apk` on an Android phone (allow installs from unknown sources).

## Build progress
Two AIs are building this in parallel, Engine (A) and Front (B). This block updates itself whenever the status files change.

<!-- STATUS:START -->
**Platform A · Engine** — 40/44 done

- ✅ Scaffold + autoload stubs
- ✅ Android export + CI build
- ✅ Content loader + validator
- ✅ Clock, save, offline arrivals
- ✅ Inspect, match, reputation
- ✅ Daily mystery + share text
- ✅ Tests + integration fixes
- ➖ 40 objects content
- ✅ A0.1
- ✅ A-C1
- ✅ A-C2
- ✅ A-C3
- ⬜ A-C4
- ✅ A-C5
- ✅ A0.2
- ✅ A0.3
- ✅ A0.5
- ✅ A0.6
- ✅ A1.1
- ✅ A1.2
- ✅ A1.3
- ✅ A1.4
- ✅ A1.5
- ✅ A2.5
- ✅ A2.1
- ✅ A2.2
- ✅ A2.3
- ✅ A2.4
- ✅ A3.5
- ✅ CI-race
- ✅ A-cheat-stub
- ✅ A5.1
- ✅ A3.1
- ✅ A3.2
- ✅ A3.3
- ✅ A3.4
- ✅ A6.0
- ✅ A6.1
- ✅ A6.2
- ✅ A6.3
- ✅ A6.4
- 🔄 A6.5
- ⬜ A6.6
- ✅ A6.7
- ⬜ A6.8

**Platform B · Screens** — 24/25 done

- ✅ Theme + UI kit
- ✅ Icons, backdrop, shaders
- ✅ Main scene + navigation
- ✅ Counter + inspect popup
- ✅ Owner visit + matching
- ✅ 15 owners content
- ✅ Shelf, catalog, gallery
- ✅ Daily + share card
- ✅ Audio, haptics, polish
- ✅ App icon set
- ✅ 40 objects + clue/hint alignment
- ✅ B-C1
- ✅ B-C2
- ✅ B-C3
- ✅ B-C4
- ✅ B0.1
- ✅ B0.2
- ✅ B0.3
- ✅ B1.1
- ✅ B1.2
- ✅ B1.3
- ✅ B1.4
- ✅ B1.5
- ✅ B1.6
- 🔄 B5.0

**Platform C · Sound + Story** — 1/6 done

- ✅ C1
- 🔄 C2
- 🔄 C3
- ⬜ C4
- ⬜ C5
- ⬜ C6

**Platform D · World** — 1/10 done

- ✅ D1
- ⬜ D2
- ⬜ D3
- ⬜ D4
- ⬜ D5
- ⬜ D6
- ⬜ D7
- ⬜ D8
- ⬜ D9
- ⬜ D10
<!-- STATUS:END -->

Live view: **https://manofwhitebrown.github.io/Platform-Zero/**

## Project layout
| Path | What it holds |
|---|---|
| `autoload/` | Engine singletons: Events, Content, GameState, Mystery, Clock |
| `content/` | `objects.json` (the lost objects and their clues) and `owners.json` (the 15 regulars) |
| `scenes/` | Counter, inspect popup, owner visit, shelf, catalog, daily, intro |
| `ui/` | Theme, reusable components, tier names |
| `assets/`, `shaders/`, `audio/` | Icons, backdrop art, shaders and sounds, all generated in the project |
| `tests/`, `tools/` | Headless tests and the content validator |
| `status/` | Progress files read by the dashboard and this README |
| `dashboard/` | The build board served on GitHub Pages |
| `.github/workflows/` | `build` (APK), `pages` (dashboard), `readme-status` (this README's progress block) |

## Run it
- Open the folder in **Godot 4.3** and press play, or
- Validate content: `python3 tools/validate_content.py`
- Headless tests: `godot --headless --script tests/run_tests.gd`

Design: portrait 1080×1920, gl_compatibility renderer, dusk-teal palette with brass lamps and parchment claim tags.
