# Forever nameplate skin

Select **Nameplates → General → Nameplate Art → Forever (Thin)**. This is an
additional skin; Heritage remains the default. Layout settings changed by a skin
preset are saved per style, so switching back restores the previous layout.

The first-use preset has a 166×13 health bar, 6-unit cast bar, centered outlined
name, health text at the bar's right edge, and the original level badge on the
right. Existing aura, threat, identity, stacking and cast detection code is reused.
The power bar and elite icon are initially off, matching the inspected Forever
layout; they remain configurable. This is a skin port, not a port of modern
client APIs or every Forever gameplay feature.

## Artwork

Source: the user's local `wowf` **1.60.1.70532** installation. Original BLPs were
read by FileDataID from CASC, without modifying that installation. Rectangles and
slice definitions were inspected in its `UiTextureAtlasMember`,
`UiTextureAtlasElement` and `UiTextureAtlasElementSliceData` tables; anchoring was
checked against the same client's nameplate Lua/XML files.

`DragonUI/Textures/Nameplates/Forever/provenance.json` records the source hashes,
FileDataIDs, rectangles, and adaptations. Artwork is © Blizzard Entertainment,
not MIT; see the addon's third-party notices. No Blizzard Lua implementation is
copied into this port.

To regenerate, extract the FileDataIDs listed in that manifest into a separate
directory, naming each file with its numeric ID, and run:

```text
python tools/build_forever_nameplates.py EXTRACTED_DIRECTORY
```

Requires Pillow. Borders and badges keep their original image pixels, padded to
power-of-two TGAs with explicit UVs; the four StatusBar fills are resampled to
512×32. The cast spark uses the original pip's central band, because the modern
tiled atlas slicing API is unavailable in 3.3.5a. Nine-slice rendering is performed
by DragonUI, not by the modern client engine.

## Tests

```text
python tools/test_forever_nameplates.py
```

Requires Pillow and lupa with its Lua 5.1 runtime. Tests check syntax, XML paths,
texture format, style restoration, native off-target levels, skulls, visibility,
focus/target borders, cast icons, and style transitions on existing frames.
They use a frame mock and do **not** establish visual correctness inside WoW.

In-game acceptance still requires checking UI scale, low-health edge clipping,
target/focus changes, recycled plates, friendly name-only mode, spell casts,
channels, interrupt holds, and switching between all three skins. Unknown native
levels are deliberately hidden rather than copied from a different unit.
