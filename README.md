# Platform Zero

[![build](https://github.com/manofwhitebrown/Platform-Zero/actions/workflows/build.yml/badge.svg)](https://github.com/manofwhitebrown/Platform-Zero/actions/workflows/build.yml)

*You are the attendant of the Lost Property car on the Zero Line, a night train that never reaches its last stop.* Things get left behind. You find them, examine them, and hand them back to the people who lost them, or refuse the impostors who didn't.

A cozy idle + deduction game for Android. Built with Godot 4.5 (GDScript, gl_compatibility) and packaged by GitHub Actions. All art and audio are procedural or generated in the project.

## How it plays
1. **Explore the train.** Six cars: Observation, Sleeper, **Lost Property (hub)**, Passenger, Dining, Luggage. Tap hotspots (they shimmer after a while) to find lost items.
2. **Examine on the bench** with five tools: Magnifier (initials, station stamp), Lamp (colour, material), Ear (sound), Nose (smell), Brush (wear).
3. **Claimants walk in** (calm, hurried, worried, shy or grumpy, each with body-language tells). Ask three questions.
4. **Hand over the right item**, or **refuse an impostor** (exactly one detail is wrong) for a bonus.
5. **Earn tokens and reputation** (tiers at 0 / 10 / 30 / 70 / 150) to unlock cars and shop items. Regulars have story arcs.
6. **Come back daily** for the Night Case. Progress continues offline: one stop per 6 minutes, up to 20.

No fail state, nothing expires, nothing is lost for good. Portrait is primary; landscape is supported.

## Get the APK
Open **Actions → build**, pick the latest green run, and download the **platform-zero-apk** artifact. Unzip it and install the `.apk` on an Android phone (allow installs from unknown sources).

## Build progress
Four AIs build this in parallel: Engine (A), Screens (B), Sound + Story (C) and World (D). This block updates itself whenever the status files change.

<!-- STATUS:START -->
**Platform A · Engine** — 48/48 done


> Repo audit pass: fixed rrect polygon errors, HUD shop coin tint, lock hint wording. All tests/e2e green on 4.5.

<details><summary>Finished (48)</summary>

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
- ✅ Requests from other AIs
- ✅ Retire v1 code
- ✅ Cheat tests
- ✅ Godot 4.5 upgrade (last)
- ✅ Balance retune
- ✅ End-to-end test
- ✅ CI hygiene
- ✅ A6.12

</details>

**Platform B · Screens** — 38/38 done


> Post-QA fixes pushed: brass sliders, ledger tabs fit width, landscape overlay width cap. Build job green; screenshots stale (see request).

<details><summary>Finished (38)</summary>

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
- ✅ Settings
- ✅ Back Office cheat panel
- ✅ Audio wiring
- ✅ UI QA pass
- ✅ Help + tips
- ✅ Lore + achievements

</details>

**Platform C · Sound + Story** — 14/14 done


> Map polish verified with local Godot 4.5 renders (portrait vertical train, landscape big cars, locked card OK). run_tests 0 failures, map/audio tests pass. C1-C14 done.

<details><summary>Finished (14)</summary>

- ✅ Audio generator (47 sounds)
- ✅ Audio engine
- ✅ Story + writing pass
- ✅ Lore collectibles
- ✅ 400 items + solvability audit
- ✅ Playbot + text polish
- ✅ Audio QA
- ✅ How-to-play cards
- ✅ Loading tips
- ✅ Store listing + privacy policy
- ✅ Achievements data
- ✅ Re-check balance with playbot
- ✅ Map text + sounds + help card
- ✅ Train map: data, overlay, HUD button, travel

</details>

**Platform D · World** — 12/12 done


> Added Dr.poly (skips degenerate polygons) and routed all world/actor draw_colored_polygon calls through it + vgrad/hgrad zero-size guard, to kill "triangulation failed" logs. Not verified locally.

<details><summary>Finished (12)</summary>

- ✅ Seats + seated poses
- ✅ Dress the 5 other cars
- ✅ Ambient routine visuals
- ✅ Scenery + weather
- ✅ Station arrival
- ✅ Hotspots + item placement
- ✅ Camera + transitions
- ✅ Character generator
- ✅ Intro + title scene
- ✅ World performance + QA shots
- ✅ Door-open animation
- ✅ Fast-travel camera

</details>
<!-- STATUS:END -->

Live view: **https://manofwhitebrown.github.io/Platform-Zero/**

## Project layout
| Path | What it holds |
|---|---|
| `autoload/` | Engine singletons: Events, Clock, Content, Sim, SimAmbient, Cheats, Audio |
| `content/` | Objects, owners (regulars), barks, dialogue, arcs, lore, routes, shop, economy, generated items |
| `world/`, `actors/`, `shaders/` | The side-on train: cars, props, scenery, weather, camera, people, intro scene |
| `bench/`, `ui/` | Bench and tools, HUD, claim UI, menus, theme |
| `audio/` | Generated sounds and the manifest |
| `assets/` | Procedural art and icons |
| `tests/`, `tools/` | Headless tests, e2e, fuzz, screenshot runner, content validators and generators |
| `docs/` | Store listing, privacy policy, CI-rendered screenshots (`docs/screens/`) |
| `status/` | Progress files read by the dashboard and this README |
| `dashboard/` | The build board served on GitHub Pages |
| `.github/workflows/` | `build` (validate, tests, APK, screenshots), `pages` (dashboard), `readme-status` (the progress block above) |

## Run it
- Open the folder in **Godot 4.5** and press play, or
- Validate content: `python3 tools/validate_content.py`
- Headless tests: `godot --headless --script tests/run_tests.gd` (also `tests/e2e.gd`, `tests/fuzz.gd`)

Design: portrait 1080×1920, dusk-teal palette (night `#12303B`, lamp `#F2B84B`, brass `#B8893E`, parchment `#EADFC8`) with lamp pools and parchment claim tags.
