# Wonderland artwork credits and provenance

The retained architecture, props and furniture described below are by **Kenney Vleugels / Kenney**. The latest terrain, foliage, movement icons and ambience are credited in [Wonderland polish credits](wonderland-polish-credits.md). The
Roguelike RPG pack additionally credits **Lynn Evers**. Thank you to both artists.

| Pack | Original publisher/source | License and attribution | Wonderland use |
| --- | --- | --- | --- |
| Roguelike / RPG pack | [Kenney](https://kenney.nl/assets/roguelike-rpg-pack) | CC0 1.0; attribution optional. Original notice names Kenney Vleugels and Lynn Evers. | Mushrooms, flowers, teapot/cup landmarks, village facades, castle masonry/roofs/windows, shelves, table settings, fountain pieces, reward chest/rocks and physical signs. Earlier Kenney grass, paths and trees have been superseded by the credited Ninja Adventure art. |
| Roguelike Indoor pack | [Kenney](https://kenney.nl/assets/roguelike-interior-pack) | CC0 1.0; attribution optional. Original notice names Kenney Vleugels. | Human-drawn tables, chairs, beds, plants, kitchen counters, stoves and furniture throughout the eight village and four castle interiors. |
| Roguelike Cave & Dungeons pack | [Kenney](https://kenney.nl/assets/roguelike-caves-dungeons) | CC0 1.0; attribution optional. Original notice names Kenney Vleugels. | Complete open/closed stone-arch arrangements for the Pink Wonderland Door, castle gate and interior doorways. |
| 1-Bit Pack 1.1 | [Kenney](https://kenney.nl/assets/1-bit-pack) | CC0 1.0; attribution optional. Original notice identifies Kenney and creation date 2020-05-06. | One existing key glyph displayed in pink and existing clock-face glyphs. |

CC0 permits commercial game use, modification and redistribution. The original
pack notices are preserved beside each source PNG in `assets/wonderland_human/`.
The original sheets are byte-for-byte unchanged. Atlas regions, repeated human
tiles, nearest-neighbor scaling, optional runtime tint and sprite transforms are
ordinary level composition; no pixels are painted by the implementation and no
generative image model or service was used. The large tea landmark sprites magnify
the native human-drawn teapot and cup; they are deliberately chunky pixel
art rather than newly drawn illustrations.

## Evidence checked and limitations

The publisher's sites (including itch.io and OpenGameArt) returned network access
denials in this environment. Downloads therefore came from the existing
[Kenney archive maintained by ETdoFresh](https://github.com/ETdoFresh/kenney.nl),
pinned to commit
[`45df48c4d45f8716216b1a9e22df0b69cd9f5932`](https://github.com/ETdoFresh/kenney.nl/commit/45df48c4d45f8716216b1a9e22df0b69cd9f5932).
GitHub's commit page reports **2020-07-17**, and the archived notices explicitly
identify the artists, CC0 and commercial-use permission. The original atlas
instructions specify 16×16 cells with a 1px separator; complete multi-cell
arrangements were inspected against the archived preview/sample images. Kenney's
established published body of work, named creators, original notices and this
pre-2021 archive are the basis for treating these as human-created pixel art.
This is reasonable provenance evidence, not an absolute forensic guarantee of
every artist's production process. The archive is a third-party mirror, not an
official Kenney GitHub repository; original publisher links above remain the
canonical references.

`assets/wonderland_human/provenance.json` records the exact upstream file paths,
archive revision and SHA-256 of every included sheet, license and atlas note.
The local verification test checks those hashes. No unattributed mirror image or
asset with unclear redistribution permission is included in the replacement set.

## Previous assets

All known AI-authored Wonderland drawing routines and embedded floor/grass
textures have been replaced. The previous drawing-code butterflies and steam
are removed; existing human plants and fountain pieces receive subtle transform
or tint animation instead. Bespoke roof/foliage shaders are no longer used.

The Fan-tasy trial, mushroom-house sheet, GFX and original cave packs supplied
earlier by the user have **not been deleted or relicensed**. No Wonderland visual
now loads their artwork, including the new entrance framing and reward chest.
Original game areas outside this task keep their existing artwork. This audit
does not assert newly verified licenses or provenance for those unrelated assets.
See the [before-edit audit](wonderland-art-audit.md) for the replacement inventory.
