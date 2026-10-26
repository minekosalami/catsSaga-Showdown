# Wonderland v2 asset provenance

No generative image, audio, font or animation tool was used. No original artwork file was changed or deleted. The new PNGs are unchanged source files from the same artist-maintained collection as the preceding Wonderland rebuild.

Source: [Eliza Wyatt — LPC Revised](https://github.com/ElizaWy/LPC/tree/f07f7f5892e67c932c68f70bb04472f2c64e46bc), revision `f07f7f5892e67c932c68f70bb04472f2c64e46bc` (2023-12-01). License: [OGA-BY 3.0](https://opengameart.org/content/oga-by-30-faq), allowing game use and redistribution with attribution. The artist's root notice explicitly describes the collection as hand drawn; sheet credits identify original artists, adaptations and upstream source packs. This is credible authorship evidence rather than a forensic certification.

`assets/wonderland_human/cohesion/provenance.json` lists all imported filenames, original paths, revision and SHA-256 hashes. The following source artists must be credited:

| Sheets | Credited artists | Use |
|---|---|---|
| Wood Floor A, Tile B, Floral Carpet A | Lanea Zimmerman (Sharm), Eliza Wyatt (DeathsDarling) | Floors and bordered rugs |
| Half-Wall Paneling A | Lanea Zimmerman, Eliza Wyatt | Interior wainscoting |
| Chair, Dining A; Loveseat, Small — Casual Patterned A | Lanea Zimmerman, BlueCarrot16, Eliza Wyatt | Seating groups |
| Thrones | Lanea Zimmerman, Eliza Wyatt | Royal throne |
| Table, Rough Wood; Countertop; Fireplace, Cast Iron | Lanea Zimmerman, Eliza Wyatt | Tables, shop counters and cooking bays |
| Desk, Vanity | Eliza Wyatt | Tiny Pink House dressing alcove |
| Paintings, Landscape | Lanea Zimmerman, Eliza Wyatt | Existing-room decoration |
| Ornamental Windows A | Lanea Zimmerman, Eliza Wyatt | Modular upper/lower window frames |

The unmodified `Seating-Credits.txt`, `Wall-Items-Credits.txt`, and `Windows-Credits.txt` accompany the new sheets. Related original floor, wall and furniture notices and the root artist/license notice remain in `assets/wonderland_human/rebuild/`. Those notices include the original OpenGameArt URLs and more detailed artist contributions. Local `.gitattributes` preserves upstream notice bytes and line endings. Exported in-game Asset Credits includes the new attribution entry.

Retained Ninja Adventure artwork is credited to Pixel-Boy (CC0); retained Kenney trim, signs and props to Kenney Vleugels/Kenney and Lynn Evers where noted (CC0). Their original notices, historical source evidence and caveats remain in [previous credits](wonderland-environment-rebuild-credits.md). No soundtrack, recording or font was imported for v2.

Technical adaptations: atlas selection, alpha-bound trimming, modular tile/window assembly, integer display scales, shader palette matching, static silhouette projection, wall-base lighting and local opacity animation. Original image pixels remain unchanged on disk. Shadows render the existing human artwork through a directional lighting shader; no shadow sprite sheet, replacement texture or procedural artwork is generated. Palette matching changes grass fringe colors only; source dirt and water colors are retained.
