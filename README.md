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
**Platform A · Engine** — 42/44 done

- 🔄 Requests from other AIs
- ⬜ Godot 4.5 upgrade (last)

> A6.6 done: GameState + Mystery autoloads and files removed (scenes/ was already gone); v1 save migration + test kept. All local tests, parse_all, fuzz green. Left: A6.8 Godot upgrade (last), A6.5 ongoing.

<details><summary>Finished (42)</summary>

- ✅ Scaffold + autoload stubs
- ✅ Android export + CI build
- ✅ Content loader + validator
- ✅ Clock, save, offline arrivals
- ✅ Inspect, match, reputation
- ✅ Daily mystery + share text
- ✅ Tests + integration fixes
- ✅ Sim + Cheats stubs
- ✅ Cleanup 1
- ✅ Cleanup 2
- ✅ Cleanup 3
- ✅ Delete old v1 code
- ✅ Cleanup 5
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
- ✅ Barks, dialogue, names
- ✅ Screenshot CI race fix
- ✅ Cheat stub for screenshots
- ✅ Cheat panel backend
- ✅ Procedural content (240 items)
- ✅ Shop + economy
- ✅ Regular story arcs
- ✅ Daily Night Case
- ✅ Screenshot runner + script parse check
- ✅ Offline progress
- ✅ Safe saving + backup
- ✅ Balance + fuzz tests
- ✅ Sim performance
- ✅ Retire v1 code
- ✅ Cheat tests

</details>

**Platform B · Screens** — 32/36 done

- ⬜ Settings
- ⬜ Back Office (cheat panel) UI
- ⬜ Audio wiring
- ⬜ UI QA pass

> B5.7 done: story card shows a "A NEW CHAPTER" block when hand_over result has arc_line, and uses ItemArt. Beat toasts still arrive via Events.toast. Next B5.8 Settings.

<details><summary>Finished (32)</summary>

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
- ✅ 40 objects + clue alignment
- ✅ B-C1
- ✅ B-C2
- ✅ B-C3
- ✅ B-C4
- ✅ B0.1
- ✅ B0.2
- ✅ B0.3
- ✅ Train car shell
- ✅ Actor rig
- ✅ Tap-to-walk + highlights
- ✅ Claimants, bubbles, interview UI
- ✅ Bench + 5 tools
- ✅ HUD
- ✅ Train is the real main scene
- ✅ Tutorial overlay
- ✅ Shared item art
- ✅ Ledger + retire v1 screens
- ✅ Shop screen
- ✅ Night Case screen
- ✅ Welcome-back screen
- ✅ Arc story cards

</details>

**Platform C · Sound + Story** — 6/6 done


> All C tasks done. Final read-through of 914 strings: no typos/double spaces/odd placeholders; names consistent. Balance numbers sent to A (fuzz.gd).

<details><summary>Finished (6)</summary>

- ✅ Audio generator (47 sounds)
- ✅ Audio engine
- ✅ Story + writing pass
- ✅ Lore collectibles
- ✅ 400 items + solvability audit
- ✅ Playbot + text polish

</details>

**Platform D · World** — 4/10 done

- ⬜ Station arrival
- ⬜ Hotspots + item placement
- ⬜ Camera + transitions
- ⬜ Character generator
- ⬜ Intro / title scene
- ⬜ World performance + QA shots

> D4: scenery adds desert + tunnel biomes, snow peaks, lightning flashes in rain, GlassFx (rain drops/fog on window glass). TrainWorld.shot_scene(biome,weather,tod) forces the view for shots. Biomes plains/snow/sea/city/fo

<details><summary>Finished (4)</summary>

- ✅ Seats + seated poses
- ✅ Dress the 5 other cars
- ✅ Ambient routine visuals
- ✅ Scenery + weather

</details>
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
