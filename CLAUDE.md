# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # install dependencies
flutter analyze          # static analysis — must pass with zero issues before any PR
flutter test             # run all tests
flutter test --update-goldens  # regenerate golden images after intentional rendering changes
flutter test test/seven_segment_display_test.dart  # run a single test file
```

Flutter version is pinned to `3.35.7` via `.mise.toml`.

## Code style

Enforced by `analysis_options.yaml`:
- 80-character line limit
- Single quotes for strings
- No implicit dynamics or casts

## Architecture

This is a pure Flutter package (`segment_display`) with no external dependencies beyond the Flutter SDK.

**Public API** — `lib/segment_display.dart` is the single barrel file. Everything consumed by users is exported from there.

**Rendering pipeline:**

```
value (String)
  → CharacterSegmentMap (char → bitmask)
  → SegmentDisplay.createSingleCharacter() → List<Segment>
  → SegmentDisplayPainter (CustomPainter)
  → Canvas
```

**Layer breakdown:**

| Layer | Key files | Role |
|---|---|---|
| Widget | `lib/src/display/segment_display.dart` | Abstract `StatelessWidget` base; handles `value` parsing, `characterCount` padding, `showDisabledDividers`, and size computation |
| Concrete displays | `seven_segment_display.dart`, `fourteen_segment_display.dart`, `sixteen_segment_display.dart` | Implement `createSingleCharacter()`, which returns `Segment` objects in bit-order for the display type |
| Character encoding | `lib/src/character_segment_map.dart` | Maps chars to bitmasks for each display type (`seven`, `fourteen`, `sixteen`). Divider chars (`.` and `:`) are handled separately via `dividerCharacters` |
| Segment | `lib/src/segment/segment.dart` | Holds a `Path` and an `isEnabled` flag. Named constructors (e.g. `Segment.sevenA`) delegate path creation to `SegmentStyle` |
| Position | `lib/src/segment/segment_position.dart` | Computes `(left, top)` pixel offsets for every named segment slot, derived from `segmentSize` |
| Style | `lib/src/segment_style/segment_style.dart` | Abstract class; defines four base geometry methods (`createHorizontalPath`, `createVerticalPath`, `createDiagonalForwardPath`, `createDiagonalBackwardPath`) plus per-display-per-segment `createPath*` overrides |
| Painter | `lib/src/segment_display_painter.dart` | `CustomPainter` that batches all enabled `Segment` paths into one draw call and disabled into another |

**Bitmask encoding:** In `createSingleCharacter`, segments are returned in bit order starting from bit 0. For example, `SevenSegmentDisplay.createSingleCharacter` returns `[G, F, E, D, C, B, A]` — so bit 0 controls G (middle), bit 6 controls A (top). The loop `encoding >> j & 1 == 1` directly matches index `j` to the corresponding segment.

## Tests

All tests in `test/` are golden image tests except `features_test.dart`, which contains logic-only unit tests (no golden comparison). When rendering changes intentionally, run `--update-goldens` and commit the updated `.png` files from `test/goldens/`.

`test/fixture.dart` provides shared `Widget` builders used across golden test files.

## Extending the package

**New character:** Add a `char → bitmask` entry to the relevant map(s) in `lib/src/character_segment_map.dart`. See existing entries and the `Segment` named constructors for bit ordering per display type.

**New segment style:** Extend `SegmentStyle`, implement the four base path methods, then export the class from `lib/segment_display.dart`. Override individual `createPath*` methods only when a specific segment needs a different shape from the base geometry.
