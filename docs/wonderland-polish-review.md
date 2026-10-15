# Wonderland fairytale polish

Wonderland keeps its six outdoor regions, eight enterable village buildings,
four castle rooms, geographical connections, entries, Pink Door/key/chest
progression and locked castle. The eighteen baked scenes retain their original
markers, portals, building positions and existing collision shapes. A new river
adds solid water and walkable bridges without changing those connections.
No NPCs, Princess, quests, encounters or music were added to Wonderland.

## Visible changes

- Credited Ninja Adventure grass, dirt transitions, varied tree silhouettes,
  shrubs, animated daisies and fluttering six-frame petals replace the simpler
  foliage/terrain. Existing Kenney architecture and furnishings are retained,
  with coordinated house roof colors, flower boxes, door lamps and trim.
- One continuous river crosses Tea Gardens, Wonderland Forest and Mushroom
  Thicket. Its banks line up across the geographical seams; the existing north
  routes cross on bounded wooden bridges with rails. Water blocks movement;
  bridges omit the solid water cells. Native source images remain unchanged.
- Wonderland's terrain previews were recaptured from the actual Godot scenes.
  Existing fog/discovery state, map coordinates and interior organization remain.
- All overworld portal destinations have physical Z-interactable wooden signs.
  Existing destination labels are hidden while their nodes remain available to
  gate-status scripts. Signs display their route's live locked/open status through
  the existing dialogue UI, and do not unlock routes or change story flags.
- Exploration gains a human-drawn shadow, modest moving bob, fading pawprints
  and shoreline ripples. Cat combat uses the same shadow; existing cinematic
  bobbing stays the sole bob where it already exists. Sequence() gets a very
  small visual bob while flying and a floor-anchored shadow in gravity sections.
  Actor positions, movement calculations, collision centers and damage shapes
  are unchanged by these effects.
- A persistent ambience autoload layers archived human bird/wind/insect/water
  recordings by environment, crossfades regions, softens indoor sounds, and
  supplies cave drips/reverb. It fades away for combat and menus without touching
  the music player or battle clock. Options → Environmental ambience persists
  separately from game saves. Cave Room 7 still desaturates/muffles its sound;
  the previous synthesized bed/drip/drone code was replaced with recorded audio.
- Info → Credits retains LLiosette and the existing cave credit. Its new Asset
  Credits viewer provides scrollable source/license notices bundled with exports.

Artist credits, original notices, pinned sources, evidence and source-access
limitations are in [wonderland-polish-credits.md](wonderland-polish-credits.md).
Every new visual/audio file is unchanged from the credited distribution; source
hashes are checked automatically. No generative image/audio service was used.
Large tea props retain the deliberately chunky native Kenney pixel art rather
than pretending to be newly illustrated high-resolution assets.

## Rendered review

Godot 4.6.3, Compatibility renderer, Xorg dummy display and Mesa llvmpipe produced
41 Wonderland/menu captures. The sheets below and selected full-size images were
visually inspected, including all six outdoor regions, all eight facades, all
12 interiors, both Pink Door states, river crossings, signs and the options/
credits windows. These are actual screenshots; the contact sheets are review
montages and are not game assets.

- [All outdoors](review/wonderland-polish/outdoors.png)
- [Eight village exteriors](review/wonderland-polish/houses.png)
- [All furnished interiors](review/wonderland-polish/interiors.png)
- [Signs, settings, movement and credits](review/wonderland-polish/shared-polish.png)
- [River crossing](review/wonderland-polish/river.png)
- [Castle exterior](review/wonderland-polish/castle.png)
- [Updated world map](review/wonderland-polish/map.png)

## Automated validation

All listed suites completed with zero failed checks:

| Check | Result |
| --- | --- |
| Headless editor import | Passed; no parse/import errors |
| New world-polish suite | 185 checks |
| Wonderland traversal/progression | 163 checks |
| Existing structure and human-art audit | 87 checks |
| Cave progression, quiet-room effects and save migration | 120 checks |
| Cartography/fog | 77 checks |
| Existing RPG/cheats/options | 81 checks |
| Existing forest layout/collision | 74 checks |
| Boss 2 | 72 checks |
| Boss 2 overhaul | 45 checks |
| Incarna | 194 checks |
| BlankKitten | 566 checks |
| Sequence presentation/mechanics | 102 checks |
| Main menu, gameplay, shooting, SATURATE, victory/retry/navigation | Passed, zero failures |

The new suite exercises actual Z sign input, live gate text, unchanged progression,
footprint creation/expiry, river physics, bridge water exclusion, runtime ripple
ownership, the persistent audio toggle/fades, source hashes, Godot decoding of
all ten recordings, and in-game credits reuse. Existing artwork tests still
compare original structures to their prior fixture; only the newly added
`Fairytale*` layers are excluded from that older structural hash.

The player's shooting, SATURATE, damage/input and physics methods, and Sequence's
input, physics, damage and cheat methods were also compared byte-for-byte to the
base revision. Their implementations are unchanged.

Reproduce from the repository root with Godot available on PATH:

```sh
godot --headless --editor --path . --import
godot --headless --path . --script tests/headless_world_polish.gd
godot --headless --path . --script tests/headless_wonderland.gd
godot --headless --path . --script tests/headless_wonderland_art.gd
godot --path . --rendering-method gl_compatibility --script tests/render_wonderland.gd
```

Headless automated checks and captures used isolated XDG data/config directories,
so they did not write a real player's save or audio preference. Captures used the
Dummy audio driver. Source durations/levels and Godot playback/fade state were
checked, but **the mix was not listened to**. Headphone/speaker balance, natural
recording seams, subjective movement feel and a human walk-through still require
manual playtesting. Existing Godot shutdown ObjectDB/resource-in-use messages
remain in several regression/capture runs; there are no remaining runtime script
or import errors in the final checked runs. Dummy-display VSync warnings are
an environment limitation.

## Editing

The original baked scenes remain the authoring source. `Ground`, `GardenPaths`,
`FairytaleWater` and `FairytaleBridges` are editable TileMapLayers with nearest
filtering. Grass/paths use native 16px cells at 2×; the original pre-scaled water/
wood sheet uses 64px cells at 0.5×, giving the same 32px world grid. The path
TileSet has a configured terrain brush. Erase solid water underneath any manually
painted bridge. Flowers/grass/rails add no solid collision.

`tools/polish_wonderland.gd -- --apply` is an explicit deterministic authoring
pass, never a runtime world generator. Re-running it recreates only its
`Fairytale*` decorations/river layers and repaints the existing floor/path cells;
it preserves the original structural nodes. Make manual scenery edits directly
in the baked scenes when you do not want that decoration pass reapplied.
After visual edits, regenerate map previews with a graphical Godot session:

```sh
godot --path . --rendering-method gl_compatibility --script tools/bake_wonderland.gd -- --maps-only
```
